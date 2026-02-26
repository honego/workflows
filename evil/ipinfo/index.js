export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 提取IP地址
    const ip = url.pathname.split("/")[1];
    if (!ip) {
      return new Response(JSON.stringify({ error: "Missing IP address in path" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 提取查询参数
    const db = url.searchParams.get("db") || "maxmind";
    const lang = url.searchParams.get("lang") || "en";

    // 构建缓存键
    const cacheUrl = new URL(request.url);
    const cacheKey = new Request(cacheUrl.toString(), request);
    const cache = caches.default;

    // 检查边缘缓存, 如果命中直接返回
    let response = await cache.match(cacheKey);
    if (response) {
      return response;
    }

    let upstreamUrl = "";
    let fetchOptions = {
      headers: { Accept: "application/json" },
    };

    try {
      // 核心路由: 根据 ?db= 参数选择上游服务并注入密钥
      switch (db.toLowerCase()) {
        case "abuseipdb":
          upstreamUrl = `https://api.abuseipdb.com/api/v2/check?ipAddress=${ip}`;
          fetchOptions.headers["Key"] = env.ABUSEIPDB_KEY;
          break;

        case "scamalytics":
          upstreamUrl = `https://api.scamalytics.com/${env.SCAMALYTICS_USER}/?ip=${ip}&key=${env.SCAMALYTICS_KEY}`;
          break;

        case "ip2location":
          upstreamUrl = `https://api.ip2location.io/?key=${env.IP2LOCATION_KEY}&ip=${ip}`;
          break;

        case "ipdata":
          upstreamUrl = `https://api.ipdata.co/${ip}?api-key=${env.IPDATA_KEY}`;
          break;

        case "ipqualityscore":
          upstreamUrl = `https://www.ipqualityscore.com/api/json/ip/${env.IPQS_KEY}/${ip}`;
          break;

        case "maxmind":
        default:
          upstreamUrl = `https://geoip.maxmind.com/geoip/v2.1/city/${ip}?lang=${lang}`;
          fetchOptions.headers["Authorization"] =
            `Basic ${btoa(env.MAXMIND_ACCOUNT_ID + ":" + env.MAXMIND_LICENSE_KEY)}`;
          break;
      }

      // 发起上游请求
      const apiResponse = await fetch(upstreamUrl, fetchOptions);

      if (!apiResponse.ok) {
        throw new Error(`Upstream API responded with status: ${apiResponse.status}`);
      }

      const data = await apiResponse.json();

      // 组装最终响应设置缓存控制头
      response = new Response(JSON.stringify(data), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "public, max-age=86400",
          "Access-Control-Allow-Origin": "*",
        },
      });

      // 异步写入缓存不阻塞当前请求的返回
      ctx.waitUntil(cache.put(cacheKey, response.clone()));

      return response;
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  },
};
