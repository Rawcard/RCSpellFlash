-- WoW client simulation for tools/test_clients.py.
-- Widgets are permissive stubs (any unknown widget method is a no-op). Game
-- APIs follow the flavor being tested (FLAVOR): APIs a client doesn't have are
-- missing, and on Retail and WoW Forever combat values are secret.
-- Globals set by the runner: FLAVOR, BUILD_TOC, CLASS_FILE, CLASS_ID
local unpack = unpack or table.unpack

local function perm(name)
	local o = { __name = name, shown = false, scripts = {}, hooks = {}, level = 1, w = 36, h = 36, scale = 1, pts = {} }
	local function fire(s, e, ...)
		if s.scripts[e] then s.scripts[e](s, ...) end
		for _, fn in ipairs(s.hooks[e] or {}) do fn(s, ...) end
	end
	local known = {
		Show = function(s) local was = s.shown; s.shown = true; if not was then fire(s, "OnShow") end end,
		Hide = function(s) local was = s.shown; s.shown = false; if was then fire(s, "OnHide") end end,
		SetScale = function(s, v) s.scale = v end,
		ClearAllPoints = function(s) s.pts = {} end,
		SetPoint = function(s, ...) s.pts[#s.pts + 1] = { ... } end,
		IsShown = function(s) return s.shown end,
		IsVisible = function(s) return s.shown end,
		SetShown = function(s, v) s.shown = v and true or false end,
		GetWidth = function(s) return s.w end,
		GetHeight = function(s) return s.h end,
		GetSize = function(s) return s.w, s.h end,
		SetWidth = function(s, v) s.w = v end,
		SetHeight = function(s, v) s.h = v end,
		SetSize = function(s, w, h) s.w, s.h = w, h end,
		GetFrameLevel = function(s) return s.level end,
		SetFrameLevel = function(s, v) s.level = v end,
		GetScale = function(s) return s.scale end,
		GetEffectiveScale = function() return 1 end,
		GetName = function(s) return s.__gname end,
		GetParent = function() return UIParent end,
		GetScript = function(s, e) return s.scripts[e] end,
		SetScript = function(s, e, f) s.scripts[e] = f end,
		HookScript = function(s, e, fn) s.hooks[e] = s.hooks[e] or {}; table.insert(s.hooks[e], fn) end,
		GetText = function(s) return s.text or "" end,
		SetText = function(s, t) s.text = t end,
		GetStringWidth = function() return 50 end,
		GetStringHeight = function() return 12 end,
		GetNumPoints = function() return 0 end,
		GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end,
		GetCenter = function() return 500, 400 end,
		GetLeft = function() return 100 end,
		GetTop = function() return 500 end,
		GetRight = function() return 300 end,
		GetBottom = function() return 100 end,
		GetAttribute = function() return nil end,
		GetChildren = function() return end,
		GetRegions = function() return end,
		IsMouseOver = function() return false end,
		GetChecked = function(s) return s.checked end,
		SetChecked = function(s, v) s.checked = v end,
		GetValue = function(s) return s.value or 0 end,
		SetValue = function(s, v) s.value = v end,
		GetMinMaxValues = function() return 0, 100 end,
		GetTexture = function(s) return s.tex end,
		SetTexture = function(s, t) s.tex = t end,
		GetVerticalScroll = function() return 0 end,
		GetVerticalScrollRange = function() return 0 end,
		GetObjectType = function() return "Frame" end,
		IsObjectType = function() return true end,
		GetAlpha = function() return 1 end,
		GetNumLines = function() return 0 end,
		GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
		CreateAnimationGroup = function() return perm("anim") end,
		GetFrameStrata = function() return "MEDIUM" end,
		GetFontString = function(s) s._fs = s._fs or perm("FontString"); return s._fs end,
		GetNormalTexture = function(s) s._nt = s._nt or perm("Texture"); return s._nt end,
		GetHighlightTexture = function(s) s._ht = s._ht or perm("Texture"); return s._ht end,
		GetPushedTexture = function(s) s._pt = s._pt or perm("Texture"); return s._pt end,
		GetCheckedTexture = function(s) s._ct = s._ct or perm("Texture"); return s._ct end,
		GetStatusBarTexture = function(s) s._sb = s._sb or perm("Texture"); return s._sb end,
		GetThumbTexture = function(s) s._tt = s._tt or perm("Texture"); return s._tt end,
	}
	setmetatable(o, { __index = function(t, k)
		if known[k] then return known[k] end
		if type(k) == "string" and (k:match("^Create") ) then
			return function(_, name)
				local o2 = perm(k)
				if type(name) == "string" then o2.__gname = name; rawset(_G, name, o2) end
				return o2
			end
		end
		if type(k) ~= "string" or not k:match("^%u") then
			return nil -- plain fields are nil on real frames
		end
		-- only method-looking names are widget methods; other capitalized keys
		-- (ManaBar, HealthBar...) are child frames that may not exist
		local verb = k:match("^(%u%l+)")
		local VERBS = { Set = 1, Get = 1, Is = 1, Has = 1, Enable = 1, Disable = 1, Register = 1, Unregister = 1, Show = 1, Hide = 1,
			Clear = 1, Start = 1, Stop = 1, Play = 1, Add = 1, Remove = 1, Can = 1, Lock = 1, Unlock = 1, Raise = 1, Lower = 1,
			Hook = 1, Click = 1, Update = 1, Flash = 1, Fade = 1, Reset = 1, Refresh = 1, Toggle = 1, Adjust = 1, Scroll = 1,
			Insert = 1, Page = 1, Release = 1, Resume = 1, Pause = 1, Finish = 1, Execute = 1, Apply = 1, Stretch = 1, Rotate = 1 }
		if not verb or not VERBS[verb] then
			return nil
		end
		return function() return nil end
	end })
	return o
end

ALLFRAMES = {}
BLOCKED = {}
function CreateFrame(kind, gname, parent, template)
	local f = perm(kind)
	f.parent = parent
	f.kind = kind
	f.RegisterEvent = function(self, ev)
		if type(ev) ~= "string" then error("RegisterEvent: bad event") end
		if SECRET_CLIENT and (ev == "COMBAT_LOG_EVENT_UNFILTERED" or ev == "COMBAT_LOG_EVENT") then
			error(FLAVOR .. ": registering " .. ev .. " is not allowed")
		end
		self.events = self.events or {}
		self.events[ev] = true
	end
	f.RegisterUnitEvent = f.RegisterEvent
	f.UnregisterEvent = function(self, ev) if self.events then self.events[ev] = nil end end
	f.UnregisterAllEvents = function(self) self.events = {} end
	f.IsEventRegistered = function(self, ev) return self.events and self.events[ev] or false end
	f.GetParent = function(self) return self.parent or UIParent end
	-- secure frames can't be shown, hidden, moved or reconfigured by addons in
	-- combat (the game blocks it and reports ADDON_ACTION_BLOCKED)
	if type(template) == "string" and template:find("Secure") then
		f.secure = true
		for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetAttribute",
			"SetParent", "SetScale", "EnableMouse", "RegisterForClicks", "SetAllPoints" }) do
			local orig = f[m]
			f[m] = function(self, ...)
				if COMBAT then
					BLOCKED[#BLOCKED + 1] = tostring(gname or kind) .. ":" .. m .. " " .. (debug and debug.traceback and debug.traceback("", 2):match("\n%s*([^\n]*RC%-SpellFlash[^\n]*)") or "?")
					return
				end
				return orig(self, ...)
			end
		end
	end
	ALLFRAMES[#ALLFRAMES + 1] = f
	if gname then f.__gname = gname; _G[gname] = f end
	-- the named children Blizzard templates create ($parentText, $parentLow...)
	if gname and template and template ~= "" then
		for _, c in ipairs({ "Text", "Low", "High", "Button", "Left", "Middle", "Right", "Icon", "TextLeft1", "TextRight1" }) do
			if rawget(_G, gname .. c) == nil then
				local child = perm("child"); child.__gname = gname .. c
				_G[gname .. c] = child
			end
		end
		f.Text = _G[gname .. "Text"]
	end
	if not gname and template and template ~= "" then
		if kind == "CheckButton" then f.Text = perm("FontString") end
		if kind == "Slider" then f.Low, f.High, f.Text = perm("FontString"), perm("FontString"), perm("FontString") end
	end
	return f
end

-- ====================================================================== base
UIParent = perm("UIParent"); UIParent.w, UIParent.h = 1365, 768; UIParent.shown = true
WorldFrame = perm("WorldFrame")
Minimap = perm("Minimap"); Minimap.shown = true
GameTooltip = perm("GameTooltip")
GameTooltipStatusBar = perm("GameTooltipStatusBar")
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormalSmall", "GameFontNormalLarge",
	"NumberFontNormalHuge", "BossEmoteNormalHuge", "SystemFont_Shadow_Large", "GameFontDisable", "GameFontWhite" }) do
	_G[n] = perm(n)
