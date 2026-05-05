// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 honeok <i@honeok.com>

const RSSHUB_ORIGINS = [
  { url: "http://86.38.200.13:1200", weight: 100 }, // Los Angeles
  { url: "http://107.173.38.166:1200", weight: 100 }, // Los Angeles
  { url: "http://97.64.36.218:8880", weight: 100 }, // Los Angeles
  { url: "http://74.211.110.28:1200", weight: 100 }, // Los Angeles
  { url: "http://74.48.42.9:1200", weight: 100 }, // Los Angeles
  { url: "http://192.9.251.97:9002", weight: 95 }, // San Jose
  { url: "http://23.95.61.212:1200", weight: 95 }, // Santa Clara
  { url: "http://172.83.158.142:1200", weight: 90 }, // Seattle
  { url: "http://107.173.181.24:1200", weight: 90 }, // Seattle
];

const MAX_UPSTREAM_TRIES = 3;
const UPSTREAM_TIMEOUT_MS = 15000;

const ERROR_PAGE_URLS = {
  403: "https://fastly.jsdelivr.net/gh/honeok/config@release/webserver/html/403.html",
  404: "https://fastly.jsdelivr.net/gh/honeok/config@release/webserver/html/404.html",
  500: "https://fastly.jsdelivr.net/gh/honeok/config@release/webserver/html/50x.html",
};

const RETRYABLE_STATUS_CODES = new Set([500, 502, 503, 504]);

export default {
  async fetch(request) {
    const requestUrl = new URL(request.url);

    // 按 path + query 哈希 保证同一个 RSS 路由优先命中同一后端
    const sortedOrigins = orderOriginsByWeightedHash(requestUrl.pathname + requestUrl.search, RSSHUB_ORIGINS);

    // 只有 GET / HEAD 自动重试
    // POST 等带 body 的请求不重试, 避免请求体被重复消费
    const isRetryableMethod = request.method === "GET" || request.method === "HEAD";

    const maxAttempts = isRetryableMethod ? Math.min(MAX_UPSTREAM_TRIES, sortedOrigins.length) : 1;

    for (let attemptIndex = 0; attemptIndex < maxAttempts; attemptIndex++) {
      const selectedOrigin = sortedOrigins[attemptIndex];
      const upstreamUrl = buildUpstreamUrl(request.url, selectedOrigin.url);

      try {
        const upstreamResponse = await fetchWithTimeout(
          upstreamUrl,
          buildProxyRequestOptions(request, requestUrl, upstreamUrl),
          UPSTREAM_TIMEOUT_MS,
        );

        // 403 / 404 重试, 直接返回自定义错误页。
        // 这类通常不是节点故障, 而是路由本身无权限或不存在
        if (upstreamResponse.status === 403 || upstreamResponse.status === 404) {
          await safelyCancelResponseBody(upstreamResponse);
          return renderErrorPage(upstreamResponse.status);
        }

        // 500 系列认为是后端节点异常 先尝试切换到下一个节点
        if (isRetryableMethod && RETRYABLE_STATUS_CODES.has(upstreamResponse.status)) {
          await safelyCancelResponseBody(upstreamResponse);

          if (attemptIndex < maxAttempts - 1) {
            continue;
          }

          return renderErrorPage(upstreamResponse.status);
        }

        return upstreamResponse;
      } catch (upstreamError) {
        // 当前节点连接失败 超时或 fetch 抛错时, 继续尝试下一个节点
        if (attemptIndex < maxAttempts - 1) {
          continue;
        }
      }
    }

    // 所有节点都不可用时返回 502, 并使用统一 50x 错误页
    return renderErrorPage(502);
  },
};

function buildUpstreamUrl(originalRequestUrl, originBaseUrl) {
  const requestUrl = new URL(originalRequestUrl);
  const originUrl = new URL(originBaseUrl);

  // 保留源站自己的协议 IP 端口
  // 例如:
  // http://86.38.200.13:1200 + /foo?bar=1
  // => http://86.38.200.13:1200/foo?bar=1
  return `${originUrl.origin}${requestUrl.pathname}${requestUrl.search}`;
}

