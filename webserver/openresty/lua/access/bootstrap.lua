--
-- SPDX-License-Identifier: Apache-2.0
-- Description: The lua file is the OpenResty access phase entrypoint.
-- Copyright (c) 2026 honeok <i@honeok.com>

local block_malformed_methods = require("access.block_malformed_methods")
local block_ua = require("access.block_ua")
local block_sensitive_paths = require("access.block_sensitive_paths")

block_malformed_methods()
block_ua()
block_sensitive_paths()
