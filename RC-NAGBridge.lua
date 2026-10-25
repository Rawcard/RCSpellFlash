-- RC-NAGBridge: Bridge between NAG addon and RC-SpellFlash
-- Reads NAG.nextSpell (primary) and NAG.secondarySpells (left/right/above/below)
-- and tells RC-SpellFlash which buttons to flash

local ADDON_NAME = "RC-NAGBridge"
local UPDATE_FREQUENCY = 0.05 -- How often to check NAG for updates

-- Wait for RC-SpellFlash to load
local SF = nil
local bridgeFrame = CreateFrame("Frame")
local isInitialized = false

-- Debug mode (set to true to see debug messages)
local DEBUG_MODE = false  -- Disabled - working correctly!
local DEBUG_STANCE = false  -- Disabled - working correctly!

local function DebugPrint(...)
    if DEBUG_MODE then
        print("|cff00ff00[RC-NAGBridge]|r", ...)
    end
end

-- Initialize the bridge
local function Initialize()
    if isInitialized then return true end
    
    -- Try to get RC-SpellFlash library
    if LibStub then
        SF = LibStub("RCSpellFlash", true)
    end
    
    if not SF then
        DebugPrint("RC-SpellFlash not found, waiting...")
        return false
    end
    
    -- Register with RC-SpellFlash
    SF:RegisterAddon(ADDON_NAME)
    
    isInitialized = true
    DebugPrint("Initialized successfully!")
    return true
end

-- Get color for a position type
local function GetColorForPosition(position)
    if not SF or not SF.Config or not SF.Config.colors then
        return 1, 1, 0, 1 -- Default yellow
    end
    
    local colors = SF.Config.colors
    
    if position == "LEFT" or position == "left" then
        local c = colors.left or {0, 1, 1, 1}
        return c[1], c[2], c[3], c[4] or 1
    elseif position == "ABOVE" or position == "above" then
        local c = colors.above or {1, 0.5, 0, 1}
        return c[1], c[2], c[3], c[4] or 1
    elseif position == "RIGHT" or position == "right" then
        -- Use left color for right (or define a separate right color)
        local c = colors.left or {0, 1, 1, 1}
        return c[1], c[2], c[3], c[4] or 1
    elseif position == "BELOW" or position == "below" then
        -- Use above color for below (or define a separate below color)
        local c = colors.above or {1, 0.5, 0, 1}
        return c[1], c[2], c[3], c[4] or 1
    elseif position == "AOE" or position == "aoe" then
        local c = colors.above or {1, 0.5, 0, 1}
        return c[1], c[2], c[3], c[4] or 1
    else
        -- Primary/default
        local c = colors.primary or SF.Config.color or {1, 1, 0, 1}
        return c[1], c[2], c[3], c[4] or 1
    end
end

