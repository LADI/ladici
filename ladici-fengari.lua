-- -*- Mode: Lua; indent-tabs-mode: nil; lua-indent-level: 2 -*-
-- LADI Continuous Integration (ladici)
-- SPDX-FileCopyrightText: Copyright © 2023 Nedko Arnaudov */
-- SPDX-License-Identifier: GPL-2.0-or-later

print("LADICI lua in web browser!")
--print(package.path)
package.path = './?.lua'
--print(package.path)
local js = require "js"
--print("js: " .. repr(js))
local window = js.global
--window.title = "LADICI lua in web browser!"
--print("window: " .. repr(window))
local document = window.document
--print("document: " .. repr(document))
local text = document:createTextNode("LADICI lua in web browser!")
document.body:appendChild(text)
document.body:appendChild(document:createElement("br"))
local buildno = require "buildno01"
local text = document:createTextNode(buildno.description)
document.body:appendChild(text)
print("LADICI done")
