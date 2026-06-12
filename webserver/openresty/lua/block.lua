--
-- SPDX-License-Identifier: Apache-2.0
-- Description: The lua file is use openresty sensitive path blocking rules based on OWASP core rule set 3.4.0.
-- Copyright (c) 2026 honeok <i@honeok.com>
--
-- block.lua

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

local first_byte = string_byte(get_method() or "", 1)

-- 拦截请求方法异常的探测请求
if not first_byte or first_byte < 65 or first_byte > 90 then
  return exit(444)
end

local uri = ngx.var.uri or ""

-- 拦截敏感路径
local matched, _, err = regex_find(uri, sensitive_path_pattern, "ijox")

if err then
  log(ngx.ERR, "failed to evaluate sensitive path pattern: ", err)
  return exit(444)
end

if matched then
  return exit(444)
end
