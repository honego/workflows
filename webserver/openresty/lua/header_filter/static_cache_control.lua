-- 从 nginx 变量中读取静态资源兜底缓存策略
local static_cache_control = ngx.var.static_cache_control

-- 当前 uri 没有匹配静态资源缓存规则 直接跳过
if static_cache_control == nil or static_cache_control == "" then
  return
end

-- 当前响应状态码
local response_status = ngx.status

-- 当前响应头对象
local response_headers = ngx.header

-- 只处理正常响应和 Range 响应
-- 200: 普通成功响应
-- 206: Range / Partial Content 响应, 常见于媒体 断点请求等
local is_cacheable_status = response_status == 200 or response_status == 206
if not is_cacheable_status then
  return
end

-- 如果上游返回了 Set-Cookie, 说明响应可能和用户状态有关 不补缓存
local has_set_cookie = response_headers["Set-Cookie"] ~= nil
if has_set_cookie then
  return
end

-- 如果上游已经返回缓存策略, 尊重上游不覆盖
local has_cache_control = response_headers["Cache-Control"] ~= nil
local has_expires = response_headers["Expires"] ~= nil
if has_cache_control or has_expires then
  return
end

-- 上游没有缓存策略时, 才由 openresty 补充静态资源缓存头
response_headers["Cache-Control"] = static_cache_control
