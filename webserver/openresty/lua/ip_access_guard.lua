--
-- SPDX-License-Identifier: Apache-2.0
-- Description: OpenResty Redis-backed IP ban check with shared-dict L1 cache.
-- Copyright (c) 2026 honeok <i@honeok.com>

local ngx = ngx
local exit = ngx.exit
local log = ngx.log
local WARN = ngx.WARN
local ERR = ngx.ERR
local HTTP_FORBIDDEN = ngx.HTTP_FORBIDDEN
local remote_addr = ngx.var.remote_addr

local redis = require("resty.redis")
local ip_ban_cache = ngx.shared.ip_ban_cache

local REDIS_HOST = "127.0.0.1"
local REDIS_PORT = 6379
local REDIS_TIMEOUT_MS = 50
local REDIS_KEEPALIVE_TIMEOUT_MS = 10000
local REDIS_KEEPALIVE_POOL_SIZE = 200

local CACHE_TTL_BAN = 60
local CACHE_TTL_PASS = 5
local CACHE_TTL_FAIL = 1

-- shared dict 缺失时放行 避免配置错误导致全站不可用
if not ip_ban_cache then
  log(ERR, "ip_ban_cache shared dict not found")
  return
end

-- IP 为空时放行 避免异常请求影响正常链路
if not remote_addr or remote_addr == "" then
  return
end

-- L1 缓存命中直接决策 减少 Redis 查询
local cached = ip_ban_cache:get(remote_addr)
if cached ~= nil then
  if cached == 1 then
    return exit(HTTP_FORBIDDEN)
  end

  return
end

local red = redis:new()
red:set_timeouts(REDIS_TIMEOUT_MS, REDIS_TIMEOUT_MS, REDIS_TIMEOUT_MS)

local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
if not ok then
  log(WARN, "redis connect failed: ", err)
  ip_ban_cache:set(remote_addr, 0, CACHE_TTL_FAIL)
  return
end

-- 封禁键存在即拒绝
local ban_key = "ban:ip:" .. remote_addr
local exists, exists_err = red:exists(ban_key)

if not exists then
  log(WARN, "redis exists failed: ", exists_err)
  ip_ban_cache:set(remote_addr, 0, CACHE_TTL_FAIL)
  red:close()
  return
end

if exists == 1 then
  ip_ban_cache:set(remote_addr, 1, CACHE_TTL_BAN)
  red:set_keepalive(REDIS_KEEPALIVE_TIMEOUT_MS, REDIS_KEEPALIVE_POOL_SIZE)
  return exit(HTTP_FORBIDDEN)
end

ip_ban_cache:set(remote_addr, 0, CACHE_TTL_PASS)
red:set_keepalive(REDIS_KEEPALIVE_TIMEOUT_MS, REDIS_KEEPALIVE_POOL_SIZE)
return
