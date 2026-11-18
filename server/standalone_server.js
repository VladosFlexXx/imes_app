const http = require("node:http");
const {
  EIOS_BASE,
  isValidEiosUrl,
  getQuerySecretError,
  CookieJar,
  fetchWithRedirects,
} = require("./core");

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "0.0.0.0";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS, PUT, DELETE",
  "Access-Control-Allow-Headers": "Content-Type, x-cookie-header, x-target-url, Accept, Authorization",
  "Access-Control-Max-Age": "86400",
};

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

  // Проверка секретов в URL параметрах
  const secretError = getQuerySecretError(query);
  if (secretError) {
    sendResponse(
      res,
      400,
      { ...dynamicCors, "Content-Type": "application/json" },
      JSON.stringify({ error: secretError })
    );
    return;
  }

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

      const username = bodyData.username || bodyData.login;
      const password = bodyData.password || bodyData.pass;

      if (!username || !password) {
        sendResponse(
          res,
          400,
          { ...dynamicCors, "Content-Type": "application/json" },
          JSON.stringify({ error: "Missing login credentials in request body" })
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
      const isLoginPage = myFinalUrl.includes("/login") || 
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
    const cookieHeader = req.headers["x-cookie-header"] || "";

    if (!targetUrl) {
      sendResponse(
        res,
        200,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify({
          status: "ok",
          service: "MyIMES Proxy & Backup Server",
          usage: "Pass x-target-url header pointing to https://eos.imes.su",
          time: new Date().toISOString(),
        })
      );
      return;
    }

    if (!isValidEiosUrl(targetUrl)) {
      sendResponse(
        res,
        403,
        { ...dynamicCors, "Content-Type": "application/json" },
        JSON.stringify({ error: "Доступ разрешен только к https://eos.imes.su (порт 443)" })
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

    let currentProxyUrl = targetUrl;
    let upstreamRes;
    for (let hop = 0; hop <= 6; hop++) {
      if (!isValidEiosUrl(currentProxyUrl)) {
        sendResponse(
          res,
          403,
          { ...dynamicCors, "Content-Type": "application/json" },
          JSON.stringify({ error: "Редирект на сторонний адрес запрещен" })
        );
        return;
      }

      upstreamRes = await fetch(currentProxyUrl, {
        method: method,
        headers: proxyHeaders,
        body: method === "POST" && rawBody ? rawBody : undefined,
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
});

module.exports = server;
