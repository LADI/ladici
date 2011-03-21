-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- PERsonal MESsage HUb (permshu)
--
-- Copyright (C) 2010, 2011 Nedko Arnaudov <nedko@arnaudov.name>
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

module('irc_client', package.seeall)

local function connect(location)
  assert(location.args.host)
  assert(location.args.nick)

  local host = location.args.host
  local port = location.args.port or 6667
  local nick = location.args.nick
  local username = location.args.username or nick
  local realname = location.args.realname or nick
  local join = location.args.join

  local print = function(msg) hub.deliver(location.name, msg) end

  local peer

  local function send(msg) irc.send_to_peer(peer, msg) end

  local function print_notice(msg, prefix)
    if msg then
      if type(msg) == 'string' then print(prefix .. msg) end
      if type(msg) == 'table'  then print(prefix .. table.concat(msg, ' ')) end
    end
  end

  local server_capabilities = {}
  local command_handlers = {}

  command_handlers['PING'] = function(prefix, command, params)
                               --print("PING received")
                               if #params ~= 0 then
                                 local msg = "PONG"
                                 for _, server in pairs(params) do
                                   msg = msg .. ' ' .. server
                                 end
                                 send(msg)
                               end
                             end

  command_handlers['NOTICE'] = function(prefix, command, params) print_notice(params[2], 'NOTICE:  ') end

  command_handlers['MODE'] = function(prefix, command, params)
                               print(('MODE:    [%s] [%s]'):format(params[1], params[2]))
                             end

  command_handlers['PRIVMSG'] =
    function(prefix, command, params)
      print(("'%s' -> '%s' : '%s'"):format(tostring(prefix), params[1], params[2]))
    end

  command_handlers['JOIN'] = function(prefix, command, params)
                               print(("'%s' joined '%s'"):format(prefix, params[1]))
                               -- local channel = channel:new()
                               -- channel.users['@permeshu'] = {}
                               -- channel.users[nick] = {}
                               -- channel:join(peer, params[1], nick)
                               -- channels[channel.name] = channel
                             end

  -- welcome
  command_handlers['001'] = function(prefix, command, params) print_notice(table.concat(params, ' ', 2), 'WELCOME: ') end
  -- your host
  command_handlers['002'] = function(prefix, command, params) print_notice(table.concat(params, ' ', 2), 'SHOST:   ') end
  -- server created
  command_handlers['003'] = function(prefix, command, params) print_notice(table.concat(params, ' ', 2), 'SCREAT:  ') end
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
                                    print(('SCAPS:   %s is available'):format(param))
                                    key = param
                                    value = true
                                  else
                                    print(('SCAPS:   %s is [%s]'):format(key, value))
                                  end
                                  server_capabilities[key] = value
                                end
                              end
                            end

  local function stats_reply(prefix, command, params)
    print_notice(table.concat(params, ' ', 2), 'SSTATS:  ')
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
    print_notice(table.concat(params, ' ', 2), 'MOTD:    ')
  end

  command_handlers['375'] = motd_reply -- MOTD start
  command_handlers['372'] = motd_reply -- MOTD middle
  command_handlers['376'] = motd_reply -- MOTD end

  peer, err = remotes.connect_tcp(host, port)
  if not peer then return nil, err end

  local disconnect_function = nil
  remotes.add_thread(function()
                       send(("NICK %s"):format(nick))
                       send(("USER %s %s %s :%s"):format(username, peer.get_local_ip(), host, realname))
                       if join then send("JOIN " .. join) end
                       err = irc.receive(peer, command_handlers, function(msg) print(msg) end)
                       -- print(err)
                       peer.close()
                       if disconnect_function then
                         -- print("Calling disconnect callback")
                         disconnect_function()
                       end
                       peer = nil
                     end)
  return {
    disconnect = function(disconnect_function_param)
                   print("Disconnecting from " .. host)
                   peer.close()         -- this will break the receive loop
                   disconnect_function = disconnect_function_param
                 end,
    send = send
  }
end

local descriptor = {
  name = 'IRC',
  required_params = {
    host="IP address or a host name if IRC server",
    nick="Nickname",
  },
  optional_params = {
    port="TCP port, defaults to 6667",
    username="Username, defaults to nick",
    realname="Real name, defaults to nick",
  },
  connect=connect,
}

protocols.register(descriptor)

return {}                       -- nothing directly public here
