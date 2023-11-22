-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2010-2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

local registry = {}

function register(name, protocol, args)
  registry[name] = {name=name, protocol=protocol, args=args}
end

return {
  register = register,
}
