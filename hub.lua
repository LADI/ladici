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

require 'misc'

module(..., package.seeall)

local interface = nil

channel_cls = {}
function channel_cls:new(o)
  o = o or {}
  if not o.users then o.users = {} end
  setmetatable(o, self)
  self.__index = self
  return o
end

function channel_cls:set_name(name)
  self.name = name
end

function channel_cls:set_topic(topic)
  self.topic = topic
end

function channel_cls:attach()
  if not interface then return end
  print(("attaching channel '%s'"):format(tostring(self.name)))
  interface.channel_join(self.name)
  interface.channel_set_topic(self.name, self.topic)
end

function channel_cls:get_users()
  users = {}
  for nick, user in pairs(self.users) do
    users[nick] = user
  end
  return users
end

function channel_cls:mode()
--  send_to_peer(self.peer, "MODE " .. self.name .. ' +tn')
end

function channel_cls:outgoing_message(msg, receiver)
  print(('outgoing message for %s: "%s"'):format(receiver, msg))
end

local control_channel = channel_cls:new{name = '&control', topic = 'permeshu control channel', users = {['@permeshu'] = {}}}

function control_channel:send_reply(msg, sender)
  interface.send_msg(msg, sender or 'permeshu', self.name)
end

function control_channel:disconnect_location(name)
  location = locations.registry[name]
  assert(location.connection)
  location.connection.disconnect(function()
                                   self:send_reply("Location [" .. name .. "] disconnected successfully")
                                   location.connection = nil
                                 end)
end

function control_channel:outgoing_message(command)
  commands = {}
  commands['quit'] =
    function()
      interface.disconnect()

      for name,location in pairs(locations.registry) do
        if location.connection then self:disconnect_location(name) end
      end

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

local channels = {}

local function register_channel(channel)
  channels[channel.name] = channel
end

function get_channel(channel)
  return channels[channel]
end

register_channel(control_channel)

function incoming_message(msg, location, sender, channel)
  if not interface then
    if location then
      if not sender then
        msg = location.name .. ": " .. msg
      elseif not channel then
        msg = ('%s said "%s"'):format(sender, msg)
      else
        msg = ('%s said in #%s "%s"'):format(sender, channel, msg)
      end
    end
    print(msg)
    return
  end

  -- print(location)
  if not sender then
    control_channel:send_reply(location.name .. ": " .. msg, 'permeshu')
  elseif not channel then
    -- private message
    interface.send_msg(msg, location.name .. '/' .. sender)
  else
    -- channel message
    interface.send_msg(msg, sender, '#' .. location.name .. '/' .. channel)
  end
end

function outgoing_message(msg, receiver)
  channel = get_channel(receiver)
  if channel then return channel:outgoing_message(msg, receiver) end
end

function join(location, channel_name, nick)
  channel_name = '#' .. location.name .. '/' .. channel_name
  channel = get_channel(channel_name)
  if not channel then
    channel = channel_cls:new{name = channel_name}
    register_channel(channel)
    channel:attach()
  end

  if not channel.users[nick] then
    channel.users[nick] = {}
  end
end

function attach_interface(iface)
  print(("attaching interface: %s"):format(tostring(iface)))
  interface = iface

  for name, obj in pairs(channels) do
    obj:attach()
  end
end

function detach_interface(iface)
  print(("detaching interface: %s"):format(tostring(iface)))
  assert(interface == iface)
  interface = nil
end
