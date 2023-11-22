-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

--module('misc', package.seeall)

function dump_table(t)
  print('--')
  -- print(#t)
  -- print('--')
  for i,v in pairs(t) do
    print(("%30s - %s"):format(tostring(i), tostring(v)))
  end
  print('--')
end

function trim(s) return s:gsub("^%s*(.-)%s*$", "%1") end

function parse_and_consume(buffer, regexp)
  local b = 0
  local e = 0
  b, e, a1, a2, a3, a4 = buffer:find(regexp)
  if not b then return buffer end
  rest = buffer:sub(e + 1)
  if rest == '' then rest = nil end
  return rest, a1, a2, a3, a4
end

return {
  dump_table = dump_table,
  trim = trim,
  parse_and_consume = parse_and_consume,
}