end
DEFAULT_CHAT_FRAME = perm("chat")
PlayerFrame, TargetFrame, FocusFrame, PetFrame, ComboFrame, CastingBarFrame, PlayerCastingBarFrame, MainMenuBar, MainMenuBarArtFrame =
	perm("PlayerFrame"), perm("TargetFrame"), perm("FocusFrame"), perm("PetFrame"), perm("ComboFrame"), perm("CastingBarFrame"),
	perm("PlayerCastingBarFrame"), perm("MainMenuBar"), perm("MainMenuBarArtFrame")
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show() end
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
PRINTED = {}
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end PRINTED[#PRINTED + 1] = table.concat(t, " ") end
function GetLocale() return "enUS" end
NOW = 100
function GetTime() return NOW end
function GetServerTime() return 1000 end
function time() return 1000 end
function date() return "2026-10-25" end
function debugprofilestop() return 0 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
string.trim = strtrim
function strsplit(sep, s, n) local t = {} for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t + 1] = part end return unpack(t) end
string.split = function(s, sep) return strsplit(sep, s) end
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strlower, strupper, strsub, strfind, strmatch, strlen, strrep, format, tinsert, tremove, floor, ceil, abs, min, max, gsub, mod =
	string.lower, string.upper, string.sub, string.find, string.match, string.len, string.rep, string.format, table.insert, table.remove,
	math.floor, math.ceil, math.abs, math.min, math.max, string.gsub, math.fmod
