--
-- SPDX-License-Identifier: Apache-2.0
-- Description: The lua file is used to block obvious malicious User-Agent requests in OpenResty.
-- Copyright (c) 2026 honeok <i@honeok.com>

local ngx = ngx
local var = ngx.var
local exit = ngx.exit
local log = ngx.log
local re_find = ngx.re.find
local ERR = ngx.ERR
local WARN = ngx.WARN
local strlen = string.len

local function request_value(value)
  if value == nil or value == "" then
    return "-"
  end
  return value
end

local function log_reject(reason, user_agent)
  log(
    WARN,
    "ua_ban: reason=",
    reason,
    ", remote_addr=",
    request_value(var.remote_addr),
    ", request_uri=",
    request_value(var.request_uri),
    ", user_agent=",
    request_value(user_agent)
  )
end

local function reject(reason, user_agent)
  log_reject(reason, user_agent)
  return exit(444)
end

local function regex_found(pattern, user_agent)
  local from, _, err = re_find(user_agent, pattern, "ijox")

  if err then
    log(
      ERR,
      "ua_ban: reason=regex_error",
      ", remote_addr=",
      request_value(var.remote_addr),
      ", request_uri=",
      request_value(var.request_uri),
      ", user_agent=",
      request_value(user_agent),
      ", error=",
      err
    )
    return exit(444)
  end

  return from ~= nil
end

-- 本地监控和指定 AI UA 固定放行 避免被后续 UA 规则误伤
local allowed_ua_pattern = [[
  (?:
    ^ Uptime-Kuma (?: / [A-Za-z0-9._+-]+ )? $

    | (?: ^ | [^A-Za-z0-9] )
      (?:
        GPTBot
        | OAI-SearchBot
        | OAI-AdsBot
        | ChatGPT-User
        | ClaudeBot
        | Claude-User
        | Claude-SearchBot
        | anthropic-ai
        | PerplexityBot
        | Perplexity-User
        | Applebot-Extended
        | GoogleOther
        | Google-CloudVertexBot
        | Bytespider
        | CCBot
        | Diffbot
        | omgilibot
        | YouBot
        | Meta-ExternalAgent
        | meta-externalagent
        | meta-externalfetcher
        | cohere-ai
        | AI2Bot
      )
      (?: / | [^A-Za-z0-9] | $ )
  )
]]

-- 拦截特征明确的 UA
local deny_rules = {
  {
    reason = "attack_payload_user_agent",
    pattern = [[
      \$ \{ \s* jndi \s* :
    ]],
  },
  {
    reason = "cli_downloader_user_agent",
    pattern = [[
      (?: ^ | [^A-Za-z0-9] )
      (?: curl | wget | httpie )
      (?: / | [^A-Za-z0-9] | $ )
    ]],
  },
  {
    reason = "script_client_user_agent",
    pattern = [[
      (?: ^ | [^A-Za-z0-9] )
      (?:
        python-requests
        | python-urllib
        | urllib3
        | aiohttp
        | httpx
        | Go-http-client
        | libwww-perl
        | lwp-trivial
        | okhttp
        | Apache-HttpClient
        | node-fetch
        | axios
        | GuzzleHttp
        | powershell
        | WinHTTP
        | WinHttpRequest
      )
      (?: / | [^A-Za-z0-9] | $ )
    ]],
  },
  {
    reason = "scanner_user_agent",
    pattern = [[
      (?: ^ | [^A-Za-z0-9] )
      (?:
        sqlmap
        | nikto
        | nmap
        | masscan
        | zgrab
        | zmap
        | nuclei
        | wpscan
        | acunetix
        | nessus
        | openvas
        | netsparker
        | metasploit
        | dirbuster
        | gobuster
        | dirsearch
        | feroxbuster
        | ffuf
        | wfuzz
        | hydra
      )
      (?: / | [^A-Za-z0-9] | $ )
    ]],
  },
  {
    reason = "measurement_user_agent",
    pattern = [[
      (?:
        (?: ^ | [^A-Za-z0-9] )
        (?:
          CensysInspect
          | Shodan
          | Shodan-Pull
          | ZoomEye
          | BinaryEdge
          | LeakIX
          | GreyNoise
          | InternetMeasurement
          | Cortex-Xpanse
          | GenomeCrawlerd
        )
        (?: / | [^A-Za-z0-9] | $ )

        | Palo \s+ Alto \s+ Networks
      )
    ]],
  },
}

return function()
  local user_agent = var.http_user_agent
  local uri = var.uri
  local method = var.request_method

  -- 公开爬虫策略文件 允许正常读取
  if uri == "/robots.txt" and (method == "GET" or method == "HEAD") then
    return
  end

  -- 空 UA 基本都是探测 脚本或异常客户端 直接断开
  if user_agent == nil or user_agent == "" or user_agent == "-" then
    return reject("empty_user_agent", user_agent)
  end

  -- 异常超长 UA 没有正常业务价值 避免日志污染和规则绕过
  if strlen(user_agent) > 512 then
    return reject("oversized_user_agent", user_agent)
  end

  if regex_found([[ ^ \s* $ ]], user_agent) then
    return reject("empty_user_agent", user_agent)
  end

  if regex_found(allowed_ua_pattern, user_agent) then
    return
  end

  for i = 1, #deny_rules do
    local rule = deny_rules[i]

    if regex_found(rule.pattern, user_agent) then
      return reject(rule.reason, user_agent)
    end
  end
end
