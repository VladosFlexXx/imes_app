const http = require("node:http");

const EIOS_BASE = "https://eos.imes.su";
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "0.0.0.0";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, DELETE",
  "Access-Control-Allow-Headers": "Content-Type, x-cookie-header, x-target-url, Accept, Authorization",
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
      .map(([k, v]) => `${k}=${v}`)
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

function sendResponse(res, statusCode, headers, body) {
  res.writeHead(statusCode, headers);
  if (body) {
    res.end(body);
  } else {
    res.end();
  }
}

const server = http.createServer(async (req, res) => {
  const start = Date.now();
  const method = (req.method || "GET").toUpperCase();

  const reqOrigin = req.headers["origin"] || "*";
  const dynamicCors = {
    ...CORS_HEADERS,
    "Access-Control-Allow-Origin": reqOrigin,
  };

  if (method === "OPTIONS") {
    sendResponse(res, 204, dynamicCors);
    return;
  }

  const parsedUrl = new URL(req.url, `http://${req.headers.host || "localhost"}`);
  const pathname = parsedUrl.pathname;
  const query = Object.fromEntries(parsedUrl.searchParams.entries());

  // Buffer incoming body
  let rawBody = "";
  try {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    rawBody = Buffer.concat(chunks).toString("utf-8");
  } catch (err) {
    sendResponse(
      res,
      400,
      { ...dynamicCors, "Content-Type": "application/json" },
      JSON.stringify({ error: "Failed to read request body" })
    );
    return;
  }

  try {
    // 1. Health / Root
    if (pathname === "/" || pathname === "/health") {
      const info = {
        status: "ok",
        service: "MyIMES Proxy & Backup Server",
        version: "1.0.0",
        uptimeSec: Math.floor(process.uptime()),
        time: new Date().toISOString(),
        node: process.version,
        memoryMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
      };
      sendResponse(
        res,
        200,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify(info, null, 2)
      );
      return;
    }

    // 2. Login endpoint (/login or ?action=login)
    const isLogin = pathname === "/login" || pathname === "/login/index.php" || query.action === "login";
    if (isLogin) {
      let bodyData = {};
      if (rawBody.trim().length > 0) {
        try {
          bodyData = JSON.parse(rawBody);
        } catch (_) {
          // May be form-urlencoded
          const params = new URLSearchParams(rawBody);
          bodyData = Object.fromEntries(params.entries());
        }
      }

      const username = bodyData.username || bodyData.login || query.username;
      const password = bodyData.password || bodyData.pass || query.password;

      if (!username || !password) {
        sendResponse(
          res,
          400,
          { ...dynamicCors, "Content-Type": "application/json" },
          JSON.stringify({ error: "Missing login credentials (username, password)" })
        );
        return;
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
      const isLoginPage =
        myFinalUrl.includes("/login") ||
        lower.includes("loginfailed") ||
        lower.includes("неверный логин") ||
        (lower.includes("вход в систему") && !lower.includes("личный кабинет"));

      if (isLoginPage) {
        sendResponse(
          res,
          401,
          { ...dynamicCors, "Content-Type": "application/json" },
          JSON.stringify({
            success: false,
            error: "Неверный логин или пароль от ЭИОС",
            debug: { postFinalUrl, myFinalUrl, moodleCookie: jar.get("MoodleSession") ? "present" : "missing" },
          })
        );
        return;
      }

      const finalCookie = jar.toHeader();
      sendResponse(
        res,
        200,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify({
          success: true,
          cookie: finalCookie,
        })
      );
      return;
    }

    // 3. Proxy endpoint
    const targetUrl = req.headers["x-target-url"] || query.url;
    const cookieHeader = req.headers["x-cookie-header"] || query.cookie || "";

    if (!targetUrl) {
      sendResponse(
        res,
        200,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify({
          status: "ok",
          service: "MyIMES Proxy & Backup Server",
          usage: "Pass x-target-url header or ?url= parameter pointing to eos.imes.su",
          time: new Date().toISOString(),
        })
      );
      return;
    }

    if (!targetUrl.startsWith(EIOS_BASE)) {
      sendResponse(
        res,
        403,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify({ error: "Доступ разрешен только к eos.imes.su" })
      );
      return;
    }

    const proxyHeaders = {
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1",
      "Accept": req.headers["accept"] || "text/html,application/xhtml+xml,application/xml",
    };
    if (cookieHeader) {
      proxyHeaders["Cookie"] = cookieHeader;
    }

    const upstreamRes = await fetch(targetUrl, {
      method: method,
      headers: proxyHeaders,
      body: method === "POST" && rawBody ? rawBody : undefined,
      redirect: "follow",
    });

    const responseBody = await upstreamRes.text();
    const contentType = upstreamRes.headers.get("content-type") || "text/html; charset=utf-8";

    sendResponse(
      res,
      upstreamRes.status,
      {
        ...dynamicCors,
        "Content-Type": contentType,
      },
      responseBody
    );
  } catch (err) {
    sendResponse(
      res,
      500,
      { ...dynamicCors, "Content-Type": "application/json" },
      JSON.stringify({
        error: "Ошибка прокси: " + err.message,
        stack: err.stack,
      })
    );
  } finally {
    const ms = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${method} ${pathname} -> ${res.statusCode} (${ms}ms)`);
  }
});

server.listen(PORT, HOST, () => {
  console.log(`🚀 MyIMES Standalone Proxy Server running at http://${HOST}:${PORT}/`);
  console.log(`   Connected to EIOS upstream: ${EIOS_BASE}`);
});

process.on("SIGTERM", () => {
  console.log("Shutting down gracefully...");
  server.close(() => process.exit(0));
});