-- WoW's global math helpers (trig in degrees)
sqrt, random, exp, log, deg, rad, atan, atan2 = math.sqrt, math.random, math.exp, math.log, math.deg, math.rad, math.atan, math.atan2
function cos(d) return math.cos(math.rad(d)) end
function sin(d) return math.sin(math.rad(d)) end
function tan(d) return math.tan(math.rad(d)) end
function tContains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function CopyTable(t) local o = {} for k, v in pairs(t) do o[k] = type(v) == "table" and CopyTable(v) or v end return o end
function hooksecurefunc(t, m, fn)
	if type(t) == "string" then t, m, fn = _G, t, m end
	local orig = t[m]
	if type(orig) == "function" then
		t[m] = function(...) local a, b, c, d = orig(...); fn(...); return a, b, c, d end
	end
end
function securecall(fn, ...) if type(fn) == "string" then fn = _G[fn] end return fn(...) end
function GetBuildInfo() return "x", "1", "Oct 1 2026", BUILD_TOC end
COMBAT = false
TARGET = false
PET = false
function InCombatLockdown() return COMBAT end
function GetCursorPosition() return 0, 0 end
function PlaySound() end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function ReloadUI() end
function GetRealmName() return "Realm" end
function GetRealZoneText() return "Elwynn Forest" end
function GetZoneText() return "Elwynn Forest" end
function IsInInstance() return false, "none" end
function GetInstanceInfo() return "Elwynn", "none", 0, "", 5 end
function IsInRaid() return false end
function IsInGroup() return false end
function GetNumGroupMembers() return 0 end
function GetNumSubgroupMembers() return 0 end
function IsMounted() return false end
function GetShapeshiftForm() return 0 end
function GetGuildInfo() return nil end
function GetAverageItemLevel() return 100, 100 end
function RegisterUnitWatch() end
function UnregisterUnitWatch() end
function SecureUnitButton_OnLoad() end
TIMERS = {}
C_Timer = {
	After = function(_, fn) TIMERS[#TIMERS + 1] = fn end,
	NewTicker = function(_, fn) TIMERS[#TIMERS + 1] = fn; return { Cancel = function() end, IsCancelled = function() return false end } end,
	NewTimer = function(_, fn) TIMERS[#TIMERS + 1] = fn; return { Cancel = function() end } end,
}
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() end }
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return nil end, LoadAddOn = function() end }
-- the old dropdown library (Classic and, as a compatibility layer, Retail)
UIDROPDOWNMENU_MENU_LEVEL = 1
function UIDropDownMenu_Initialize(frame, fn) frame.initfn = fn end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetButtonWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_JustifyText() end
function UIDropDownMenu_SetSelectedID(frame, id) frame.selectedID = id end
function UIDropDownMenu_GetSelectedID(frame) return frame.selectedID end
function UIDropDownMenu_CreateFrames() end
function ToggleDropDownMenu() end
function CloseDropDownMenus() end
function GameTooltip_SetDefaultAnchor() end

DebuffTypeColor = { none = { r = 0.8, g = 0, b = 0 }, Magic = { r = 0.2, g = 0.6, b = 1 }, Curse = { r = 0.6, g = 0, b = 1 },
	Disease = { r = 0.6, g = 0.4, b = 0 }, Poison = { r = 0, g = 0.6, b = 0 }, [""] = { r = 0.8, g = 0, b = 0 } }
PowerBarColor = setmetatable({}, { __index = function() return { r = 0, g = 0, b = 1 } end })
CLASS_ICON_TCOORDS = setmetatable({}, { __index = function() return { 0, 1, 0, 1 } end })
MAX_PARTY_MEMBERS = 4
Enum = {
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6, SoulShards = 7, LunarPower = 8,
		HolyPower = 9, Maelstrom = 11, Chi = 12, Insanity = 13, BurningEmbers = 14, DemonicFury = 15, ArcaneCharges = 16, Fury = 17, Pain = 18, Essence = 19 },
}
-- ================================================================ secrets
local rawtype = type
local SECRET = {}
SECRET.__index = function() error(FLAVOR .. ": indexed a secret value", 2) end
SECRET.__newindex = function() error(FLAVOR .. ": assigned into a secret value", 2) end
SECRET.__call = function() error(FLAVOR .. ": called a secret value", 2) end
SECRET.__concat = function() return NEWSECRET("") end
SECRET.__tostring = function() return "<secret>" end
SECRET.__metatable = "secret"
local SECRET_TYPE = setmetatable({}, { __mode = "k" })
local function secret(v)
	local o = setmetatable({}, SECRET)
	SECRET_TYPE[o] = rawtype(v)
	return o
