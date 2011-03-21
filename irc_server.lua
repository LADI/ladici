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

require 'hub'
require 'irc'

module('irc_server', package.seeall)

local function remote_client_thread(peer)
  print("Remote " .. peer.get_description() .. " connected")

  local function send(msg) irc.send_to_peer(peer, msg) end

  local user
  local realname
  local nick
  local host = peer.get_ip()

  local function nop() end
  local function unknown_command(prefix, command, params)
    msg = 'Unknown/wrong command [' .. command .. ']'
    if prefix then msg = msg .. ', prefix: [' .. prefix .. ']' end
    if params then
      msg = msg .. ', params:'
      for _,param in pairs(params) do
        msg = msg .. ' [' .. param .. ']'
      end
    end
    print(msg)
    send(msg)
  end

  local interface = {
    channel_join = function(channel) irc.send_to_peer(peer, ":" .. nick .. " JOIN " .. channel)  end,
    channel_set_topic = function(channel, topic) irc.send_to_peer(peer, ":permeshu 332 " .. nick .. ' ' .. channel .. ' :' .. (topic or '')) end,
    channel_send_msg = function(channel, sender, msg) irc.send_to_peer(peer, ':' .. sender .. ' PRIVMSG ' .. channel .. ' :' .. msg) end,
    disconnect =
      function(channel)
        peer.accept_disable()

        for name,location in pairs(locations.registry) do
          if location.connection then self:disconnect_location(name) end
        end

        irc.send_to_peer(peer, 'ERROR :Goodbye!')
      end,
  }
  local attached = false

  local function maybe_welcome()
    if not user or not nick then return end
    send(":permeshu 001 " .. nick .. " Welcome to the Internet Relay Network " .. nick .. "!" .. user .. "@" .. host)

    hub.attach_interface(interface)
    attached = true
  end

  local command_handlers = {}

  command_handlers[''] = unknown_command

  command_handlers['USER'] = function(prefix, command, params)
                               user = params[1]
                               realname = params[4]
                               if not nick then unknown_command(prefix, command, params) return end
                               maybe_welcome()
                             end
  command_handlers['PASS'] = nop
  command_handlers['NICK'] = function(prefix, command, params)
                               nick = params[1]
                               if not nick then unknown_command(prefix, command, params) return end
                               maybe_welcome()
                             end

  command_handlers['QUIT'] = function(prefix, command, params)
                               print(("Client is terminating its session [%s]"):format(tostring(params[1])))
                               send('ERROR :Goodbye!')
                               return true -- break the receive loop
                             end

  command_handlers['PRIVMSG'] =
    function(prefix, command, params)
      msg = params[2]
      if not msg then unknown_command(prefix, command, params) return end
      channel = hub.get_channel(params[1])
      if not channel then unknown_command(prefix, command, params) return end -- unknown channel
      return channel:privmsg(msg)
    end

  command_handlers['WHO'] =
    function(prefix, command, params)
      channel = hub.get_channel(params[1])
      if not channel then unknown_command(prefix, command, params) return end -- unknown channel
      for unick, uobj in pairs(channel.get_users(channel)) do
        irc.send_to_peer(peer, ":permeshu 353 " .. nick .. ' = ' .. channel.name .. ' :' .. unick)
      end
      irc.send_to_peer(peer, ":permeshu 353 " .. nick .. ' = ' .. channel.name .. ' :' .. nick)
      irc.send_to_peer(peer, ":permeshu 315 " .. nick .. ' ' .. channel.name .. ' :End of NAMES list')
    end

  command_handlers['MODE'] =
    function(prefix, command, params)
      channel = params[1]
      if not channel then unknown_command(prefix, command, params) return end
      -- irc.send_to_peer(peer, "MODE " .. channel .. ' +tn') -- TODO: maintain channel mode in hub
    end

  -- command_handlers['JOIN'] = function(prefix, command, params)
  --                         end

  local err = irc.receive(peer, command_handlers, function(msg) print(msg) end)

  if attached then
    hub.detach_interface(interface)
  end

  print(("Remote %s disconnected (%s)"):format(peer.get_description(), tostring(err)))
end

function create()
  print('Creating IRC server')
  err = remotes.create_tcp_server(remote_client_thread, {{host='*', port=6667}})
  if err then return err end
end
