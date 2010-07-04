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

module(..., package.seeall)

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