end
NEWSECRET = secret
local function isSecret(v) return rawtype(v) == "table" and getmetatable(v) == "secret" end
-- type() of a secret gives its real type, as in the game
function type(v) if isSecret(v) then return SECRET_TYPE[v] end return rawtype(v) end
local rawformat = string.format
string.format = function(fmt, ...)
	for i = 1, select("#", ...) do
		if isSecret((select(i, ...))) then return secret("") end
	end
	return rawformat(fmt, ...)
end
format = string.format
local rawtonumber = tonumber
function tonumber(v, ...) if isSecret(v) then return v end return rawtonumber(v, ...) end
local function S(v) if COMBAT and SECRET_CLIENT then return secret(v) end return v end

-- ================================================================ units
local enemyUnits = { target = true, targettarget = true, focus = true }
GROUP = false
RAID = false
DEAD, OFFLINE, FAR, DEBUFF = {}, {}, {}, {}
local function partyUnit(u) return type(u) == "string" and (u:match("^party[1-4]$") or u:match("^partypet[1-4]$")) end
function UnitExists(u)
	if u == "player" then return true end
	if u == "pet" then return PET end
	if u == "target" or u == "targettarget" then return TARGET end
	if partyUnit(u) then return GROUP and not u:match("pet") end
	if type(u) == "string" and u:match("^raid%d+$") then return RAID and tonumber(u:match("%d+")) <= 10 end
	if type(u) == "string" and u:match("^boss%d$") then return COMBAT and u == "boss1" end
	return false
