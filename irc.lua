-- -*- Mode: Lua; indent-tabs-mode: t; lua-indent-level: 2 -*-
-- PERsonal MESsage HUb (permshu)
--
-- Copyright (C) 2010 Nedko Arnaudov <nedko@arnaudov.name>
--
-- permshu is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- permshu is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with permshu. If not, see <http://www.gnu.org/licenses/>
-- or write to the Free Software Foundation, Inc.,
-- 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.

local base = _G
local remotes = require('remotes')
local misc = require('misc')
module('irc')

local function parse_and_consume(buffer, regexp)
  local b = 0
  local e = 0
  b, e, a1, a2, a3, a4 = buffer:find(regexp)
  if not b then return buffer end
  rest = buffer:sub(e + 1)
  if rest == '' then rest = nil end
  return rest, a1, a2, a3, a4
end

function connect(args)
  base.assert(args.host)
  base.assert(args.nick)

  local host = args.host
  local port = args.port or 6667
  local nick = args.nick
  local username = args.username or nick
  local realname = args.realname or nick
  local peer

  local function send(msg)
    --base.print('-----send------' .. msg)
    peer.send(msg .. "\r\n")
  end

  local function print_notice(msg, prefix)
    if msg then
      if base.type(msg) == 'string' then base.print(prefix .. msg) end
      if base.type(msg) == 'table'  then base.print(prefix .. base.table.concat(msg, ' ')) end
    end
  end

  local server_capabilities = {}
  local command_handlers = {}

  command_handlers['PING'] = function(prefix, command, params)
                               --base.print("PING received")
                               if #params ~= 0 then
                                 local msg = "PONG"
                                 for _, server in base.pairs(params) do
                                   msg = msg .. ' ' .. server
                                 end
                                 send(msg)
                               end
                             end

  command_handlers['NOTICE'] = function(prefix, command, params) print_notice(params[2], 'NOTICE:  ') end

  command_handlers['MODE'] = function(prefix, command, params)
                               base.print(('MODE:    [%s] [%s]'):format(params[1], params[2]))
                             end

  -- welcome
  command_handlers['001'] = function(prefix, command, params) print_notice(base.table.concat(params, ' ', 2), 'WELCOME: ') end
  -- your host
  command_handlers['002'] = function(prefix, command, params) print_notice(base.table.concat(params, ' ', 2), 'SHOST:   ') end
  -- server created
  command_handlers['003'] = function(prefix, command, params) print_notice(base.table.concat(params, ' ', 2), 'SCREAT:  ') end
  -- server info
  command_handlers['004'] = function(prefix, command, params)
                              local server_name = params[2]
                              local server_version = params[3]
                              local user_modes_available = params[4]
                              local channel_modes_available = params[5]
                              print_notice(server_name, 'SNAME:   ')
                              print_notice(server_version, 'SVER:    ')
                              print_notice(user_modes_available, 'UMODES:  ')
                              print_notice(channel_modes_available, 'CMODES:  ')
                            end

  -- bounce / supported stuff
  command_handlers['005'] = function(prefix, command, params)
                              if #params > 2 then
                                for i = 2, #params - 1 do
                                  local param = params[i]
                                  local _, _, key, value = param:find('^([^=]+)=(.+)')
                                  if not key then
                                    base.print(('SCAPS:   %s is available'):format(param))
                                    key = param
                                    value = true
                                  else
                                    base.print(('SCAPS:   %s is [%s]'):format(key, value))
                                  end
                                  server_capabilities[key] = value
                                end
                              end
                            end

  local function stats_reply(prefix, command, params)
    print_notice(base.table.concat(params, ' ', 2), 'SSTATS:  ')
  end

  command_handlers['250'] = stats_reply
  command_handlers['251'] = stats_reply
  command_handlers['252'] = stats_reply
  command_handlers['253'] = stats_reply
  command_handlers['254'] = stats_reply
  command_handlers['255'] = stats_reply
  command_handlers['265'] = stats_reply
  command_handlers['266'] = stats_reply

  local function motd_reply(prefix, command, params)
    print_notice(base.table.concat(params, ' ', 2), 'MOTD:    ')
  end

  command_handlers['375'] = motd_reply -- MOTD start
  command_handlers['372'] = motd_reply -- MOTD middle
  command_handlers['376'] = motd_reply -- MOTD end

  local function receiver()
    local raw_msg, err = peer.receive()
    if not raw_msg then return nil, err end
    -- base.print('----receive----' .. base.tostring(raw_msg))

    local prefix
    local command
    local argstr
    local reset = raw_msg

    -- prefix
    reset, prefix = parse_and_consume(reset, "^:([^ ]*) *")
    --if prefix then base.print(("prefix: '%s'"):format(prefix)) end
    --if reset then base.print(("rest: '%s'"):format(reset)) end

    -- command and  params
    reset, command, params = parse_and_consume(reset, "^([^ ]*) *(.*)")
    --if command then base.print(("command: '%s'"):format(command)) end
    --if params then base.print(("params: '%s'"):format(params)) end
    base.assert(not reset)

    params_table = {}
    local param
    while params do
      params, param = parse_and_consume(params, '^:(.*)')
      if param then base.table.insert(params_table, param) break end
      params, param = parse_and_consume(params, '^ *([^ \r\n]+) *')
      base.table.insert(params_table, param)
    end

    if command_handlers[command] then
      command_handlers[command](prefix, command, params_table)
    else
      base.print('----receive----' .. base.tostring(raw_msg))
      -- if prefix then base.print(("prefix: '%s'"):format(prefix)) end
      -- base.print(("command: '%s'"):format(command))
      -- for _, param in base.pairs(params_table) do base.print('[' .. param .. ']') end
    end

    return true
  end

  local function get_info()
    base.print('host: ' .. peer:get_desciption())
    base.print('nick: ' .. nick)
    base.print('username: ' .. username)
    base.print('realname: ' .. realname)
  end

  peer, err = remotes.create_tcp(host, port, receiver)
  if not peer then return nil, err end

  send(("NICK %s"):format(nick))
  send(("USER %s %s %s :%s"):format(username, peer.local_ip, host, realname))
  return {send = send, get_info = get_info}
end

function serve()
  server = remotes.create_tcp_server({{host='*', port=6667}})
end
