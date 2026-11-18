const {
  EIOS_BASE,
  isValidEiosUrl,
  getQuerySecretError,
  CookieJar,
  fetchWithRedirects,
} = require("./core");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://vladosflexxx.github.io",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-cookie-header, x-target-url, Accept",
  "Access-Control-Max-Age": "86400",
};

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

    // 1. Проверка на секреты в query-параметрах
    const secretError = getQuerySecretError(query);
    if (secretError) {
      return {
        statusCode: 400,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({ error: secretError }),
      };
    }

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

      const username = bodyData.username || bodyData.login;
      const password = bodyData.password || bodyData.pass;

      if (!username || !password) {
        return {
          statusCode: 400,
          headers: { ...dynamicCors, "Content-Type": "application/json" },
          body: JSON.stringify({ error: "Missing login credentials in request body" }),
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
    const cookieHeader = headers["x-cookie-header"] || "";

    if (!targetUrl) {
      return {
        statusCode: 200,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({ status: "ok", service: "MyIMES Proxy", time: new Date().toISOString() }),
      };
    }

    if (!isValidEiosUrl(targetUrl)) {
      return {
        statusCode: 403,
        headers: { ...dynamicCors, "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Доступ разрешен только к https://eos.imes.su (порт 443)" }),
      };
    }

    const proxyHeaders = {
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1",
      "Accept": headers["accept"] || "text/html,application/xhtml+xml,application/xml",
    };
    if (cookieHeader) {
      proxyHeaders["Cookie"] = cookieHeader;
    }

    let currentProxyUrl = targetUrl;
    let upstreamRes;
    for (let hop = 0; hop <= 6; hop++) {
      if (!isValidEiosUrl(currentProxyUrl)) {
        return {
          statusCode: 403,
          headers: { ...dynamicCors, "Content-Type": "application/json" },
          body: JSON.stringify({ error: "Редирект на сторонний адрес запрещен" }),
        };
      }

      upstreamRes = await fetch(currentProxyUrl, {
        method: method,
        headers: proxyHeaders,
        redirect: "manual",
      });

      const isRedirect = [301, 302, 303, 307, 308].includes(upstreamRes.status);
      if (!isRedirect) break;

      const loc = upstreamRes.headers.get("location");
      if (!loc) break;

      const nextUrl = new URL(loc, currentProxyUrl).toString();
      if (!isValidEiosUrl(nextUrl)) {
        break;
      }
      currentProxyUrl = nextUrl;
    }

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