end

function UnitClassBase() return CLASS_FILE end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitLevel() return 60 end
function UnitName(u) if u == "player" then return "Rob", nil end return S("Bandit"), nil end
function UnitPVPName() return "Rob" end
function UnitGUID(u) return u == "player" and "Player-1-1" or "Creature-0-1-1-1-1-1" end
function UnitIsUnit(a, b) return a == b end
function UnitIsPlayer(u) return u == "player" end
function UnitIsDead(u) return false end
function UnitIsGhost() return false end
function UnitIsDeadOrGhost() return false end
function UnitIsAFK() return false end
function UnitIsDND() return false end
function UnitIsPVP() return false end
function UnitIsConnected() return true end
function UnitIsVisible() return true end
function UnitInRange() return true, true end
function UnitPosition() return 0, 0, 0, 0 end
function UnitAffectingCombat(u) return COMBAT end
function UnitCanAttack(a, u) return enemyUnits[u] == true end
function UnitIsFriend(a, u) return not enemyUnits[u] end
function UnitReaction(a, b) if enemyUnits[a] or enemyUnits[b] then return 2 end return 5 end
function UnitClassification() return "normal" end
function UnitCreatureType() return "Humanoid" end
function UnitCreatureFamily() return nil end
function UnitGroupRolesAssigned() return "DAMAGER" end
function UnitInVehicle() return false end
function UnitHasVehicleUI() return false end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
function UnitAttackSpeed() return 2.4, nil end
function UnitSelectionColor() return 1, 0, 0, 1 end
HEALTH, HEALTHMAX, POWER, POWERMAX = 7000, 10000, 40, 100
function UnitHealth(u) return S(u == "player" and HEALTH or 3000) end
function UnitHealthMax(u) return S(u == "player" and HEALTHMAX or 6000) end
function UnitName(u) if u == "player" then return "Rob", nil end if partyUnit(u) then return "Mate" .. u:sub(-1), nil end return S("Bandit"), nil end
function UnitPower(u, t) return S(POWER) end
function UnitPowerMax(u, t) return S(POWERMAX) end
function UnitPowerType(u) return POWERTYPE or 0, "MANA" end
function GetComboPoints() return S(2) end
function GetSpellCooldown() return S(0), S(0), 1, 1 end
function GetSpellInfo(id) if rawtype(id) == "number" or rawtype(id) == "string" then return "Spell" .. tostring(id), nil, 134400, 0, 0, 30, id end end
function IsUsableSpell() return true, false end
function GetSpellCharges() return nil end
function UnitAura() return nil end
function UnitBuff() return nil end
function UnitDebuff() return nil end
function CombatLogGetCurrentEventInfo() return 0, "SPELL_DAMAGE" end
C_Spell = {
	GetSpellInfo = function(id) return { name = "Spell" .. tostring(id), iconID = 134400, spellID = id, castTime = 0 } end,
	GetSpellName = function(id) return "Spell" .. tostring(id) end,
	GetSpellTexture = function() return 134400 end,
	GetSpellCooldown = function() return { startTime = S(0), duration = S(0), isEnabled = true, modRate = 1 } end,
	GetSpellCharges = function() return nil end,
	IsSpellUsable = function() return true, false end,
}
C_UnitAuras = {
	GetAuraDataByIndex = function() return nil end,
	GetDebuffDataByIndex = function() return nil end,
	GetBuffDataByIndex = function() return nil end,
	GetPlayerAuraBySpellID = function() return nil end,
}
AuraUtil = { FindAuraByName = function() return nil end, ForEachAura = function() end, UnpackAuraData = function() return nil end }
C_UnitAuras.GetDebuffDataByIndex = function(u, i)
	local t = DEBUFF_FOR(u, i)
	if t then return { name = S("Curse of Doom"), icon = 134400, applications = 0, dispelName = S(t), duration = 30, expirationTime = NOW + 30, sourceUnit = "target", spellId = 603 } end
