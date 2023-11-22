-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

require 'socket'
-- require 'misc'

module('remotes', package.seeall)

local threads = {}

function add_thread(fun)
  local thread = coroutine.create(fun)
  table.insert(threads, thread)
  -- print("new " .. tostring(thread))
  -- misc.dump_table(threads)
end

local function receive(sock, block_size)
  local block, status
  while true do
    local partial
    sock:settimeout(0)            -- do not block
    block, status, partial = sock:receive(block_size)
    -- print('block   [' .. tostring(block) .. ']')
    -- print('status  [' .. tostring(status) .. ']')
    -- print('partial [' .. tostring(partial) .. ']')
    if block and string.len(block) == 0 then block = nil end
    block = block or partial
    if block and string.len(block) == 0 then block = nil end
    if block then break end
    if status == 'timeout' then
      -- if data is not available, tell the dispatcher so it can eventually wait on this socket
      coroutine.yield(sock)
    else
      break
    end
  end
  return block, status
end

local function accept_thread_factory(sock, client_thread)
  local accept_enabled = true
  return
  function()
    while accept_enabled do
      sock:settimeout(0)          -- do not block
      local client, err = sock:accept()
      if client then
        add_thread(function()
                     local ip = client:getpeername()
                     local description = ("%s:%s"):format(client:getpeername())
                     local peer = {
                       send = function(data) client:send(data) end,
                       receive = function(block_size) return receive(client, block_size) end,
                       get_description = function() return description end,
                       get_ip = function() return ip end,
                       accept_disable = function() accept_enabled = false end
                     }
                     client_thread(peer)
                     -- print('closing client socket')
                     client:close()
                   end)
      elseif err == 'timeout' then
        -- if data is not available, tell the dispatcher so it can eventually wait on this socket
        coroutine.yield(sock)
      else
        error("accept failed: " .. err) -- terminate the thread coroutine
      end
    end
  end
end

function dispatch()
  local i
  local sockets = {}            -- list of sockets that to wait on
  while true do
    if threads[i] == nil then   -- no more threads?
      if threads[1] == nil then print("no more threads to dispatch") break end
      i = 1                     -- restart the loop
      sockets = {}
    end

    -- print('resuming ' .. tostring(threads[i]))
    local status, sock = coroutine.resume(threads[i])
    if not sock then            -- thread finished its task?
      -- print(('finished %s'):format(tostring(threads[i])))
      table.remove(threads, i)
      -- misc.dump_table(threads)
    else
      i = i + 1
      assert(type(sock) == 'userdata', tostring(sock))
      table.insert(sockets, sock)
      if #sockets == #threads then -- all threads blocked?
        -- print("all threads blocked")
        -- misc.dump_table(sockets)
        socket.select(sockets)
        -- print("select done")
      end
    end
  end
end

function connect_tcp(host, port)
  local sock, err = socket.connect(host, port)
  if not sock then return nil, err end

  local local_ip = sock:getsockname()
  local ip, port2 = sock:getpeername()
  assert(port == port2)

  return {
    get_description = function() return ("%s[%s]:%s"):format(host, ip, port) end,
    get_local_ip = function() return local_ip end,
    send = function(data) sock:send(data) end,
    receive = function(block_size) return receive(sock, block_size) end,
    close = function() sock:close() end,
  }
end

function create_tcp_server(client_thread, binds, backlog)
  assert(client_thread)
  local sock, res, err

  sock, err = socket.tcp()
  if not sock then return err end

  res, err = sock:setoption('linger', {on=true, timeout=0})
  if not res then return err end

  for _, bind in pairs(binds) do
    res, err = sock:bind(bind.host, bind.port)
    if not res then return err end
    print(("Listening on %s:%s"):format(bind.host, bind.port))
  end

  res, err = sock:listen(backlog)
  if not res then return err end

  sock:settimeout(0)
  add_thread(accept_thread_factory(sock, client_thread))
end
