-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
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

require 'misc'
require 'protocols'
require 'hub'

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

local function receive(peer, command_handlers, deliver)
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

local function send_to_peer(peer, msg)
  -- print('-----send------' .. msg)
  peer.send(msg .. "\r\n")
end

function connect(location)
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

  local function send(msg) send_to_peer(peer, msg) end

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
                       err = receive(peer, command_handlers, function(msg) print(msg) end)
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

channel = {users={}}
function channel:new()
  o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function channel:set_topic(topic)
  self.topic = topic
end

function channel:join(peer, name, nick)
  self.peer = peer
  self.name = name
  self.nick = nick
  send_to_peer(self.peer, ":" .. self.nick .. " JOIN " .. self.name)
  send_to_peer(self.peer, ":permeshu 332 " .. self.nick .. ' ' .. self.name .. ' :' .. (self.topic or ''))
  --self:who()
end

function channel:who()
  for nick, user in pairs(self.users) do
    send_to_peer(self.peer, ":permeshu 353 " .. self.nick .. ' = ' .. self.name .. ' :' .. nick)
  end
  send_to_peer(self.peer, ":permeshu 315 " .. self.nick .. ' ' .. self.name .. ' :End of NAMES list')
end

function channel:mode()
--  send_to_peer(self.peer, "MODE " .. self.name .. ' +tn')
end

local control_channel = channel:new()

function control_channel:join(peer, nick)
  self:set_topic('permeshu control channel')
  self.users['@permeshu'] = {}
  self.users[nick] = {}
  channel.join(self, peer, '&control', nick)
end

function control_channel:send_reply(msg)
  send_to_peer(self.peer, ':permeshu PRIVMSG ' .. self.name .. ' :' .. msg)
end

function control_channel:disconnect_location(name)
  location = locations.registry[name]
  assert(location.connection)
  location.connection.disconnect(function()
                                   self:send_reply("Location [" .. name .. "] disconnected successfully")
                                   location.connection = nil
                                 end)
end

function control_channel:privmsg(command)
  commands = {}
  commands['quit'] =
    function()
      self.peer.accept_disable()

      for name,location in pairs(locations.registry) do
        if location.connection then self:disconnect_location(name) end
      end

      send_to_peer(self.peer, 'ERROR :Goodbye!')
      return true -- break the receive loop
    end

  commands['locations'] =
    function()
      for name, dict in pairs(locations.registry) do
        if dict.connection then status = "connected" else status = "disconnected" end
        self:send_reply(("%s\t- %s"):format(name, status))
      end
    end

  commands['connect'] =
    function()
      location = locations.registry['freenode']

      if location.connection then
        self:send_reply("Location is already connected")
        return
      end

      connection, err = protocols.registry[location.protocol].connect(location)
      assert(connection or err)
      if not connection then
        self:send_reply(err)
      else
        self:send_reply("Location [" .. location.name .. "] connected successfully")
        location.connection = connection
      end
    end

  commands['disconnect'] =
    function()
      location = locations.registry['freenode']
      if not location.connection then
        self:send_reply("Location is not connected")
      else
        self:disconnect_location('freenode')
      end
    end

  if commands[command] then
    return commands[command]()
  else
    msg = 'Unknown control command [' .. command .. ']'
    print(msg)
    self:send_reply(msg)
  end
end

local function remote_client_thread(peer)
  print("Remote " .. peer.get_description() .. " connected")

  local function send(msg) send_to_peer(peer, msg) end

  local user
  local realname
  local nick
  local host = peer.get_ip()
  local channels = {}
  local control

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

  local function deliver(sender, msg)
    if not control then return false end
    control:send_reply(sender .. ': ' .. msg)
    return true
  end

  hub.register_delivery(deliver)

  local function maybe_welcome()
    if not user or not nick then return end
    send(":permeshu 001 " .. nick .. " Welcome to the Internet Relay Network " .. nick .. "!" .. user .. "@" .. host)
    control = control_channel:new()
    control:join(peer, nick)
    channels[control.name] = control
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

  command_handlers['PRIVMSG'] = function(prefix, command, params)
                                  if not params[1] or not params[2] then unknown_command(prefix, command, params) return end
                                  if channels[params[1]] then
                                    return channels[params[1]]:privmsg(params[2])
                                  else
                                    print(("client sends '%s' to '%s'"):format(params[2], params[1]))
                                  end
                                end

  command_handlers['WHO'] =
    function(prefix, command, params)
      if not params[1] or not channels[params[1]] then unknown_command(prefix, command, params) return end
      channels[params[1]]:who()
    end

  command_handlers['MODE'] =
    function(prefix, command, params)
      if not params[1] or not channels[params[1]] then unknown_command(prefix, command, params) return end
      channels[params[1]]:mode()
    end

  -- command_handlers['JOIN'] = function(prefix, command, params)
  --                         end

  local err = receive(peer, command_handlers, function(msg) print(msg) end)
  print(("Remote %s disconnected (%s)"):format(peer.get_description(), tostring(err)))
end

function create_server()
  print('Creating IRC server')
  err = remotes.create_tcp_server(remote_client_thread, {{host='*', port=6667}})
  if err then return err end
end
