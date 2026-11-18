/**
 * Единое ядро валидации и безопасности для шлюзов MyIMES (Node.js & Serverless).
 */

const EIOS_BASE = "https://eos.imes.su";

/**
 * Строгая проверка адреса назначения:
 * - Схема строго https:
 * - Хост строго eos.imes.su
 * - Порт пустой или 443
 * - Никаких учетных данных в URL (user:pass@)
 */
function isValidEiosUrl(urlString) {
  if (!urlString || typeof urlString !== "string") return false;
  try {
    const parsed = new URL(urlString);
    if (parsed.protocol !== "https:") return false;
    if (parsed.hostname.toLowerCase() !== "eos.imes.su") return false;
    if (parsed.port !== "" && parsed.port !== "443") return false;
    if (parsed.username || parsed.password) return false;
    return true;
  } catch (_) {
    return false;
  }
}

/**
 * Проверка на наличие секретов в URL параметрах (query string).
 * Возвращает текст ошибки, если обнаружен секрет, иначе null.
 */
function getQuerySecretError(query) {
  if (!query || typeof query !== "object") return null;

  const keys = Object.keys(query).map((k) => k.toLowerCase());
  if (keys.includes("password") || keys.includes("pass")) {
    return "Передача пароля в URL параметрах запрещена. Передавайте пароль в теле POST запроса.";
  }
  if (keys.includes("cookie")) {
    return "Передача cookie в URL параметрах запрещена. Используйте заголовок x-cookie-header.";
  }
  return null;
}

class CookieJar {
  constructor() {
    this.cookies = new Map();
  }

  setFromHeaders(headers) {
    let setCookies = [];
    if (typeof headers.getSetCookie === "function") {
      setCookies = headers.getSetCookie();
    } else {
      const raw = headers.get ? headers.get("set-cookie") : headers["set-cookie"];
      if (raw) setCookies = Array.isArray(raw) ? raw : [raw];
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

/**
 * Безопасный запрос с ручной обработкой редиректов:
 * - Проверяет каждый шаг через isValidEiosUrl.
 * - При выходе за пределы eos.imes.su прекращает переходы и не передает cookie.
 */
async function fetchWithRedirects(url, options = {}, jar = new CookieJar(), maxHops = 6) {
  let currentUrl = url;
  let currentMethod = options.method || "GET";
  let currentBody = options.body;
  const baseHeaders = options.headers || {};

  if (!isValidEiosUrl(currentUrl)) {
    throw new Error("Запрещенный адрес назначения: " + currentUrl);
  }

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

    const nextUrl = new URL(loc, currentUrl).toString();
    if (!isValidEiosUrl(nextUrl)) {
      // Редирект ведет за пределы ЭИОС — останавливаемся без передачи учетных данных
      return { response: res, finalUrl: currentUrl };
    }

    currentUrl = nextUrl;
    if (res.status === 303 || (res.status === 302 && currentMethod === "POST")) {
      currentMethod = "GET";
      currentBody = undefined;
    }
  }

  throw new Error("Too many redirects");
}

module.exports = {
  EIOS_BASE,
  isValidEiosUrl,
  getQuerySecretError,
  CookieJar,
  fetchWithRedirects,
};
