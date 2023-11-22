-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

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
    channel_set_topic = function(channel, topic) irc.send_to_peer(peer, ":ladici 332 " .. nick .. ' ' .. channel .. ' :' .. (topic or '')) end,
    send_msg = function(msg, sender, channel)
                 receiver = channel or nick
                 irc.send_to_peer(peer, ':' .. sender .. ' PRIVMSG ' .. receiver .. ' :' .. msg)
               end,
    disconnect =
      function(channel)
        peer.accept_disable()

        irc.send_to_peer(peer, 'ERROR :Goodbye!')
      end,
  }
  local attached = false

  local function maybe_welcome()
    if not user or not nick then return end
    send(":ladici 001 " .. nick .. " Welcome to the Internet Relay Network " .. nick .. "!" .. user .. "@" .. host)

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
      return hub.outgoing_message(msg, params[1])
    end

  command_handlers['WHO'] =
    function(prefix, command, params)
      channel = hub.get_channel(params[1])
      if not channel then unknown_command(prefix, command, params) return end -- unknown channel
      for unick, uobj in pairs(channel.get_users(channel)) do
        irc.send_to_peer(peer, ":ladici 353 " .. nick .. ' = ' .. channel.name .. ' :' .. unick)
      end
      irc.send_to_peer(peer, ":ladici 353 " .. nick .. ' = ' .. channel.name .. ' :' .. nick)
      irc.send_to_peer(peer, ":ladici 366 " .. nick .. ' ' .. channel.name .. ' :End of NAMES list')
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
