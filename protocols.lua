-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

registry = {}

local function dump_params(name, t)
  print('\t'..name)
  for i, v in pairs(t) do
    print(("\t\t%s\t- %s"):format(tostring(i), tostring(v)))
  end
end

local function dump()
  for _,t in pairs(registry) do
    print('----')
    print(t.name)
    for i, v in pairs(t) do
      if i == 'required_params' then
        dump_params("Required params", v)
      elseif i == 'optional_params' then
        dump_params("Optional params", v)
      else
        --print(("%30s - %s"):format(tostring(i), tostring(v)))
      end
    end
  end
  print('----')
end

function register(descriptor)
  registry[descriptor.name] = descriptor
  -- dump()
end

return {
  register = register,
}
