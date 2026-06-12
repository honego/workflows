-- block.lua

local ngx = ngx
local exit = ngx.exit
local get_method = ngx.req.get_method
local regex_find = ngx.re.find
local string_byte = string.byte

-- 拦截隐藏文件、敏感配置和备份文件
local sensitive_path_pattern = [[
  (?:^|/)
  (?:
    \.(?!well-known(?:/|$))[^/]*(?:/|$)
    |
    (?:
      composer\.(?:json|lock)|package\.json|yarn\.lock|wp-config\.php|config\.php|settings\.php
      |database\.yml|secrets\.yaml|Thumbs\.db
    )$
    |
    [^/]+\.(?:bak|old|swp|sql|db|dump|pyc|pyo|sqlite|php~|conf~|ini~|log~|~)$
  )
]]

local first_byte = string_byte(get_method(), 1)

-- 拦截请求方法异常的探测请求
if first_byte and (first_byte < 65 or first_byte > 90) then
  return exit(444)
end

-- 命中敏感路径后直接关闭连接
if regex_find(ngx.var.uri or "", sensitive_path_pattern, "ijox") then
  return exit(444)
end
