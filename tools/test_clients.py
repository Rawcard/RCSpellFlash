#!/usr/bin/env python3
"""Load RC-SpellFlash on every WoW client and class (TOC -> Lua files) and play
a short session: login, action bars full of spells, a fake NAG recommending
spells (the bridge reads NAG's display data), a fight (secret values on Retail
and WoW Forever), the options window and every slash command.

  pip install lupa
  python3 tools/test_clients.py            all clients
  python3 tools/test_clients.py retail     one client

Fails on any Lua error, or when NAG's recommended spell isn't flashed.
"""
import os
import sys

import lupa.luajit21 as lupa_mod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSIC9 = [("WARRIOR", 1), ("PALADIN", 2), ("HUNTER", 3), ("ROGUE", 4), ("PRIEST", 5), ("SHAMAN", 7), ("MAGE", 8), ("WARLOCK", 9), ("DRUID", 11)]
CLIENTS = {
    "era": ("RC-SpellFlash_Vanilla.toc", 11508, CLASSIC9),
    "tbc": ("RC-SpellFlash_TBC.toc", 20505, CLASSIC9),
    "wrath": ("RC-SpellFlash_Wrath.toc", 30405, CLASSIC9 + [("DEATHKNIGHT", 6)]),
    "cata": ("RC-SpellFlash_Cata.toc", 40402, CLASSIC9 + [("DEATHKNIGHT", 6)]),
    "mists": ("RC-SpellFlash.toc", 50504, CLASSIC9 + [("DEATHKNIGHT", 6), ("MONK", 10)]),
    "retail": ("RC-SpellFlash_Mainline.toc", 120005, CLASSIC9 + [("DEATHKNIGHT", 6), ("MONK", 10), ("DEMONHUNTER", 12), ("EVOKER", 13)]),
    "forever": ("RC-SpellFlash_Camelot.toc", 16001, CLASSIC9),
}