end
C_UnitAuras.GetBuffDataByIndex = function(u, i)
	if u == "target" and i == 1 then return { name = S("Arcane Intellect"), icon = 134400, applications = 0, dispelName = S("Magic"), isStealable = S(true), duration = 1800, expirationTime = NOW + 1800, sourceUnit = "target", spellId = 1459 } end
end
function IsInGroup() return GROUP end
function GetNumGroupMembers() return GROUP and 5 or 0 end
function GetNumSubgroupMembers() return GROUP and 4 or 0 end
function UnitInParty(u) return GROUP and (u == "player" or partyUnit(u)) and true or false end
function UnitIsGroupLeader(u) return u == "player" end
function UnitThreatSituation() return S(0) end
function UnitDetailedThreatSituation() return S(false), S(0), S(0), S(0), S(0) end
function UnitGetIncomingHeals() return S(0) end
function UnitGetTotalAbsorbs() return S(0) end
function UnitPhaseReason() return nil end
function UnitIsCharmed() return false end
function UnitHasIncomingResurrection() return false end
function UnitClass(u)
	if u == "player" or u == "vehicle" then return CLASS_NAME, CLASS_FILE, CLASS_ID end
	if u == "party2" then return "Priest", "PRIEST", 5 end
	return "Warrior", "WARRIOR", 1
end
function IsPlayerSpell() return true end
function IsSpellKnown() return true end
function IsSpellKnownOrOverridesKnown() return true end
function GetSpecialization() return 1 end
function GetSpecializationInfo(i) return 1, "Spec", "", 134400, "DAMAGER" end
function GetSpecializationInfoByID() return 1, "Spec" end
function GetInspectSpecialization() return 0 end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(i) return "Tree" .. i, nil, 0 end

-- party situations (after the defaults above)
function IsInRaid() return RAID end
function UnitIsDead(u) return S(DEAD[u] or false) end
function UnitIsGhost() return false end
function UnitIsDeadOrGhost(u) return S(DEAD[u] or false) end
function UnitIsConnected(u) return not OFFLINE[u] end
function UnitInRange(u) return not FAR[u], true end
function UnitHasVehicleUI(u) return VEHICLE and u == "player" or false end
-- a dispellable debuff on a unit, both old and new aura APIs
function DEBUFF_FOR(u, i)
	local t = DEBUFF[u]
	if t and i == 1 then return t end
end
function UnitDebuff(u, i) local t = DEBUFF_FOR(u, i) if t then return S("Curse of Doom"), 134400, 0, S(t), 30, NOW + 30, "target", false, false, 603 end end
function UnitBuff(u, i) if u == "target" and i == 1 then return S("Arcane Intellect"), 134400, 0, S("Magic"), 1800, NOW + 1800, "target", S(true), false, 1459 end end
function UnitAura(u, i, filter)
	if type(filter) == "string" and filter:find("HARMFUL") then return UnitDebuff(u, i) end
	return UnitBuff(u, i)