-- Update flashes based on NAG data
local function UpdateFromNAG()
    if not isInitialized then
        if not Initialize() then return end
    end
    
    if not SF then 
        DebugPrint("ERROR: SF is nil!")
        return 
    end
    if not NAG then 
        DebugPrint("ERROR: NAG is nil!")
        return 
    end
    
    -- Track what we need to flash
    local spellsToFlash = {}
    
    -- Check if NAG is using group display mode
    local DisplayManager = NAG.GetModule and NAG:GetModule("DisplayManager", true)
    if DisplayManager and DisplayManager.IsGroupDisplayMode then
        local isGroupMode = DisplayManager:IsGroupDisplayMode()
        DebugPrint("NAG IsGroupDisplayMode:", isGroupMode)
    else
        DebugPrint("DisplayManager.IsGroupDisplayMode not available")
    end
    
    -- NEW APPROACH: Use NAG:GetDisplayGroupIconData() which returns all display data organized by groups
    if NAG.GetDisplayGroupIconData then
        local groupData = NAG:GetDisplayGroupIconData()
        
        if groupData and type(groupData) == "table" then
            DebugPrint("Got group data from NAG:GetDisplayGroupIconData()")
            
            -- Process each group (MAIN, COOLDOWNS, AOE, DEFENSIVES, INTERRUPTS, SEQUENCE)
            for groupName, icons in pairs(groupData) do
                if type(icons) == "table" then
                    DebugPrint("Processing group:", groupName, "with", #icons, "icons")
                    
                    for i, iconData in ipairs(icons) do
                        local spellId = iconData.spellId or iconData.itemId
                        if spellId and type(spellId) == "number" then
                            -- Determine color based on group
                            local position = "primary"
                            if groupName == "COOLDOWNS" or groupName == "cooldowns" then
                                position = "left"
                            elseif groupName == "AOE" or groupName == "aoe" then
                                position = "aoe"
                            elseif groupName == "DEFENSIVES" or groupName == "defensives" then
                                position = "above"
                            elseif groupName == "INTERRUPTS" or groupName == "interrupts" then
                                position = "below"
                            end
                            
                            local r, g, b, a = GetColorForPosition(position)
                            
                            -- Add to flash table (won't override if same spell already exists)
                            if not spellsToFlash[spellId] then
                                spellsToFlash[spellId] = {
                                    position = position,
                                    r = r, g = g, b = b, a = a
                                }
                                DebugPrint("ADDED from group", groupName, ":", spellId, GetSpellInfo(spellId), "position:", position)
                            else
                                DebugPrint("SKIPPED (already exists):", spellId, "from group:", groupName)
                            end
                        end
                    end
                end
            end
        else
            DebugPrint("ERROR: GetDisplayGroupIconData returned invalid data, type:", type(groupData))
        end
    else
        DebugPrint("ERROR: NAG.GetDisplayGroupIconData does not exist!")
    end
    
    -- FALLBACK: Always check NAG.secondarySpells directly as well
    if NAG.secondarySpells and type(NAG.secondarySpells) == "table" and #NAG.secondarySpells > 0 then
        DebugPrint("FALLBACK: Found", #NAG.secondarySpells, "in NAG.secondarySpells")
        for i, entry in ipairs(NAG.secondarySpells) do
            if entry and type(entry) == "table" then
                local secondarySpellId = entry.spellId or entry.itemId
                if secondarySpellId and type(secondarySpellId) == "number" then
                    local position = entry.position or "LEFT"
                    local r, g, b, a = GetColorForPosition(position)
                    
                    if not spellsToFlash[secondarySpellId] then
                        spellsToFlash[secondarySpellId] = {
                            position = position,
                            r = r, g = g, b = b, a = a
                        }
                        DebugPrint("FALLBACK ADDED:", secondarySpellId, GetSpellInfo(secondarySpellId), "position:", position)
                    end
                end
            end
        end
    end
    
    -- Clear previous flashes
    if SF.ClearFlashes then
        SF:ClearFlashes(ADDON_NAME)
        DebugPrint("Cleared previous flashes")
    else
        DebugPrint("ERROR: SF.ClearFlashes is nil!")
    end
    
    -- Flash all spells with their colors
    DebugPrint("=== FLASH TABLE CONTENTS ===")
    for spellId, data in pairs(spellsToFlash) do
        DebugPrint("  Spell ID:", spellId, "Position:", data.position, "Color:", data.r, data.g, data.b, data.a)
    end
    DebugPrint("=== STARTING FLASH ===")
    
    local flashCount = 0
    for spellId, data in pairs(spellsToFlash) do
        if SF.FlashSpell then
            SF:FlashSpell(ADDON_NAME, spellId, data.r, data.g, data.b, data.a)
            flashCount = flashCount + 1
            DebugPrint("Flashed spell:", spellId, "position:", data.position, "RGBA:", data.r, data.g, data.b, data.a)
        else
            DebugPrint("ERROR: SF.FlashSpell is nil!")
        end
    end
    DebugPrint("Total spells flashed:", flashCount)
end

-- Throttled update
local timeSinceLastUpdate = 0

bridgeFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= UPDATE_FREQUENCY then
        timeSinceLastUpdate = 0
        UpdateFromNAG()
    end
end)

-- Events
bridgeFrame:RegisterEvent("PLAYER_LOGIN")
bridgeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

bridgeFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Delay initialization to ensure other addons are loaded
        C_Timer.After(2, function()
            if Initialize() then
                print("|cff00ff00RC-NAGBridge|r loaded - bridging NAG to RC-SpellFlash")
                
                -- Register for NAG's frame update message (after UpdateFromNAG is defined)
                if NAG and NAG.RegisterMessage then
                    NAG.RegisterMessage(bridgeFrame, "NAG_FRAME_UPDATED", function()
                        DebugPrint("Received NAG_FRAME_UPDATED message")
                        UpdateFromNAG()
                    end)
                    DebugPrint("Registered for NAG_FRAME_UPDATED messages")
                else
                    DebugPrint("NAG.RegisterMessage not available, will use polling")
                end
            end
        end)
    end
end)

-- Slash command for debugging
SLASH_RCNAGBRIDGE1 = "/nagbridge"
SLASH_RCNAGBRIDGE2 = "/rcnagbridge"
SlashCmdList["RCNAGBRIDGE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "debug" then
        DEBUG_MODE = not DEBUG_MODE
        print("|cff00ff00RC-NAGBridge|r Debug mode:", DEBUG_MODE and "ON" or "OFF")
    elseif msg == "status" then
        print("|cff00ff00RC-NAGBridge Status:|r")
        print("  Initialized:", isInitialized and "Yes" or "No")
        print("  SF variable:", SF and "Found" or "NOT FOUND")
        print("  SF type:", type(SF))
        print("  NAG variable:", NAG and "Found" or "NOT FOUND")
        print("  NAG type:", type(NAG))
        
        if SF then
            print("  SF.FlashSpell:", SF.FlashSpell and "exists" or "MISSING")
            print("  SF.ClearFlashes:", SF.ClearFlashes and "exists" or "MISSING")
            print("  SF.Config:", SF.Config and "exists" or "MISSING")
        end
        
        if NAG then
            print("  NAG.nextSpell type:", type(NAG.nextSpell))
            if NAG.nextSpell then
                if type(NAG.nextSpell) == "number" then
                    print("  NAG.nextSpell:", tostring(NAG.nextSpell))
                    local spellName = GetSpellInfo(NAG.nextSpell)
                    print("    Spell name:", spellName or "UNKNOWN")
                elseif type(NAG.nextSpell) == "table" then
                    print("  NAG.nextSpell: (table)")
                    print("    spellId:", tostring(NAG.nextSpell.spellId))
                    print("    itemId:", tostring(NAG.nextSpell.itemId))
                    print("    position:", tostring(NAG.nextSpell.position))
                    local spellId = NAG.nextSpell.spellId or NAG.nextSpell.itemId
                    if spellId then
                        local spellName = GetSpellInfo(spellId)
                        print("    Spell name:", spellName or "UNKNOWN")
                    end
                else
                    print("  NAG.nextSpell:", tostring(NAG.nextSpell))
                end
            else
                print("  NAG.nextSpell: nil")
            end
            
            print("  NAG.secondarySpells type:", type(NAG.secondarySpells))
            if NAG.secondarySpells and type(NAG.secondarySpells) == "table" then
                print("  NAG.secondarySpells count:", #NAG.secondarySpells)
                for i, entry in ipairs(NAG.secondarySpells) do
                    if entry and type(entry) == "table" then
                        print("    [" .. i .. "] spellId:", tostring(entry.spellId), "position:", tostring(entry.position))
                        if entry.spellId and type(entry.spellId) == "number" then
                            local spellName = GetSpellInfo(entry.spellId)
                            print("        name:", spellName or "UNKNOWN")
                        end
                    else
                        print("    [" .. i .. "] INVALID ENTRY (type: " .. type(entry) .. ")")
                    end
                end
            else
                print("  NAG.secondarySpells: nil or not a table")
            end
        end
    elseif msg == "colors" then
        -- Open RC-SpellFlash color options
        if SF and SF.optionsPanel then
            SF.optionsPanel:Show()
        else
            SlashCmdList["SPELLFLASH"]("config")
        end
    elseif msg == "test" then
        print("|cff00ff00RC-NAGBridge|r Testing flash...")
        if SF then
            -- Flash test spells
            SF:ClearFlashes(ADDON_NAME)
            
            -- Try to flash current NAG recommendations
            if NAG and NAG.nextSpell then
                local primarySpellId = NAG.nextSpell
                if type(NAG.nextSpell) == "table" then
                    primarySpellId = NAG.nextSpell.spellId or NAG.nextSpell.itemId
                end
                if primarySpellId and type(primarySpellId) == "number" then
                    local r, g, b, a = GetColorForPosition("primary")
                    SF:FlashSpell(ADDON_NAME, primarySpellId, r, g, b, a)
                    print("  Flashing primary:", primarySpellId, GetSpellInfo(primarySpellId))
                end
            end
            
            if NAG and NAG.secondarySpells then
                for i, entry in ipairs(NAG.secondarySpells) do
                    if entry and entry.spellId then
                        local r, g, b, a = GetColorForPosition(entry.position)
                        SF:FlashSpell(ADDON_NAME, entry.spellId, r, g, b, a)
                        print("  Flashing secondary:", entry.spellId, GetSpellInfo(entry.spellId), "[" .. (entry.position or "?") .. "]")
                    end
                end
            end
            
            C_Timer.After(3, function()
                SF:ClearFlashes(ADDON_NAME)
                print("|cff00ff00RC-NAGBridge|r Test complete")
            end)
        else
            print("  RC-SpellFlash not found!")
        end
    else
        print("|cff00ff00RC-NAGBridge Commands:|r")
        print("  /nagbridge status - Show current status and NAG data")
        print("  /nagbridge debug - Toggle debug mode")
        print("  /nagbridge colors - Open color options")
        print("  /nagbridge test - Test flash current NAG spells")
    end
end
