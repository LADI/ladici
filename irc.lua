-- -*- Mode: Lua -*-
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

   local function receiver()
      local buffer, err = peer.receive()
      if not buffer then return buffer, err end
      base.print('----receive----' .. base.tostring(buffer))

      local prefix
      local command
      local argstr

      -- prefix
      buffer, prefix = parse_and_consume(buffer, "^:([^ ]*) *")
      --if prefix then print(("prefix: '%s'"):format(prefix)) end
      --if buffer then print(("rest: '%s'"):format(buffer)) end

      -- command and  params
      buffer, command, params = parse_and_consume(buffer, "^([^ ]*) *(.*)")
      --if command then print(("command: '%s'"):format(command)) end
      --if params then print(("params: '%s'"):format(params)) end
      base.assert(not buffer)

      return true
   end

   local function send(msg)
      base.print('-----send------' .. msg)
      peer.send(msg .. "\r\n")
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
