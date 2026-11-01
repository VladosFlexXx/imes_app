const EIOS_BASE = "https://eos.imes.su";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://vladosflexxx.github.io",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-cookie-header, x-target-url, Accept",
  "Access-Control-Max-Age": "86400",
};

class CookieJar {
  constructor() {
    this.cookies = new Map();
  }

  setFromHeaders(headers) {
    let setCookies = [];
    if (typeof headers.getSetCookie === "function") {
      setCookies = headers.getSetCookie();
    } else {
      const raw = headers.get("set-cookie");
      if (raw) setCookies = [raw];
    }
    for (const sc of setCookies) {
      const nameVal = sc.split(";")[0].trim();
      const eqIdx = nameVal.indexOf("=");
      if (eqIdx > 0) {
        const name = nameVal.slice(0, eqIdx).trim();
        const val = nameVal.slice(eqIdx + 1).trim();
        this.cookies.set(name, val);
      }
    }
  }

  toHeader() {
    return Array.from(this.cookies.entries())
      .map(([k, v]) => k + "=" + v)
      .join("; ");
  }

  get(name) {
    return this.cookies.get(name);
  }
}

async function fetchWithRedirects(url, options = {}, jar = new CookieJar(), maxHops = 6) {
  let currentUrl = url;
  let currentMethod = options.method || "GET";
  let currentBody = options.body;
  const baseHeaders = options.headers || {};

  for (let hop = 0; hop <= maxHops; hop++) {
    const headers = { ...baseHeaders };
    const cookieHeader = jar.toHeader();
    if (cookieHeader) {
      headers["Cookie"] = cookieHeader;
    }

    const res = await fetch(currentUrl, {
      method: currentMethod,
      headers: headers,
      body: currentMethod === "POST" ? currentBody : undefined,
      redirect: "manual",
    });

    jar.setFromHeaders(res.headers);

    const isRedirect = [301, 302, 303, 307, 308].includes(res.status);
    if (!isRedirect) {
      return { response: res, finalUrl: currentUrl };
    }

    const loc = res.headers.get("location");
    if (!loc) {
      return { response: res, finalUrl: currentUrl };
    }

    currentUrl = new URL(loc, currentUrl).toString();
    if (res.status === 303 || (res.status === 302 && currentMethod === "POST")) {
      currentMethod = "GET";
      currentBody = undefined;
    }
  }

  throw new Error("Too many redirects");
}

module.exports.handler = async function (event, context) {
  const method = (event.httpMethod || "GET").toUpperCase();

  const reqOrigin = (event.headers && (event.headers.origin || event.headers.Origin)) || "https://vladosflexxx.github.io";
  const dynamicCors = {
    ...CORS_HEADERS,
    "Access-Control-Allow-Origin": reqOrigin,
  };

  if (method === "OPTIONS") {
    return { statusCode: 200, headers: dynamicCors, body: "ok" };
  }

  try {
    const path = event.path || event.url || "/";
    const headers = event.headers || {};
    const query = event.queryStringParameters || {};

    const isLogin = method === "POST" || path.includes("login") || query.action === "login";

    if (isLogin) {
      let bodyData = {};
      try {
        if (event.body && typeof event.body === "object") {
          bodyData = event.body;
        } else if (typeof event.body === "string") {
          const raw = event.isBase64Encoded 
            ? Buffer.from(event.body, "base64").toString("utf-8")
            : event.body;
          bodyData = JSON.parse(raw);
        }
      } catch (e) {
        return {
          statusCode: 400,
          headers: { ...dynamicCors, "Content-Type": "application/json" },
          body: JSON.stringify({ error: "Invalid JSON: " + e.message }),
        };
      }

      const username = bodyData.username || bodyData.login || query.username;
      const password = bodyData.password || bodyData.pass || query.password;

      if (!username || !password) {
        return {
          statusCode: 400,
          headers: { ...dynamicCors, "Content-Type": "application/json" },
          body: JSON.stringify({ error: "Missing login credentials" }),
        };
      }

      const jar = new CookieJar();
      const commonHeaders = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1",
        "Accept": "text/html,application/xhtml+xml,application/xml",
      };

      const { response: getLoginRes } = await fetchWithRedirects(
        EIOS_BASE + "/login/index.php",
        { method: "GET", headers: commonHeaders },
        jar
      );

      const loginPageHtml = await getLoginRes.text();
      const tokenMatch = loginPageHtml.match(/name="logintoken"\s+value="([^"]+)"/i);
      const logintoken = tokenMatch ? tokenMatch[1] : "";

      const formParams = new URLSearchParams();
      formParams.append("username", username.trim());
      formParams.append("password", password);
      formParams.append("anchor", "");
      if (logintoken) {
        formParams.append("logintoken", logintoken);
      }

      const postHeaders = {
        ...commonHeaders,
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": EIOS_BASE + "/login/index.php",
        "Origin": EIOS_BASE,
      };

      const { response: postRes, finalUrl: postFinalUrl } = await fetchWithRedirects(
        EIOS_BASE + "/login/index.php",
        {
          method: "POST",
          headers: postHeaders,
          body: formParams.toString(),
        },
        jar
      );

      const { response: myRes, finalUrl: myFinalUrl } = await fetchWithRedirects(
        EIOS_BASE + "/my/",
        { method: "GET", headers: commonHeaders },
        jar
      );

      const myHtml = await myRes.text();
      const lower = myHtml.toLowerCase();
      const isLoginPage = myFinalUrl.includes("/login") || 
                          lower.includes("loginfailed") || 
                          lower.includes("неверный логин") || 
                          (lower.includes("вход в систему") && !lower.includes("личный кабинет"));

      if (isLoginPage) {
        return {
          statusCode: 401,
          headers: { ...dynamicCors, "Content-Type": "application/json" },
          body: JSON.stringify({ 
            success: false, 
            error: "Неверный логин или пароль от ЭИОС",
            debug: { postFinalUrl, myFinalUrl, moodleCookie: jar.get("MoodleSession") ? "present" : "missing" }
          }),
        };
      }

      const finalCookie = jar.toHeader();
      return {
        statusCode: 200,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({
          success: true,
          cookie: finalCookie,
        }),
      };
    }

    const targetUrl = headers["x-target-url"] || query.url;
    const cookieHeader = headers["x-cookie-header"] || query.cookie || "";

    if (!targetUrl) {
      return {
        statusCode: 200,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({ status: "ok", service: "MyIMES Proxy", time: new Date().toISOString() }),
      };
    }

    if (!targetUrl.startsWith(EIOS_BASE)) {
      return {
        statusCode: 403,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Доступ разрешен только к eos.imes.su" }),
      };
    }

    const proxyHeaders = {
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1",
      "Accept": headers["accept"] || "text/html,application/xhtml+xml,application/xml",
    };
    if (cookieHeader) {
      proxyHeaders["Cookie"] = cookieHeader;
    }

    const upstreamRes = await fetch(targetUrl, {
      method: method,
      headers: proxyHeaders,
      redirect: "follow",
    });

    const responseBody = await upstreamRes.text();
    const contentType = upstreamRes.headers.get("content-type") || "text/html; charset=utf-8";

    return {
      statusCode: upstreamRes.status,
      headers: {
        ...dynamicCors,
        "Content-Type": contentType,
      },
      body: responseBody,
    };

  } catch (err) {
    return {
      statusCode: 500,
      headers: { ...dynamicCors, "Content-Type": "application/json" },
      body: JSON.stringify({
        error: "Ошибка прокси: " + err.message,
        stack: err.stack,
      }),
    };
  }
};