RUN = r"""
local ADDON = "RC-SpellFlash"
NS = {}
local function loadFile(file)
	local f = assert(io.open(ADDON_DIR .. "/" .. file, "rb"), "missing " .. file)
	local src = f:read("*a"); f:close()
	src = src:gsub("^\239\187\191", "")
	local fn, err = loadstring(src, "@" .. file)
	if not fn then error("LOAD " .. file .. ": " .. tostring(err)) end
	local ok, e = pcall(fn, ADDON, NS)
	if not ok then error("LOAD " .. file .. ": " .. tostring(e)) end
end
local function fire(ev, ...)
	for _, f in ipairs(ALLFRAMES) do
		local fn = f.scripts.OnEvent
		if fn and (not f.events or f.events[ev]) then
			local ok, err = pcall(fn, f, ev, ...)
			if not ok then error("EVENT " .. ev .. ": " .. tostring(err)) end
		end
	end
end
local function update(dt)
	local due = TIMERS
	TIMERS = {}
	for _, fn in ipairs(due) do
		local ok, err = pcall(fn)
		if not ok then error("timer: " .. tostring(err)) end
	end
	for i = 1, #ALLFRAMES do
		local f = ALLFRAMES[i]
		local fn = f.scripts.OnUpdate
		if fn then
			local ok, err = pcall(fn, f, dt)
			if not ok then error("OnUpdate: " .. tostring(err)) end
		end
	end
end
local function step(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then error(label .. ": " .. tostring(err)) end
end

-- action bars: Blizzard's buttons, slots 1-12 hold spells 101..112
ACTION = {}
for i = 1, 12 do ACTION[i] = 100 + i end
function HasAction(slot) return ACTION[slot] ~= nil end
function GetActionInfo(slot) if ACTION[slot] then return "spell", ACTION[slot] end end
function GetActionTexture(slot) return ACTION[slot] and 134400 or nil end
for i = 1, 12 do
	local b = CreateFrame("CheckButton", "ActionButton" .. i, UIParent, "ActionBarButtonTemplate")
	b.action = i; b.shown = true
	local icon = CreateFrame("Frame", nil, b); b.icon = icon; b.Icon = icon
end

-- a fake NAG showing its recommendations
NAG = {
	nextSpell = 103,
	GetModule = function() return nil end,
	GetDisplayGroupIconData = function() return { MAIN = { { spellId = NAG.nextSpell } }, COOLDOWNS = { { spellId = 105 } } } end,
}

for line in io.lines(ADDON_DIR .. "/" .. TOC_FILE) do
	line = line:gsub("\r", ""):gsub("^\239\187\191", ""):gsub("\\", "/")
	if line ~= "" and not line:match("^#") and line:match("%.lua$") then loadFile(line) end
end
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
fire("ACTIONBAR_SLOT_CHANGED", 0)
for i = 1, 20 do NOW = NOW + 0.05; update(0.05) end

COMBAT = true
fire("PLAYER_REGEN_DISABLED")
for i = 1, 40 do
	NOW = NOW + 0.05
	if i == 20 then NAG.nextSpell = 107 end
	update(0.05)
end
-- NAG's main spell is flashed on its button
local function flashed(slot)
	local f = rawget(_G["ActionButton" .. slot], "RCSpellFlashFrame")
	return f ~= nil and f.shown == true
end
FLASHED = flashed(7) and not flashed(1)
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
fire("UPDATE_SHAPESHIFT_FORM")
for i = 1, 5 do NOW = NOW + 0.05; update(0.05) end

-- every control (options window, menu) and slash command
CONTROL_ERRORS = {}
local snapshot = {}
for i = 1, #ALLFRAMES do snapshot[i] = ALLFRAMES[i] end
for _, f in ipairs(snapshot) do
	for _, ev in ipairs({ "OnShow", "OnEnter", "OnLeave", "OnClick", "OnClick", "OnValueChanged", "OnHide" }) do
		local fn = f.scripts[ev]
		if fn then
			local args = (ev == "OnClick") and { "LeftButton", false } or (ev == "OnValueChanged" and { 0.5, true } or {})
			if f.kind == "CheckButton" and ev == "OnClick" then f.checked = not f.checked end
			local ok, err = pcall(fn, f, unpack(args))
			if not ok and not tostring(err):find("RELOAD", 1, true) then
				CONTROL_ERRORS[#CONTROL_ERRORS + 1] = tostring(f.__gname or f.kind) .. ":" .. ev .. " " .. tostring(err)
			end
		end
	end
end
if #CONTROL_ERRORS > 0 then
	local seen, uniq = {}, {}
	for _, e in ipairs(CONTROL_ERRORS) do local k = e:gsub("^[^ ]+ ", "") if not seen[k] then seen[k] = true; uniq[#uniq + 1] = e end end
	error("controls: " .. table.concat(uniq, " || "))
end
local cmds = {}
for k in pairs(SlashCmdList) do cmds[#cmds + 1] = k end
table.sort(cmds)
for _, k in ipairs(cmds) do
	for _, arg in ipairs({ "", "help", "test", "scan", "toggle", "toggle", "combat", "combat", "debug", "debug", "reset", "nag", "config", "menu" }) do
		step("slash " .. k .. " " .. arg, SlashCmdList[k], arg)
		update(0.05)
	end
end
if #BLOCKED > 0 then error("blocked in combat: " .. table.concat(BLOCKED, " || ")) end
"""


def run(flavor, cls, cid):
    toc, build, _ = CLIENTS[flavor]
    L = lupa_mod.LuaRuntime(unpack_returned_tuples=True)
    g = L.globals()
    g.ADDON_DIR = ROOT
    g.TOC_FILE = toc
    g.BUILD_TOC = build
    g.FLAVOR = flavor
    g.CLASS_FILE = cls
    g.CLASS_ID = cid
    L.execute(open(os.path.join(ROOT, "tools", "wow_env.lua"), encoding="utf-8").read())
    g.ReloadUI = L.eval('function() error("RELOAD") end')
    L.execute(RUN)
    return bool(g.FLASHED)


def main():
    flavors = sys.argv[1:] or list(CLIENTS)
    failed = 0
    for flavor in flavors:
        toc = CLIENTS[flavor][0]
        if not os.path.exists(os.path.join(ROOT, toc)):
            failed += 1
            print("FAIL %-7s no %s" % (flavor, toc))
            continue
        bad, noflash = [], []
        for cls, cid in CLIENTS[flavor][2]:
            try:
                if not run(flavor, cls, cid):
                    noflash.append(cls)
            except Exception as e:  # noqa: BLE001
                bad.append((cls, str(e).split("\nstack traceback")[0][:600]))
        if bad or noflash:
            failed += 1
            print("FAIL %-7s" % flavor)
            seen = set()
            for cls, err in bad:
                if err not in seen:
                    seen.add(err)
                    print("       %-11s %s" % (cls, err))
            if noflash:
                print("       NAG's spell not flashed for: " + ", ".join(noflash))
        else:
            print("OK   %-7s all %d classes" % (flavor, len(CLIENTS[flavor][2])))
    print("ALL PASS" if not failed else "%d FAILED" % failed)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