function buildProxyRequestOptions(request, originalRequestUrl, upstreamUrl) {
  const proxyHeaders = new Headers(request.headers);
  const upstreamRequestUrl = new URL(upstreamUrl);

  // 保持源站自己的 Host
  // 例如:
  // http://86.38.200.13:1200 => Host: 86.38.200.13:1200
  // http://97.64.36.218:8880 => Host: 97.64.36.218:8880
  proxyHeaders.set("Host", upstreamRequestUrl.host);

  // 清理不适合透传给源站的边缘层头部
  proxyHeaders.delete("connection");
  proxyHeaders.delete("upgrade");
  proxyHeaders.delete("cf-connecting-ip");
  proxyHeaders.delete("cf-ipcountry");
  proxyHeaders.delete("cf-ray");
  proxyHeaders.delete("cf-visitor");

  const clientIp = request.headers.get("CF-Connecting-IP") || "";
  const existingForwardedFor = request.headers.get("X-Forwarded-For");

  if (clientIp) {
    proxyHeaders.set("X-Real-IP", clientIp);
    proxyHeaders.set("X-Forwarded-For", existingForwardedFor ? `${existingForwardedFor}, ${clientIp}` : clientIp);
  }

  proxyHeaders.set("X-Forwarded-Proto", originalRequestUrl.protocol.replace(":", ""));
  proxyHeaders.set("X-Forwarded-Host", originalRequestUrl.host);

  return {
    method: request.method,
    headers: proxyHeaders,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
    redirect: "manual",
  };
}

async function fetchWithTimeout(url, requestOptions, timeoutMilliseconds) {
  const abortController = new AbortController();

  const timeoutId = setTimeout(() => abortController.abort(), timeoutMilliseconds);

  try {
    return await fetch(url, {
      ...requestOptions,
      signal: abortController.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}

async function renderErrorPage(statusCode) {
  const errorPageUrl = getErrorPageUrl(statusCode);

  try {
    const errorPageResponse = await fetch(errorPageUrl, {
      cf: {
        cacheEverything: true,
        cacheTtl: 86400,
      },
    });

    if (errorPageResponse.ok) {
      return new Response(errorPageResponse.body, {
        status: statusCode,
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "no-store",
        },
      });
    }
  } catch (errorPageFetchError) {
    // 自定义错误页本身加载失败时, 走下面的纯文本 fallback
  }

  return new Response(`${statusCode} Error\n`, {
    status: statusCode,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function getErrorPageUrl(statusCode) {
  if (statusCode === 403) {
    return ERROR_PAGE_URLS[403];
  }

  if (statusCode === 404) {
    return ERROR_PAGE_URLS[404];
  }

  return ERROR_PAGE_URLS[500];
}

async function safelyCancelResponseBody(response) {
  try {
    await response.body?.cancel();
  } catch (cancelError) {
    // 忽略 body cancel 失败, 不影响主流程
  }
}

// 类 nginx: hash $request_uri consistent;
// 同一 RSS 路由会优先分配到同一个后端
// 使用带权重的 Rendezvous Hashing 节点增删时整体扰动较小
function orderOriginsByWeightedHash(hashKey, originConfigs) {
  return originConfigs
    .map((originConfig, originIndex) => {
      const hashValue = fnv1a(`${hashKey}|${originIndex}|${originConfig.url}`);

      const normalizedHash = Math.max((hashValue + 1) / 4294967296, Number.EPSILON);

      const weightedScore = originConfig.weight / -Math.log(normalizedHash);

      return {
        ...originConfig,
        score: weightedScore,
      };
    })
    .sort((leftOrigin, rightOrigin) => rightOrigin.score - leftOrigin.score);
}

function fnv1a(inputText) {
  let hashValue = 0x811c9dc5;

  for (let characterIndex = 0; characterIndex < inputText.length; characterIndex++) {
    hashValue ^= inputText.charCodeAt(characterIndex);
    hashValue = Math.imul(hashValue, 0x01000193);
  }

  return hashValue >>> 0;
}
