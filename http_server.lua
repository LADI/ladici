-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

local misc = require 'misc'
local remotes = require 'remotes'

local function process_raw_msg(request, raw_msg)
  --print('----receive----' .. tostring(raw_msg))

  local verb
  local path
  local proto
  local rest = raw_msg

  if not request.verb then
    -- verb path proto
    rest, verb, path, proto  = parse_and_consume(rest, "^([^ ]*) ([^ ]*) (.*)$")
    --if verb then print(("verb: '%s'"):format(verb)) end
    --if path then print(("path: '%s'"):format(path)) end
    --if proto then print(("proto: '%s'"):format(proto)) end
    --if rest then print(("rest: '%s'"):format(rest)) end
    request.verb = verb
    request.path = path
    request.proto = proto
    return false
  end

  -- header
  rest, key, value  = parse_and_consume(rest, "^([^:]*): (.*)$")
  --if key then print(("key: '%s'"):format(key)) end
  --if value then print(("value: '%s'"):format(value)) end
  request.headers[key] = value

  assert(not rest)

  return false
end

function create(router)
  print('Creating HTTP server')

  local function remote_client_thread(peer)
    print("Remote " .. peer.get_description() .. " connected")

    local function send_respone(response)
      local status_line
      if response.status == 200 then
        peer.send("HTTP/1.1 200 OK\r\n")
      else
        peer.send("HTTP/1.1 500 WIP\r\n")
      end
      for k, v in pairs(response.headers) do
        peer.send(("%s: %s\r\n"):format(k, v))
      end
      peer.send("\r\n")
      if response.body then
        peer.send(response.body)
      end
    end

    local function receive_request()
      local buffer
      local request = { headers = {} }
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
          --print('[' .. tostring(buffer) .. ']')
          --print('[' .. tostring(raw_msg) .. ']')
          if not raw_msg then break end
          if raw_msg == '' then
            --print("end of headers")
            --print(request.verb .. " " .. request.path .. " " .. request.proto)
            --misc.dump_table(request.headers)
            response = router(request)
            send_respone(response)
            return
          end
          if process_raw_msg(request, raw_msg) then return end
        end
      end
      assert(false)
    end

    local host = peer.get_ip()

    local err = receive_request()

    print(("Remote %s disconnected (%s)"):format(peer.get_description(), tostring(err)))
  end

  err = remotes.create_tcp_server(remote_client_thread, {{host='127.0.0.01', port=8010}})
  if err then return err end
end

return {
  create = create,
}
