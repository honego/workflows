// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2025-2026 honeok <i@honeok.com>

const EMOJI_BASE = 127397;
const ISO_REGEX = /^[A-Z]{2}$/;
const WARP_ASNS = new Set([13335, 209242]);
const TZ_CACHE = new Map();

// 国旗转换
function getFlag(countryCode) {
  if (!countryCode || !ISO_REGEX.test(countryCode)) return undefined;
  try {
    return String.fromCodePoint(EMOJI_BASE + countryCode.charCodeAt(0), EMOJI_BASE + countryCode.charCodeAt(1));
  } catch (error) {
    return undefined;
  }
}

// 获取 Flag 的 Unicode 字符串
function getFlagUnicode(countryCode) {
  if (!countryCode || !ISO_REGEX.test(countryCode)) return undefined;
  try {
    const hex1 = (EMOJI_BASE + countryCode.charCodeAt(0)).toString(16).toUpperCase();
    const hex2 = (EMOJI_BASE + countryCode.charCodeAt(1)).toString(16).toUpperCase();
    return `U+${hex1} U+${hex2}`;
  } catch (error) {
    return undefined;
  }
}

// 获取 WARP 状态
function getWarp(asn) {
  if (!asn) return "off";
  return WARP_ASNS.has(Number(asn)) ? "on" : "off";
}

// 获取时区偏移量
function getOffset(tz) {
  if (!tz) return undefined;
  if (TZ_CACHE.has(tz)) return TZ_CACHE.get(tz);
  try {
    const now = new Date();
    const utcDate = new Date(now.toLocaleString("en-US", { timeZone: "UTC", hour12: false }));
    const tzDate = new Date(now.toLocaleString("en-US", { timeZone: tz, hour12: false }));
    const offset = Math.round((tzDate.getTime() - utcDate.getTime()) / 1000);

    if (TZ_CACHE.size < 500) TZ_CACHE.set(tz, offset);
    return offset;
  } catch (error) {
    return undefined;
  }
}

export default {
  async fetch(request) {
    const reqUrl = new URL(request.url);
    const reqPath = reqUrl.pathname;

    // 处理图标请求
    if (reqPath === "/favicon.ico") {
      const userAgent = request.headers.get("User-Agent");
      if (userAgent) {
        return Response.redirect(
          "https://fastly.jsdelivr.net/gh/devicons/devicon@latest/icons/linux/linux-original.svg",
          301,
        );
      }
      return new Response(null, { status: 204 });
    }

    // 提取通用变量
    const clientIP = request.headers.get("CF-Connecting-IP") || "127.0.0.1";
    const cfData = request.cf || {};

    // 全局 CORS 头 确保前端直接 Fetch 不被拦截
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
    };

    // 根路径仅返回 IP
    if (reqPath === "/") {
      return new Response(clientIP + "\n", {
        headers: {
          ...corsHeaders,
          "Content-Type": "text/plain; charset=utf-8",
        },
      });
    }

    // JSON 返回详细信息
    if (reqPath === "/json") {
      const resData = {
        ip: clientIP,
        asn: cfData.asn,
        org: cfData.asOrganization,
        continent: cfData.continent,
        country: cfData.country,
        region: cfData.region,
        regionCode: cfData.regionCode,
        city: cfData.city,
        emoji: getFlag(cfData.country),
        emoji_unicode: getFlagUnicode(cfData.country),
        postalCode: cfData.postalCode,
        metroCode: cfData.metroCode,
        latitude: cfData.latitude,
        longitude: cfData.longitude,
        offset: getOffset(cfData.timezone),
        timezone: cfData.timezone,
        colo: cfData.colo,
        warp: getWarp(cfData.asn),
      };

      const resJson = JSON.stringify(resData, null, 2);
      return new Response(resJson, {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json; charset=utf-8",
        },
      });
    }

    // 避免异常路径穿透
    return new Response("Not Found", { status: 404 });
  },
};
