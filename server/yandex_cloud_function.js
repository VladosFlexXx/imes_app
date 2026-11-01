/**
 * Yandex Cloud Function: Прокси и авторизация для ЭИОС ИМЭС (eos.imes.su)
 * Runtime: Node.js 18 или 20 (не требует сторонних библиотек, использует встроенный fetch)
 */

const EIOS_BASE = 'https://eos.imes.su';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-cookie-header, x-target-url',
  'Access-Control-Max-Age': '86400',
};

module.exports.handler = async function (event, context) {
  const method = (event.httpMethod || 'GET').toUpperCase();

  // 1. Ответ на CORS preflight
  if (method === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: CORS_HEADERS,
      body: '',
    };
  }

  try {
    const path = event.path || '/';
    const headers = event.headers || {};

    // 2. Эндпоинт авторизации: POST /login
    if (method === 'POST' && (path.endsWith('/login') || event.url?.includes('/login'))) {
      let bodyData = {};
      try {
        const rawBody = event.isBase64Encoded 
          ? Buffer.from(event.body, 'base64').toString('utf-8')
          : (event.body || '{}');
        bodyData = JSON.parse(rawBody);
      } catch (_) {
        return {
          statusCode: 400,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          body: JSON.stringify({ error: 'Неверный формат JSON' }),
        };
      }

      const { username, password } = bodyData;
      if (!username || !password) {
        return {
          statusCode: 400,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          body: JSON.stringify({ error: 'Логин и пароль обязательны' }),
        };
      }

      // Отправляем форму входа в Moodle
      const formParams = new URLSearchParams();
      formParams.append('username', username.trim());
      formParams.append('password', password);

      const loginRes = await fetch(`${EIOS_BASE}/login/index.php`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        },
        body: formParams.toString(),
        redirect: 'manual', // перехватываем редирект и куки
      });

      // Собираем куки
      let cookies = [];
      if (typeof loginRes.headers.getSetCookie === 'function') {
        cookies = loginRes.headers.getSetCookie();
      } else {
        const raw = loginRes.headers.get('set-cookie');
        if (raw) cookies = [raw];
      }

      const moodleCookie = cookies.find(c => c.includes('MoodleSession='));
      const location = loginRes.headers.get('location') || '';

      // Если в Moodle ошибка логина, он обычно редиректит на login/index.php или возвращает HTML с ошибкой
      const isFailed = location.includes('/login/index.php') || (!moodleCookie && loginRes.status === 200);

      if (isFailed || !moodleCookie) {
        return {
          statusCode: 401,
          headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          body: JSON.stringify({ 
            success: false, 
            error: 'Неверный логин или пароль от ЭИОС' 
          }),
        };
      }

      const cookieVal = moodleCookie.split(';')[0].trim();

      return {
        statusCode: 200,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          success: true,
          cookie: cookieVal,
        }),
      };
    }

    // 3. Эндпоинт проксирования данных: GET /proxy?url=...
    const targetUrl = headers['x-target-url'] || event.queryStringParameters?.url;
    const cookieHeader = headers['x-cookie-header'] || '';

    if (!targetUrl) {
      return {
        statusCode: 200,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          status: 'ok', 
          service: 'MyIMES Proxy', 
          time: new Date().toISOString() 
        }),
      };
    }

    // Защита: разрешаем проксировать только запросы на сайт вуза
    if (!targetUrl.startsWith(EIOS_BASE)) {
      return {
        statusCode: 403,
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Запрещено: прокси только для eos.imes.su' }),
      };
    }

    const eiosRes = await fetch(targetUrl, {
      method: method,
      headers: {
        'Cookie': cookieHeader,
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      },
      redirect: 'follow',
    });

    const responseText = await eiosRes.text();
    const contentType = eiosRes.headers.get('content-type') || 'text/html; charset=utf-8';

    return {
      statusCode: eiosRes.status,
      headers: {
        ...CORS_HEADERS,
        'Content-Type': contentType,
      },
      body: responseText,
    };
  } catch (err) {
    return {
      statusCode: 500,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: err.message || 'Ошибка проксирования' }),
    };
  }
};