end

-- ======================================================== flavor tweaks
CLASS_NAME = ({ WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "Death Knight",
	SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker" })[CLASS_FILE]
SECRET_CLIENT = (FLAVOR == "retail" or FLAVOR == "forever")
if SECRET_CLIENT then
	-- removed on Retail (11.0+) and so on WoW Forever
	for _, k in ipairs({ "GetSpellInfo", "GetSpellCooldown", "IsUsableSpell", "GetSpellCharges", "UnitAura", "UnitBuff", "UnitDebuff",
		"CombatLogGetCurrentEventInfo", "GetSpellTexture", "GetAddOnMetadata", "IsAddOnLoaded" }) do
		_G[k] = nil
	end
	-- readable percentages for display (secret-safe)
	CurveConstants = { ScaleTo100 = 1, Reverse = 2 }
	function UnitHealthPercent(u, predicted, curve)
		local h, m = (u == "player" and HEALTH or 3000), (u == "player" and HEALTHMAX or 6000)
		local p = h / m
		if curve == CurveConstants.ScaleTo100 then return p * 100 end
		return p
	end
	function UnitPowerPercent(u, t, curve)
		local p = POWER / POWERMAX
		if curve == CurveConstants.ScaleTo100 then return p * 100 end
		return p
	end
	function AbbreviateNumbers(v) if isSecret(v) then return "1.2K" end return tostring(v) end
	C_StringUtil = { TruncateWhenZero = function(v) if isSecret(v) then return secret("") end return tostring(v) end }
	function issecretvalue(v) return isSecret(v) end
	function canaccessvalue(v) return not isSecret(v) end
	function issecrettable() return false end
	function canaccesstable() return true end
	-- The new menu system replaced UnitPopup on Retail
	UnitPopup_ShowMenu = nil
	MenuUtil = { CreateContextMenu = function() end }
end
if FLAVOR == "era" or FLAVOR == "tbc" or FLAVOR == "forever" then
	GetSpecialization, GetSpecializationInfo, GetSpecializationInfoByID, GetInspectSpecialization = nil, nil, nil, nil
end
if FLAVOR == "wrath" or FLAVOR == "cata" then
	GetSpecialization, GetSpecializationInfo, GetSpecializationInfoByID = nil, nil, nil
	function GetPrimaryTalentTree() return 1 end
end
if FLAVOR == "retail" then
	GetNumTalentTabs, GetTalentTabInfo = nil, nil
end

-- Blizzard's party frames: one per member on Classic, PartyFrame on Retail
if FLAVOR == "retail" then
	PartyFrame = perm("PartyFrame"); PartyFrame.shown = true
	for i = 1, 4 do PartyFrame["MemberFrame" .. i] = perm("PartyMemberFrame") end
	CompactPartyFrame = perm("CompactPartyFrame")
else
	for i = 1, 4 do
		local f = perm("PartyMemberFrame"); f.__gname = "PartyMemberFrame" .. i; f.shown = true
		_G["PartyMemberFrame" .. i] = f
	end
end
-- the color picker (the newer one on every current client)
ColorPickerFrame = perm("ColorPickerFrame")
ColorPickerFrame.SetupColorPickerAndShow = function(self, info) self.info = info; self.shown = true end
ColorPickerFrame.GetColorRGB = function() return 1, 0.5, 0 end
ColorPickerFrame.GetColorAlpha = function() return 1 end
SOUNDKIT = setmetatable({}, { __index = function() return 8960 end })
function PlaySoundFile() return true end
C_XMLUtil = { GetTemplateInfo = function(t) return { type = "Frame", width = 0, height = 0 } end }
-- APIs this client doesn't have: never stubbed
ABSENT = {}
if SECRET_CLIENT then
	for _, k in ipairs({ "GetSpellInfo", "GetSpellCooldown", "IsUsableSpell", "GetSpellCharges", "UnitAura", "UnitBuff", "UnitDebuff",
		"CombatLogGetCurrentEventInfo", "GetSpellTexture", "GetAddOnMetadata", "IsAddOnLoaded", "UnitPopup_ShowMenu" }) do ABSENT[k] = true end
else
	for _, k in ipairs({ "UnitHealthPercent", "UnitPowerPercent", "CurveConstants", "issecretvalue", "canaccessvalue", "MenuUtil", "C_StringUtil",
		"CreateUnitHealPredictionCalculator", "C_CurveUtil", "C_Secrets", "C_RestrictedActions" }) do ABSENT[k] = true end
end
if FLAVOR ~= "mists" and FLAVOR ~= "retail" then
	for _, k in ipairs({ "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoByID" }) do ABSENT[k] = true end
end
if FLAVOR == "era" or FLAVOR == "tbc" or FLAVOR == "forever" then ABSENT.GetInspectSpecialization = true end
if FLAVOR == "retail" then ABSENT.GetNumTalentTabs = true; ABSENT.GetTalentTabInfo = true end

-- any other global API -> a no-op (recorded); frames named RC32* are never stubbed
MISSING = {}
setmetatable(_G, { __index = function(t, k)
	if rawtype(k) ~= "string" then return nil end
	-- an unknown C_ namespace: a table of no-op functions
	if k:match("^C_%u") and not ABSENT[k] then
		MISSING[k] = true
		local ns = setmetatable({}, { __index = function() return function() return nil end end })
		rawset(t, k, ns)
		return ns
	end
	if ABSENT[k] or (rawget(_G, "XMLNAMES") and rawget(_G, "XMLNAMES")[k]) or k:match("^RCSpellFlash") or k:match("^RCSF") or k:match("^SLASH_") or k:match("^[A-Z_0-9]+$") or k:match("DB$") then return nil end
	-- names that look like frames (the addon's own, created later or never) stay nil
	if k:match("%d$") then return nil end
	-- other addons aren't installed
	for _, pre in ipairs({ "ElvU", "Bartender", "Dominos", "Grid", "VuhDo", "Vuhdo", "Plater", "Details", "WeakAuras", "TacoTip", "Bagnon" }) do
		if k:sub(1, #pre) == pre then return nil end
	end
	for _, suffix in ipairs({ "Button", "Slider", "Frame", "Label", "Text", "Dropdown", "DropDown", "Backdrop", "Box", "Panel", "Bar", "Orb", "Icon" }) do
		if k:sub(-#suffix) == suffix then return nil end
	end
	-- only names that look like game API functions get a no-op stand-in;
	-- anything else (other addons' frames and tables) isn't there
	local verb = k:match("^(%u%l+)")
	local API_VERBS = { Unit = 1, Get = 1, Is = 1, Has = 1, Can = 1, Set = 1, Create = 1, Register = 1, Unregister = 1, Play = 1,
		Stop = 1, Hide = 1, Show = 1, Toggle = 1, Enable = 1, Disable = 1, Load = 1, Send = 1, Cancel = 1, Clear = 1, Close = 1,
		Open = 1, Update = 1, Request = 1, Do = 1, Use = 1, Pick = 1, Run = 1, Spell = 1, Target = 1, Focus = 1, Assist = 1,
		Inspect = 1, Notify = 1, Check = 1, Reset = 1, Find = 1, Accept = 1, Decline = 1, Leave = 1, Invite = 1, Promote = 1 }
	if not verb or not API_VERBS[verb] then return nil end
	if k:match("^[A-Z]") and not k:match("Button%d") and not k:match("^DropDownList") then
		MISSING[k] = true
		return function() return nil end
	end
end })
