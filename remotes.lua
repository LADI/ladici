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
local socket = require('socket')
local misc = require('misc')
module('remotes')

-- misc.dump_table(socket)
-- base.assert(false)

local sockets = {}
local peers = {}
local listeners = {}

function dump_peers()
  misc.dump_table(sockets)
  base.print('-- peers:')
  for sock, peer in base.pairs(peers) do
    base.print(("%s (%s) - %s"):format(peer:get_desciption(), base.tostring(peer.receiver), base.tostring(sock)))
  end
  base.print('--')
end
function dump_peers() end

function io()
  if #sockets == 0 then base.print("no sockets to IO on") return false end
  local ready, _, err = socket.select(sockets)
  if err then print(err); return false; end

  for no, sock in base.ipairs(ready) do
    local peer = peers[sock]
    local listener = listeners[sock]
    if peer then
      --base.print(("peer %s said something"):format(base.tostring(sock)))
      local ret, err = peer.receiver()
      if not ret then
        base.print(('socket error "%s" from "%s"'):format(err, peers[sock]:get_desciption()))
        for i, v in base.ipairs(sockets) do if v == sock then base.table.remove(sockets, i) break end end
        peers[sock] = nil
      end
    elseif listener then
      local client = sock:accept()
      local ip, port = client:getpeername()
      base.print(("Remote %s:%s connected"):format(ip, port))
      local peer = {
        ip = ip,
        port = port,
        get_desciption = function(peer) return ("%s:%s (client)"):format(peer.ip, peer.port) end,
        receiver = function()
                     local data, err = client:receive()
                     if not data then return nil, err end
                     base.print(('client sent: [%s]'):format(data))
                     return true
                   end
      }
      base.table.insert(sockets, client)
      peers[client] = peer
      dump_peers()
    end
  end
  return true
end

function create_tcp(host, port, receiver)
  base.assert(base.type(receiver) == 'function', "Non function receiver! " .. base.tostring(receiver))
  local sock, err = socket.connect(host, port)
  if not sock then return nil, err end
  base.table.insert(sockets, sock)
  local local_ip = sock:getsockname()
  ip, port2 = sock:getpeername()
  base.assert(port == port2)
  local peer = {
    receiver = receiver,
    host = host,
    ip = ip,
    port = port,
    get_desciption = function(peer) return ("%s[%s]:%s (server)"):format(peer.host, peer.ip, peer.port) end
  }
  peers[sock] = peer
  dump_peers()
  return {
    local_ip = local_ip,
    get_desciption = function() return peer:get_desciption() end,
    send = function(data, i, j) return sock:send(data, i, j) end,
    receive = function(pattern, prefix) return sock:receive(pattern, prefix) end,
  }
end

function create_tcp_server(binds, backlog)
  local sock, res, err

  sock, err = socket.tcp()
  if not sock then return nil, err end

  for _, bind in base.pairs(binds) do
    res, err = sock:bind(bind.host, bind.port)
    if not res then return nil, err end
    base.print(("Listening on %s:%s"):format(bind.host, bind.port))
  end

  res, err = sock:listen(backlog)
  if not res then return nil, err end

  sock:settimeout(0)
  base.table.insert(sockets, sock)
  listeners[sock] = true
  return sock
end
