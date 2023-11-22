-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

module('irc', package.seeall)

local function parse_and_consume(buffer, regexp)
  local b = 0
  local e = 0
  b, e, a1, a2, a3, a4 = buffer:find(regexp)
  if not b then return buffer end
  rest = buffer:sub(e + 1)
  if rest == '' then rest = nil end
  return rest, a1, a2, a3, a4
end

function parse_nick_prefix(prefix)
  rest = prefix
  b, e, host = rest:find('@(.+)')
  if not b then
    host = nil
  else
    rest = rest:sub(0, b - 1)
  end
  b, e, user = rest:find('!(.+)')
  if not b then
    user = nil
    nick = rest
  else
    nick = rest:sub(0, b - 1)
  end

  return nick, user, host
end

local function process_raw_msg(command_handlers, raw_msg, deliver)
  -- print('----receive----' .. tostring(raw_msg))

  local prefix
  local command
  local rest = raw_msg

  -- prefix
  rest, prefix = parse_and_consume(rest, "^:([^ ]*) *")
  --if prefix then print(("prefix: '%s'"):format(prefix)) end
  --if rest then print(("rest: '%s'"):format(rest)) end

  -- command and  params
  rest, command, params = parse_and_consume(rest, "^([^ ]*) *(.*)")
  --if command then print(("command: '%s'"):format(command)) end
  --if params then print(("params: '%s'"):format(params)) end
  assert(not rest)

  params_table = {}
  local param
  while params do
    params, param = parse_and_consume(params, '^:(.*)')
    if param then table.insert(params_table, param) break end
    params, param = parse_and_consume(params, '^ *([^ \r\n]+) *')
    table.insert(params_table, param)
  end

  local ret

  if command_handlers[command] then
    ret = command_handlers[command](prefix, command, params_table)
  elseif command_handlers[''] then
    ret = command_handlers[''](prefix, command, params_table)
  else
    -- print('----receive----' .. tostring(raw_msg))
    -- if prefix then print(("prefix: '%s'"):format(prefix)) end
    -- print(("command: '%s'"):format(command))
    -- for _, param in pairs(params_table) do print('[' .. param .. ']') end
    msg = 'Unknown msg [' .. command .. ']'
    if prefix then msg = msg .. ', prefix: [' .. prefix .. ']' end
    if params_table then
      msg = msg .. ', params:'
      for _,param in pairs(params_table) do
        msg = msg .. ' [' .. param .. ']'
      end
    end
    deliver(msg)
  end

  return ret
end

function receive(peer, command_handlers, deliver)
  local buffer
  while true do
    local raw_msg
    local data, err = peer.receive(4000)
    -- print('[' .. tostring(data) .. ']')
    -- print('[' .. tostring(err) .. ']')
    if not data then return err end

    if buffer then
      buffer = buffer .. data
    else
      buffer = data
    end

    -- print('---> [' .. tostring(buffer) .. ']')
    while buffer do
      buffer, raw_msg = parse_and_consume(buffer, '^([^\r\n]*)\r\n')
      -- print('[' .. tostring(buffer) .. ']')
      -- print('[' .. tostring(raw_msg) .. ']')
      if not raw_msg then break end
      if process_raw_msg(command_handlers, raw_msg, deliver) then return end
    end
  end
  assert(false)
end

function send_to_peer(peer, msg)
  -- print('-----send------' .. msg)
  peer.send(msg .. "\r\n")
end
