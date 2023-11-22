-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

module('misc', package.seeall)

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
