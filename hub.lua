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

channel = {users={}}
function channel:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function channel:set_name(name)
  self.name = name
end

function channel:set_topic(topic)
  self.topic = topic
end

function channel:attach(interface)
  print(("attaching channel '%s'"):format(tostring(self.name)))
  interface.channel_join(self.name)
  interface.channel_set_topic(self.name, self.topic)
  --self:who()
end

function channel:get_users()
  users = {}
  for nick, user in pairs(self.users) do
    users[nick] = user
  end
  return users
end

function channel:mode()
--  send_to_peer(self.peer, "MODE " .. self.name .. ' +tn')
end

local control_channel = channel:new{name = '&control', topic = 'permeshu control channel'}
control_channel.users['@permeshu'] = {}

function control_channel:send_reply(msg)
  if not interface then print(msg) end
  interface.channel_send_msg(self.name, 'permeshu', msg)
end

-- function control_channel:disconnect_location(name)
--   location = locations.registry[name]
--   assert(location.connection)
--   location.connection.disconnect(function()
--                                    self:send_reply("Location [" .. name .. "] disconnected successfully")
--                                    location.connection = nil
--                                  end)
-- end

function control_channel:privmsg(command)
  commands = {}
  commands['quit'] =
    function()
      interface.disconnect()
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

function join(channel)
  channels[channel.name] = channel
end

function get_channel(channel)
  return channels[channel]
end

join(control_channel)

function deliver(sender, msg)
  control_channel:send_reply(sender .. ': ' .. msg)
end

function attach_interface(iface)
  print(("attaching interface: %s"):format(tostring(iface)))
  interface = iface

  for name, obj in pairs(channels) do
    obj:attach(interface)
  end
end

function detach_interface(iface)
  print(("detaching interface: %s"):format(tostring(iface)))
  assert(interface == iface)
  interface = nil
end
