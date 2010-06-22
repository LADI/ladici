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
module('misc')

function dump_table(t)
  base.print('--')
  -- base.print(#t)
  -- base.print('--')
  for i,v in base.pairs(t) do
    base.print(("%30s - %s"):format(base.tostring(i), base.tostring(v)))
  end
  base.print('--')
end

function trim(s) return s:gsub("^%s*(.-)%s*$", "%1") end
