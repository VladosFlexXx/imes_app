const assert = require("node:assert");
const test = require("node:test");
const { isValidEiosUrl, getQuerySecretError } = require("../server/core");
const indexHandler = require("../server/index").handler;
const yandexHandler = require("../server/yandex_cloud_function").handler;

test("Server Security: isValidEiosUrl validation", () => {
  // Valid URLs
  assert.strictEqual(isValidEiosUrl("https://eos.imes.su/"), true);
  assert.strictEqual(isValidEiosUrl("https://eos.imes.su/my/"), true);
  assert.strictEqual(isValidEiosUrl("https://eos.imes.su:443/login/index.php"), true);
  assert.strictEqual(isValidEiosUrl("https://EOS.IMES.SU/user/profile.php"), true);

  // Invalid URLs (SSRF / Protocol / Host / Port / Userinfo)
  assert.strictEqual(isValidEiosUrl("http://eos.imes.su/"), false, "Must reject plain HTTP");
  assert.strictEqual(isValidEiosUrl("https://eos.imes.su.evil.com/"), false, "Must reject domain suffix attack");
  assert.strictEqual(isValidEiosUrl("https://evil.com/"), false, "Must reject foreign host");
  assert.strictEqual(isValidEiosUrl("https://eos.imes.su:8080/"), false, "Must reject non-443 port");
  assert.strictEqual(isValidEiosUrl("https://admin:pass@eos.imes.su/"), false, "Must reject userinfo in URL");
  assert.strictEqual(isValidEiosUrl("javascript:alert(1)"), false, "Must reject non-HTTP schemes");
  assert.strictEqual(isValidEiosUrl(""), false, "Must reject empty URL");
  assert.strictEqual(isValidEiosUrl(null), false, "Must reject null");
});

test("Server Security: getQuerySecretError rejects query secrets", () => {
  // Allowed query parameters
  assert.strictEqual(getQuerySecretError({ url: "https://eos.imes.su/my/" }), null);
  assert.strictEqual(getQuerySecretError({ action: "status" }), null);

  // Forbidden secrets
  assert.ok(getQuerySecretError({ password: "123" }), "Must reject ?password=");
  assert.ok(getQuerySecretError({ pass: "123" }), "Must reject ?pass=");
  assert.ok(getQuerySecretError({ cookie: "MoodleSession=abc" }), "Must reject ?cookie=");
  assert.ok(getQuerySecretError({ COOKIE: "abc" }), "Must reject case-insensitive ?COOKIE=");
});

test("Server Security: index.js and yandex handlers reject query secrets with 400", async () => {
  for (const handler of [indexHandler, yandexHandler]) {
    // 1. Password in query
    const resPass = await handler({
      httpMethod: "GET",
      queryStringParameters: { password: "secret_password" },
    });
    assert.strictEqual(resPass.statusCode, 400);
    assert.match(resPass.body, /Передача пароля в URL параметрах запрещена/);

    // 2. Cookie in query
    const resCookie = await handler({
      httpMethod: "GET",
      queryStringParameters: { url: "https://eos.imes.su/", cookie: "MoodleSession=123" },
    });
    assert.strictEqual(resCookie.statusCode, 400);
    assert.match(resCookie.body, /Передача cookie в URL параметрах запрещена/);

    // 3. Foreign host targetUrl rejected with 403
    const resForeign = await handler({
      httpMethod: "GET",
      queryStringParameters: { url: "https://evil.com/" },
    });
    assert.strictEqual(resForeign.statusCode, 403);
    assert.match(resForeign.body, /Доступ разрешен только к https:\/\/eos\.imes\.su/);
  }
});
