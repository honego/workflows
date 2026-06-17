--
-- SPDX-License-Identifier: Apache-2.0
-- Description: The lua file blocks access to sensitive paths, path traversal, and sensitive files in OpenResty.
-- Copyright (c) 2026 honeok <i@honeok.com>

local ngx = ngx
local exit = ngx.exit
local get_method = ngx.req.get_method
local log = ngx.log
local regex_find = ngx.re.find
local string_byte = string.byte

-- 拦截敏感路径和文件
local sensitive_path_pattern = [[
  (?:^|/)
  (?:
    \.(?!well-known(?:/|$))[^/]+
    |
    (?:web|meta)-inf
    |
    [^/]*(?:
      config|settings?|secrets?|credentials?|database
      |service[-_.]?accounts?|access[-_.]?tokens?|private[-_.]?keys?
    )[^/]*\.(?:php|ya?ml|json|xml)
    |
    (?:config|conf|configuration|secrets?|credentials?)/
    (?:[^/]+/)*[^/]+\.(?:php|ya?ml|json|ini|conf(?:ig)?|toml|xml|properties)
    |
    [^/]+[-.]lock(?:[-.][^/]+)?
    |
    [^/]+\.(?:
      log(?:\.\d+)?|bak|backup|bkp|old|orig|save|copy|tmp|temp|sw[op]
      |sql|db|dump|sqlite3?|py[co]|inc|src|tfstate|tfvars(?:\.json)?
      |conf(?:ig)?|ini|properties|toml|key|p12|pfx|jks|keystore
    )
    |
    [^/]+~
    |
    [^/]*(?:private[-_.]?key|service[-_.]?account|client[-_.]?(?:secret|credentials?))[^/]*\.pem
    |
    id_(?:rsa|dsa|ecdsa|ed25519)
    |
    phpinfo(?:[-_.][^/]*)?\.php
    |
    (?:server|nginx|stub)[-_.]?(?:status|info)
    |
    actuator(?!/health(?:/|$))
  )
  (?:[;/]|$)
]]

-- 拦截原始请求中的路径穿越
local raw_traversal_pattern = [[(?:\.\.|%2e%2e|%252e%252e)(?:/|\\|%2f|%5c|%252f|%255c)]]

local method_first_byte = string_byte(get_method() or "", 1)

-- 拦截请求方法异常的探测请求
if not method_first_byte or method_first_byte < 65 or method_first_byte > 90 then
  return exit(444)
end

-- raw_request_uri 保留原始请求用于拦截编码路径穿越
-- normalized_uri 用于匹配敏感路径
local normalized_uri = ngx.var.uri or ""
local raw_request_uri = ngx.var.request_uri or ""

-- 拦截 ../ ..\ 及其 URL 编码变体
local raw_traversal_from, _raw_traversal_to, raw_traversal_err =
  regex_find(raw_request_uri, raw_traversal_pattern, "ijo")

if raw_traversal_err then
  log(ngx.ERR, "failed to evaluate raw traversal pattern: ", raw_traversal_err)
  return exit(444)
end

if raw_traversal_from then
  return exit(444)
end

-- 拦截敏感路径和敏感文件
local sensitive_path_from, _sensitive_path_to, sensitive_path_err =
  regex_find(normalized_uri, sensitive_path_pattern, "ijox")

if sensitive_path_err then
  log(ngx.ERR, "failed to evaluate sensitive path pattern: ", sensitive_path_err)
  return exit(444)
end

if sensitive_path_from then
  return exit(444)
end
