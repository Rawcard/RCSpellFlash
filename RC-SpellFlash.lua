-- RCSpellFlash for MoP Classic
-- Visual spell indicators for action bars

local MAJOR_VERSION = "RCSpellFlash"
local MINOR_VERSION = 80006

if not LibStub then error(MAJOR_VERSION .. " requires LibStub") end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

-- Saved variables
RCSpellFlashCore = RCSpellFlashCore or {}

-- Local references
local GetTime = GetTime
local UnitAffectingCombat = UnitAffectingCombat
local pairs = pairs
local ipairs = ipairs

-- Flash data storage - ensure they're always tables
if not lib.FlashSpells or type(lib.FlashSpells) ~= "table" then
    lib.FlashSpells = {}
end
if not lib.FlashSlots or type(lib.FlashSlots) ~= "table" then
    lib.FlashSlots = {}
end
if not lib.RegisteredAddons or type(lib.RegisteredAddons) ~= "table" then
    lib.RegisteredAddons = {}
end

-- Configuration
lib.Config = lib.Config or {
    enabled = true,
    color = {1, 1, 0, 1}, -- Yellow (default/fallback)
    colors = {
        primary = {1, 1, 0, 1}, -- Yellow for primary
        left = {0, 1, 1, 1}, -- Cyan for left
        above = {1, 0.5, 0, 1}, -- Orange for above
    },
    size = 1.4,
    brightness = 0.8,
    inCombatOnly = false,
    throttle = 0.05, -- Update every 0.05 seconds
    showOutline = true, -- Show glowing outline
}

-- Action button collections for different action bar addons
local ActionButtonCollections = {
    -- Default Blizzard bars
    Blizzard = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarLeftButton", "MultiBarRightButton",
        "StanceButton", -- Stance bar (Death Knight Presences, Druid forms, Warrior stances, etc.)
        "PetActionButton", -- Pet action bar
        "PossessButton", -- Vehicle/Mind Control bar
    },
    -- Bartender4
    Bartender4 = {
        "BT4Button",
    },
    -- Dominos
    Dominos = {
        "DominosActionButton",
    },
    -- ElvUI
    ElvUI = {
        "ElvUI_Bar", -- ElvUI uses a different structure
        "ElvUI_StanceBarButton", -- ElvUI stance bar
    },
}

-- Texture for the flash effect
-- Client compatibility ---------------------------------------------------------
-- Retail (11.0+) and WoW Forever removed GetSpellInfo; rebuild it from C_Spell.
local GetSpellInfo = GetSpellInfo or function(spell)
    if spell == nil or not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local info = C_Spell.GetSpellInfo(spell)
    if info then
        return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
    end
end
RCSF_GetSpellInfo = GetSpellInfo

-- Create a frame from the first template this client has (older options
-- templates are gone from some clients), and make sure the pieces the code uses
-- (.Text on check boxes; Low / High / Text on sliders) exist either way.
function RCSF_Create(kind, name, parent, templates)
    local frame
    for _, t in ipairs(templates) do
        local known = true
        if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
            known = C_XMLUtil.GetTemplateInfo(t) ~= nil
        end
        if known then
            local ok, f = pcall(CreateFrame, kind, name, parent, t)
            if ok and f then frame = f break end
        end
    end
    frame = frame or CreateFrame(kind, name, parent)
    local function text(key, point)
        local fs = name and _G[name .. key]
        if not fs then
            fs = frame:CreateFontString(name and (name .. key) or nil, "ARTWORK", "GameFontHighlightSmall")
            fs:SetPoint(point, frame, point == "LEFT" and "RIGHT" or point, 0, 0)
        end
        return fs
    end
    if kind == "CheckButton" then
        frame.Text = frame.Text or frame.text or text("Text", "LEFT")
    elseif kind == "Slider" then
        frame.Low = frame.Low or text("Low", "BOTTOMLEFT")
        frame.High = frame.High or text("High", "BOTTOMRIGHT")
        frame.Text = frame.Text or text("Text", "TOP")
    end
    return frame
end

-- Open the game's color picker on any client: the newer picker (Retail, and the
-- Classic clients that adopted it) uses SetupColorPickerAndShow; the old one
-- takes its callbacks as fields.
function RCSF_OpenColorPicker(r, g, b, onChange, onCancel)
    if not ColorPickerFrame then return end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() onChange() end,
            cancelFunc = function(previous) if onCancel then onCancel(previous) end end,
            previousValues = { r = r, g = g, b = b },
        })
        return
    end
    ColorPickerFrame.func = onChange
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = onCancel or onChange
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { r = r, g = g, b = b }
    if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(r, g, b) end
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local FLASH_TEXTURE = "Interface\\Cooldown\\star4" -- (the custom RCSpellFlash texture was never shipped)
local FALLBACK_TEXTURE = "Interface\\Cooldown\\star4"

-- Throttle timer
local lastUpdate = 0
local updateDelay = 0.05

-- Create flash frames for action buttons
local function CreateFlashFrame(button)
    if not button or button.RCSpellFlashFrame then return button.RCSpellFlashFrame end
    
    -- Check if this is a stance button (they need higher frame levels)
    local buttonName = button:GetName() or ""
    local isStanceButton = string.match(buttonName, "^StanceButton")
                        or string.match(buttonName, "^ElvUI_StanceBarButton")
                        or string.match(buttonName, "^RCUI32StanceBtn")
    
    -- Parent to UIParent, NOT the button. Some bars (e.g. RCUI32_bar1Header) are
    -- hidden while their buttons are still active, making button-parented frames
    -- invisible. Parenting to UIParent keeps the flash visible regardless.
    -- SetAllPoints(button) still anchors position to the button's coordinates.
    local flash = CreateFrame("Frame", nil, UIParent)
    flash:SetAllPoints(button)
    flash:SetFrameStrata("HIGH")
    if isStanceButton then
        flash:SetFrameLevel(200)
    else
        flash:SetFrameLevel(100)
    end
    
    -- Create the main fill texture
    local texture = flash:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(flash)
    texture:SetBlendMode("ADD")
    texture:SetDrawLayer("OVERLAY", 7)  -- Higher sublayer for visibility
    
    -- Try to use custom texture, fall back to default if not available
    local texturePath = FLASH_TEXTURE
    texture:SetTexture(texturePath)
    
    -- If texture fails to load, use fallback
    if not texture:GetTexture() then
        texture:SetTexture(FALLBACK_TEXTURE)
    end
    
    texture:SetVertexColor(1, 1, 0) -- Start with yellow color
    texture:SetAlpha(0) -- Start hidden
    
    flash.texture = texture
    
    -- Create outline glow effect
    local outline = CreateFrame("Frame", nil, flash)
    outline:SetAllPoints(flash)
    outline:SetFrameLevel(flash:GetFrameLevel() + 1)
    
    -- Create 4 edge textures for the outline
    local edges = {}
    
    -- Top edge
    edges.top = outline:CreateTexture(nil, "OVERLAY")
    edges.top:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    edges.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    edges.top:SetHeight(3)
    edges.top:SetTexture("Interface\\Buttons\\WHITE8X8")
    edges.top:SetBlendMode("ADD")
    
    -- Bottom edge
    edges.bottom = outline:CreateTexture(nil, "OVERLAY")
    edges.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2, -2)
    edges.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    edges.bottom:SetHeight(3)
    edges.bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    edges.bottom:SetBlendMode("ADD")
    
    -- Left edge
    edges.left = outline:CreateTexture(nil, "OVERLAY")
    edges.left:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    edges.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2, -2)
    edges.left:SetWidth(3)
    edges.left:SetTexture("Interface\\Buttons\\WHITE8X8")
    edges.left:SetBlendMode("ADD")
    
    -- Right edge
    edges.right = outline:CreateTexture(nil, "OVERLAY")
    edges.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    edges.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    edges.right:SetWidth(3)
    edges.right:SetTexture("Interface\\Buttons\\WHITE8X8")
    edges.right:SetBlendMode("ADD")
    
    -- Hide all edges by default
    for _, edge in pairs(edges) do
        edge:SetVertexColor(1, 1, 0)
        edge:SetAlpha(0) -- Start hidden
    end
    
    flash.outline = outline
    flash.edges = edges
    
    -- Animation for pulsing effect
    flash.animTime = 0
    flash:SetScript("OnUpdate", function(self, elapsed)
        if self:IsShown() then
            self.animTime = self.animTime + elapsed
            local pulse = (math.sin(self.animTime * 3) + 1) / 2 -- Oscillates between 0 and 1
            local alpha = 0.3 + (pulse * 0.4) -- Varies between 0.3 and 0.7
            
            -- Pulse the outline
            local r, g, b = self.color.r, self.color.g, self.color.b
            if lib.Config.showOutline then
                for _, edge in pairs(self.edges) do
                    edge:SetVertexColor(r, g, b)
                    edge:SetAlpha(alpha)
                end
            end
        end
    end)
    
    flash.color = {r = 1, g = 1, b = 0} -- Default yellow
    flash:Hide()
    
    button.RCSpellFlashFrame = flash
    return flash
end

-- Get all action buttons from all supported action bar addons
local function GetAllActionButtons()
    local buttons = {}
    
    -- Blizzard default bars
    for _, prefix in ipairs(ActionButtonCollections.Blizzard) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                table.insert(buttons, button)
            end
        end
    end
    
    -- RCDiabloUI (RCUI32_bar1Button1 … RCUI32_bar6Button12)
    -- NOTE: LAB's UpdateState early-returns if GetAttribute("state") isn't set yet,
    -- leaving button.action=0 for bars that don't have a state driver (bars 2 & 4).
    -- Compute the slot directly from the naming convention when this happens.
    for barNum = 1, 6 do
        for btnNum = 1, 12 do
            local button = _G["RCUI32_bar" .. barNum .. "Button" .. btnNum]
            if button then
                if not button.action or button.action == 0 then
                    -- barN page = N, slot = btnNum → actionSlot = (N-1)*12 + btnNum
                    button.action = (barNum - 1) * 12 + btnNum
                end
                table.insert(buttons, button)
            end
        end
    end
    -- RCDiabloUI stance buttons
    for i = 1, 10 do
        local button = _G["RCUI32StanceBtn" .. i]
        if button then
            table.insert(buttons, button)
        end
    end

    -- Bartender4
    if Bartender4 then
        for i = 1, 120 do
            local button = _G["BT4Button" .. i]
            if button then
                table.insert(buttons, button)
            end
        end
    end
    
    -- Dominos
    if Dominos then
        for i = 1, 120 do
            local button = _G["DominosActionButton" .. i]
            if button then
                table.insert(buttons, button)
            end
        end
    end
    
    -- ElvUI
    if ElvUI then
        -- ElvUI uses ElvUI_BarXButtonY naming convention
        for barNum = 1, 10 do
            for btnNum = 1, 12 do
                local button = _G["ElvUI_Bar" .. barNum .. "Button" .. btnNum]
                if button then
                    table.insert(buttons, button)
                end
            end
        end
        
        -- ElvUI Stance Bar (usually 1-10 buttons)
        for i = 1, 10 do
            local button = _G["ElvUI_StanceBarButton" .. i]
            if button then
                table.insert(buttons, button)
            end
        end
    end
    
    return buttons
end

-- Flash a specific action button
local function FlashButton(button, r, g, b, a)
    if not button then return end
    
    local flash = button.RCSpellFlashFrame or CreateFlashFrame(button)
    if not flash then return end
    
    r = r or lib.Config.color[1]
    g = g or lib.Config.color[2]
    b = b or lib.Config.color[3]
    a = a or lib.Config.color[4]
    
    -- Store color for outline animation
    flash.color = {r = r, g = g, b = b}
    
    -- Set main fill texture (color only, alpha separate)
    flash.texture:SetVertexColor(r, g, b)
    flash.texture:SetAlpha(a * lib.Config.brightness)
    
    -- Set outline color (will be animated in OnUpdate) if enabled
    if lib.Config.showOutline and flash.edges then
        for _, edge in pairs(flash.edges) do
            edge:SetVertexColor(r, g, b)
            edge:SetAlpha(0.5)
        end
    end
    
    flash:Show()
end

-- Stop flashing a button
local function StopFlashButton(button)
    if not button or not button.RCSpellFlashFrame then return end
    
    button.RCSpellFlashFrame.texture:SetAlpha(0)
    
    -- Hide outline edges
    if button.RCSpellFlashFrame.edges then
        for _, edge in pairs(button.RCSpellFlashFrame.edges) do
            edge:SetAlpha(0)
        end
    end
    
    button.RCSpellFlashFrame:Hide()
end

-- Update all flashing buttons
local function UpdateFlashes()
    if not lib.Config.enabled then return end
    
    -- Check combat restriction
    if lib.Config.inCombatOnly and not UnitAffectingCombat("player") then
        -- Clear all flashes
        local buttons = GetAllActionButtons()
        for _, button in ipairs(buttons) do
            StopFlashButton(button)
        end
        return
    end
    
    local buttons = GetAllActionButtons()
    local activeSpells = {}
    
    -- Collect all spells that should be flashing
    if lib.FlashSpells and type(lib.FlashSpells) == "table" then
        for addonName, spellData in pairs(lib.FlashSpells) do
            if type(spellData) == "table" and spellData.enabled ~= false then
                if spellData.spells and type(spellData.spells) == "table" then
                    for spellID, flashData in pairs(spellData.spells) do
                        activeSpells[spellID] = flashData
                    end
                end
            end
        end
    end
    
    -- Pre-scan: detect whether RCUI32 is the active action-bar UI.
    -- RCUI32 bar headers are SecureHandlerStateTemplate frames that are always
    -- IsShown=false (intentional design), so their children have IsVisible()=false
    -- even when the buttons are genuinely on-screen. We therefore can't use IsVisible()
    -- for RCUI32 buttons, and fall back to GetAlpha() > 0 — but only when RCUI32 is
    -- actually the active UI. If any other addon's bars (e.g. ElvUI) are visible,
    -- RCUI32 buttons are phantom remnants and must be skipped.
    local rcui32IsPrimaryUI = true
    for _, button in ipairs(buttons) do
        local name = button:GetName() or ""
        if not name:find("^RCUI32") then
            if button:IsVisible() and button:GetAlpha() > 0.1 then
                rcui32IsPrimaryUI = false
                break
            end
        end
    end

    -- Update each button
    for _, button in ipairs(buttons) do
        local shouldFlash = false
        local flashColor = nil
        
        -- Check button type by name
        local buttonName = button:GetName() or ""
        local isStanceButton = string.match(buttonName, "^StanceButton")
                            or string.match(buttonName, "^ElvUI_StanceBarButton")
                            or string.match(buttonName, "^RCUI32StanceBtn")
        local isPetButton = string.match(buttonName, "^PetActionButton")
        local isPossessButton = string.match(buttonName, "^PossessButton")
        
        if isStanceButton then
            -- Stance buttons use GetShapeshiftFormInfo instead of GetActionInfo
            local buttonID = button:GetID()
            if buttonID then
                local _, name, _, spellID = GetShapeshiftFormInfo(buttonID)
                
                if spellID and activeSpells[spellID] then
                    shouldFlash = true
                    flashColor = activeSpells[spellID].color
                else
                    -- Fallback: check by spell name
                    if spellID then
                        local spellName = GetSpellInfo(spellID)
                        if spellName then
                            for suggestedID, flashData in pairs(activeSpells) do
                                local suggestedName = GetSpellInfo(suggestedID)
                                if suggestedName and spellName == suggestedName then
                                    shouldFlash = true
                                    flashColor = flashData.color
                                    break
                                end
                            end
                        end
                    end
                end
            end
        elseif isPetButton then
            -- Pet action buttons use GetPetActionInfo
            local buttonID = button:GetID()
            if buttonID then
                local name, _, _, _, _, _, spellID = GetPetActionInfo(buttonID)
                if spellID and activeSpells[spellID] then
                    shouldFlash = true
                    flashColor = activeSpells[spellID].color
                else
                    -- Fallback: check by spell name
                    if spellID then
                        local spellName = GetSpellInfo(spellID)
                        if spellName then
                            for suggestedID, flashData in pairs(activeSpells) do
                                local suggestedName = GetSpellInfo(suggestedID)
                                if suggestedName and spellName == suggestedName then
                                    shouldFlash = true
                                    flashColor = flashData.color
                                    break
                                end
                            end
                        end
                    end
                end
            end
        elseif isPossessButton then
            -- Possess buttons use GetPossessInfo (similar to GetShapeshiftFormInfo)
            local buttonID = button:GetID()
            if buttonID and GetPossessInfo then
                local _, _, _, spellID = GetPossessInfo(buttonID)
                if spellID and activeSpells[spellID] then
                    shouldFlash = true
                    flashColor = activeSpells[spellID].color
                else
                    -- Fallback: check by spell name
                    if spellID then
                        local spellName = GetSpellInfo(spellID)
                        if spellName then
                            for suggestedID, flashData in pairs(activeSpells) do
                                local suggestedName = GetSpellInfo(suggestedID)
                                if suggestedName and spellName == suggestedName then
                                    shouldFlash = true
                                    flashColor = flashData.color
                                    break
                                end
                            end
                        end
                    end
                end
            end
        -- Regular action buttons
        elseif button.action then
            local actionType, id = GetActionInfo(button.action)
            
            if actionType == "spell" then
                local spellID = id
                if activeSpells[spellID] then
                    shouldFlash = true
                    flashColor = activeSpells[spellID].color
                else
                    -- Fallback: check by spell name (for different spell ID versions)
                    local spellName = GetSpellInfo(spellID)
                    if spellName then
                        for suggestedID, flashData in pairs(activeSpells) do
                            local suggestedName = GetSpellInfo(suggestedID)
                            if suggestedName and spellName == suggestedName then
                                shouldFlash = true
                                flashColor = flashData.color
                                break
                            end
                        end
                    end
                end
            elseif actionType == "macro" then
                -- GetMacroSpell returns a spell ID (number) in Classic MoP
                local macroSpellID = GetMacroSpell(id)
                if macroSpellID then
                    if activeSpells[macroSpellID] then
                        shouldFlash = true
                        flashColor = activeSpells[macroSpellID].color
                    else
                        -- Name-based fallback for spell ID version differences
                        local macroSpellName = GetSpellInfo(macroSpellID)
                        if macroSpellName then
                            for suggestedID, flashData in pairs(activeSpells) do
                                local suggestedName = GetSpellInfo(suggestedID)
                                if suggestedName and suggestedName == macroSpellName then
                                    shouldFlash = true
                                    flashColor = flashData.color
                                    break
                                end
                            end
                        end
                    end
                end
                -- Fallback: search macro body text for active spell names
                -- (catches conditional macros where GetMacroSpell returns nil)
                if not shouldFlash then
                    local _, _, macroBody = GetMacroInfo(id)
                    if macroBody then
                        for suggestedID, flashData in pairs(activeSpells) do
                            local suggestedName = GetSpellInfo(suggestedID)
                            if suggestedName and macroBody:find(suggestedName, 1, true) then
                                shouldFlash = true
                                flashColor = flashData.color
                                break
                            end
                        end
                    end
                end
            end
        end
        
        -- Determine if this button is actually visible to the player.
        --
        -- RCUI32 buttons: bar headers use SecureHandlerStateTemplate and are always
        --   IsShown=false (they act as secure controllers, not visual frames), making
        --   IsVisible() unreliable for their children. Use alpha > 0 as the proxy —
        --   but ONLY when RCUI32 is the detected primary UI (see pre-scan below).
        --
        -- All other buttons (Blizzard, ElvUI, etc.): use the full parent-chain
        --   IsVisible() check plus alpha, so hidden bars (Blizzard alpha=0 or
        --   explicitly hidden by another addon) are correctly filtered.
        local isRCUI32 = buttonName:find("^RCUI32")
        local buttonVisible
        if isRCUI32 then
            buttonVisible = rcui32IsPrimaryUI and button:GetAlpha() > 0
        else
            buttonVisible = button:IsVisible() and button:GetAlpha() > 0
        end

        if shouldFlash and buttonVisible then
            if flashColor then
                FlashButton(button, flashColor.r, flashColor.g, flashColor.b, flashColor.a)
            else
                FlashButton(button)
            end
        else
            StopFlashButton(button)
        end
    end
end

-- Main update frame
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= updateDelay then
        UpdateFlashes()
        lastUpdate = 0
    end
end)

-- API Functions

-- Register an addon to use RCSpellFlash
function lib:RegisterAddon(addonName)
    -- Ensure FlashSpells is a table
    if type(self.FlashSpells) ~= "table" then
        self.FlashSpells = {}
    end
    if type(self.RegisteredAddons) ~= "table" then
        self.RegisteredAddons = {}
    end
    
    if not self.RegisteredAddons[addonName] then
        self.RegisteredAddons[addonName] = true
        self.FlashSpells[addonName] = {
            enabled = true,
            spells = {}
        }
    end
end

-- Flash a spell by spell ID with optional action type for color
function lib:FlashSpell(addonName, spellID, r, g, b, a, actionType)
    -- Ensure FlashSpells is a table
    if type(self.FlashSpells) ~= "table" then
        self.FlashSpells = {}
    end
    
    if not self.FlashSpells[addonName] then
        self:RegisterAddon(addonName)
    end
    
    -- Determine color based on action type if no explicit color provided
    local color
    if r then
        color = {r = r, g = g, b = b, a = a or 1}
    elseif actionType and self.Config.colors[actionType] then
        local c = self.Config.colors[actionType]
        color = {r = c[1], g = c[2], b = c[3], a = c[4] or 1}
    end
    
    self.FlashSpells[addonName].spells[spellID] = {
        color = color,
        actionType = actionType
    }
end

-- Flash spell with action type (uses configured color for that type)
function lib:FlashSpellByType(addonName, spellID, actionType)
    self:FlashSpell(addonName, spellID, nil, nil, nil, nil, actionType)
end

-- Flash multiple spells with action type
function lib:FlashSpellsByType(addonName, spellIDs, actionType)
    for _, spellID in ipairs(spellIDs) do
        self:FlashSpellByType(addonName, spellID, actionType)
    end
end

-- Flash multiple spells
function lib:FlashSpells(addonName, spellIDs, r, g, b, a)
    for _, spellID in ipairs(spellIDs) do
        self:FlashSpell(addonName, spellID, r, g, b, a)
    end
end

-- Stop flashing a spell
function lib:StopFlashSpell(addonName, spellID)
    if type(self.FlashSpells) == "table" and self.FlashSpells[addonName] and self.FlashSpells[addonName].spells then
        self.FlashSpells[addonName].spells[spellID] = nil
    end
end

-- Clear all flashes for an addon
function lib:ClearFlashes(addonName)
    if type(self.FlashSpells) == "table" and self.FlashSpells[addonName] then
        self.FlashSpells[addonName].spells = {}
    end
end

-- Clear all flashes from all addons
function lib:ClearAllFlashes()
    if type(self.FlashSpells) == "table" then
        for addonName in pairs(self.FlashSpells) do
            self:ClearFlashes(addonName)
        end
    end
end

-- Enable/disable RCSpellFlash
function lib:SetEnabled(enabled)
    self.Config.enabled = enabled
    if not enabled then
        self:ClearAllFlashes()
    end
end

-- Set flash color
function lib:SetColor(r, g, b, a)
    self.Config.color = {r, g, b, a or 1}
    -- Also update primary color
    self.Config.colors.primary = {r, g, b, a or 1}
end

-- Set color for a specific action type
function lib:SetActionColor(actionType, r, g, b, a)
    if self.Config.colors[actionType] then
        self.Config.colors[actionType] = {r, g, b, a or 1}
        -- If setting primary, also update legacy color
        if actionType == "primary" then
            self.Config.color = {r, g, b, a or 1}
        end
    end
end

-- Get color for a specific action type
function lib:GetActionColor(actionType)
    if self.Config.colors[actionType] then
        local c = self.Config.colors[actionType]
        return c[1], c[2], c[3], c[4] or 1
    end
    return nil
end

-- Set flash brightness
function lib:SetBrightness(brightness)
    self.Config.brightness = brightness
end

-- Set size multiplier
function lib:SetSize(size)
    self.Config.size = size
end

-- Set combat-only mode
function lib:SetCombatOnly(inCombatOnly)
    self.Config.inCombatOnly = inCombatOnly
end

-- Legacy API support
function lib:FlashForm(addonName, spellID)
    self:FlashSpell(addonName, spellID)
end

function lib:FlashMulti(addonName, ...)
    local spellIDs = {...}
    self:FlashSpells(addonName, spellIDs)
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Initialize
        C_Timer.After(1, function()
            local buttons = GetAllActionButtons()
            for _, button in ipairs(buttons) do
                CreateFlashFrame(button)
            end
        end)
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- Button changed, update immediately
        UpdateFlashes()
    end
end)

-- Options Panel
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "RCSpellFlashOptionsPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel.name = "RCSpellFlash"
    
    -- Make it work as standalone window too
    panel:SetSize(500, 550)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:Hide()
    
    -- Backdrop for standalone mode
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
    else
        -- Fallback for MoP - create simple background
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.8)
    end
    
    -- Make draggable
    panel:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    panel:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        panel:Hide()
    end)
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RC-SpellFlash Options")
    
    -- Version text
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText("Version 2.1.2 - Retail, MoP, Cata, Wrath, TBC, Classic Era and WoW Forever")
    version:SetTextColor(0.5, 0.5, 0.5)
    
    -- Enable/Disable checkbox
    local enableCheck = RCSF_Create("CheckButton", "RCSpellFlashEnableCheck", panel, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
    enableCheck:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -20)
    _G[enableCheck:GetName() .. "Text"]:SetText("Enable RCSpellFlash")
    enableCheck:SetChecked(lib.Config.enabled)
    enableCheck:SetScript("OnClick", function(self)
        lib:SetEnabled(self:GetChecked())
    end)
    
    -- Combat only checkbox
    local combatCheck = RCSF_Create("CheckButton", "RCSpellFlashCombatCheck", panel, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
    combatCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -8)
    _G[combatCheck:GetName() .. "Text"]:SetText("Only flash during combat")
    combatCheck:SetChecked(lib.Config.inCombatOnly)
    combatCheck:SetScript("OnClick", function(self)
        lib:SetCombatOnly(self:GetChecked())
    end)
    
    -- Show outline checkbox
    local outlineCheck = RCSF_Create("CheckButton", "RCSpellFlashOutlineCheck", panel, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
    outlineCheck:SetPoint("TOPLEFT", combatCheck, "BOTTOMLEFT", 0, -8)
    _G[outlineCheck:GetName() .. "Text"]:SetText("Show glowing outline (animated)")
    outlineCheck:SetChecked(lib.Config.showOutline)
    outlineCheck:SetScript("OnClick", function(self)
        lib.Config.showOutline = self:GetChecked()
    end)
    
    -- Brightness slider
    local brightnessSlider = RCSF_Create("Slider", "RCSpellFlashBrightnessSlider", panel, { "OptionsSliderTemplate", "UISliderTemplateWithLabels" })
    brightnessSlider:SetPoint("TOPLEFT", outlineCheck, "BOTTOMLEFT", 8, -32)
    brightnessSlider:SetMinMaxValues(0.1, 2.0)
    brightnessSlider:SetValue(lib.Config.brightness)
    brightnessSlider:SetValueStep(0.1)
    brightnessSlider:SetObeyStepOnDrag(true)
    brightnessSlider:SetWidth(200)
    _G[brightnessSlider:GetName() .. "Low"]:SetText("0.1")
    _G[brightnessSlider:GetName() .. "High"]:SetText("2.0")
    _G[brightnessSlider:GetName() .. "Text"]:SetText("Brightness")
    
    local brightnessValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    brightnessValue:SetPoint("TOP", brightnessSlider, "BOTTOM", 0, 0)
    brightnessValue:SetText(string.format("%.1f", lib.Config.brightness))
    
    brightnessSlider:SetScript("OnValueChanged", function(self, value)
        lib:SetBrightness(value)
        brightnessValue:SetText(string.format("%.1f", value))
    end)
    
    -- Size slider
    local sizeSlider = RCSF_Create("Slider", "RCSpellFlashSizeSlider", panel, { "OptionsSliderTemplate", "UISliderTemplateWithLabels" })
    sizeSlider:SetPoint("TOPLEFT", brightnessSlider, "BOTTOMLEFT", 0, -40)
    sizeSlider:SetMinMaxValues(0.5, 3.0)
    sizeSlider:SetValue(lib.Config.size)
    sizeSlider:SetValueStep(0.1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(200)
    _G[sizeSlider:GetName() .. "Low"]:SetText("0.5")
    _G[sizeSlider:GetName() .. "High"]:SetText("3.0")
    _G[sizeSlider:GetName() .. "Text"]:SetText("Size")
    
    local sizeValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeValue:SetPoint("TOP", sizeSlider, "BOTTOM", 0, 0)
    sizeValue:SetText(string.format("%.1f", lib.Config.size))
    
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        lib:SetSize(value)
        sizeValue:SetText(string.format("%.1f", value))
    end)
    
    -- Action Type Color Section
    local actionTypeTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionTypeTitle:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", -8, -40)
    actionTypeTitle:SetText("Action Colors:")
    
    -- Action type buttons with color preview
    local actionTypes = {
        {key = "primary", label = "Primary", desc = "Main spell recommendation"},
        {key = "left", label = "Left", desc = "Left side recommendation"},
        {key = "above", label = "Above", desc = "Above recommendation"},
    }
    
    local actionButtons = {}
    local selectedAction = "primary"
    
    for i, actionType in ipairs(actionTypes) do
        local btn = CreateFrame("Button", "RCSpellFlashAction" .. actionType.key, panel, "UIPanelButtonTemplate")
        btn:SetSize(90, 25)
        btn:SetText(actionType.label)
        
        if i == 1 then
            btn:SetPoint("TOPLEFT", actionTypeTitle, "BOTTOMLEFT", 0, -8)
        else
            btn:SetPoint("LEFT", actionButtons[i-1], "RIGHT", 8, 0)
        end
        
        -- Color preview square
        local preview = CreateFrame("Frame", nil, btn)
        preview:SetSize(16, 16)
        preview:SetPoint("RIGHT", -4, 0)
        
        local previewTexture = preview:CreateTexture(nil, "ARTWORK")
        previewTexture:SetAllPoints()
        local color = lib.Config.colors[actionType.key]
        previewTexture:SetColorTexture(color[1], color[2], color[3])
        preview.texture = previewTexture
        
        local previewBorder = preview:CreateTexture(nil, "OVERLAY")
        previewBorder:SetAllPoints()
        previewBorder:SetColorTexture(1, 1, 1, 0.5)
        
        btn.actionType = actionType.key
        btn.preview = preview
        actionButtons[i] = btn
    end
    
    -- Color Picker Menu Button
    local colorPickerBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    colorPickerBtn:SetSize(150, 25)
    colorPickerBtn:SetPoint("TOPLEFT", actionButtons[1], "BOTTOMLEFT", 0, -12)
    colorPickerBtn:SetText("Edit Selected Color")
    
    -- Function to update all action button previews
    local function UpdateAllActionPreviews()
        for _, btn in ipairs(actionButtons) do
            local color = lib.Config.colors[btn.actionType]
            btn.preview.texture:SetColorTexture(color[1], color[2], color[3])
        end
    end
    
    -- Function to update button states (show which is selected)
    local function UpdateActionButtonStates()
        for _, btn in ipairs(actionButtons) do
            if btn.actionType == selectedAction then
                btn:SetText("> " .. btn:GetText():gsub("> ", ""))
            else
                btn:SetText(btn:GetText():gsub("> ", ""))
            end
        end
    end
    
    -- Action button click handlers
    for _, btn in ipairs(actionButtons) do
        btn:SetScript("OnClick", function(self)
            selectedAction = self.actionType
            UpdateActionButtonStates()
        end)
    end
    
    UpdateActionButtonStates()
    
    -- Create Color Picker Menu Frame
    local colorMenu = CreateFrame("Frame", "RCSpellFlashColorMenu", UIParent, "BackdropTemplate")
    colorMenu:SetSize(320, 500)
    colorMenu:SetPoint("CENTER")
    colorMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    colorMenu:SetMovable(true)
    colorMenu:EnableMouse(true)
    colorMenu:SetFrameStrata("DIALOG")
    colorMenu:Hide()
    
    -- Title
    local colorMenuTitle = colorMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    colorMenuTitle:SetPoint("TOP", 0, -16)
    
    -- Current action label
    local actionLabel = colorMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    actionLabel:SetPoint("TOP", colorMenuTitle, "BOTTOM", 0, -8)
    actionLabel:SetTextColor(0.7, 0.7, 0.7)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, colorMenu, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)
    
    -- Make draggable
    colorMenu:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    colorMenu:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    
    -- RGB Sliders
    local sliders = {}
    local sliderLabels = {"Red", "Green", "Blue"}
    
    for i, label in ipairs(sliderLabels) do
        local slider = RCSF_Create("Slider", "RCSpellFlashColorSlider" .. label, colorMenu, { "OptionsSliderTemplate", "UISliderTemplateWithLabels" })
        slider:SetPoint("TOPLEFT", 30, -80 - ((i-1) * 60))
        slider:SetMinMaxValues(0, 1)
        slider:SetValueStep(0.01)
        slider:SetObeyStepOnDrag(true)
        slider:SetWidth(240)
        _G[slider:GetName() .. "Low"]:SetText("0")
        _G[slider:GetName() .. "High"]:SetText("1")
        _G[slider:GetName() .. "Text"]:SetText(label)
        
        local valueText = colorMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)
        
        slider.valueText = valueText
        slider.index = i
        sliders[i] = slider
        
        slider:SetScript("OnValueChanged", function(self, value)
            lib.Config.colors[selectedAction][self.index] = value
            self.valueText:SetText(string.format("%.2f", value))
            -- Update the legacy color if editing primary
            if selectedAction == "primary" then
                lib.Config.color[self.index] = value
            end
            lib:SetColor(lib.Config.color[1], lib.Config.color[2], lib.Config.color[3], lib.Config.color[4])
            UpdateAllActionPreviews()
        end)
    end
    
    -- Function to update sliders when switching actions
    local function UpdateSlidersForAction()
        local color = lib.Config.colors[selectedAction]
        for i = 1, 3 do
            sliders[i]:SetValue(color[i])
            sliders[i].valueText:SetText(string.format("%.2f", color[i]))
        end
        
        -- Update title and label
        local actionNames = {primary = "Primary", left = "Left", above = "Above"}
        colorMenuTitle:SetText(actionNames[selectedAction] .. " Color")
        actionLabel:SetText("Editing " .. actionNames[selectedAction]:lower() .. " action color")
    end
    
    -- Preset Colors Section
    local presetTitle = colorMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetTitle:SetPoint("TOPLEFT", sliders[3], "BOTTOMLEFT", -10, -20)
    presetTitle:SetText("Preset Colors:")
    
    local presets = {
        {name = "Yellow", r = 1, g = 1, b = 0},
        {name = "Red", r = 1, g = 0, b = 0},
        {name = "Green", r = 0, g = 1, b = 0},
        {name = "Blue", r = 0, g = 0.5, b = 1},
        {name = "Purple", r = 0.8, g = 0, b = 1},
        {name = "Orange", r = 1, g = 0.5, b = 0},
        {name = "Cyan", r = 0, g = 1, b = 1},
        {name = "Magenta", r = 1, g = 0, b = 1},
        {name = "White", r = 1, g = 1, b = 1},
    }
    
    for i, preset in ipairs(presets) do
        local btn = CreateFrame("Button", nil, colorMenu, "UIPanelButtonTemplate")
        btn:SetSize(70, 22)
        btn:SetText(preset.name)
        
        local row = math.floor((i-1) / 3)
        local col = (i-1) % 3
        
        btn:SetPoint("TOPLEFT", presetTitle, "BOTTOMLEFT", col * 80, -8 - (row * 28))
        
        btn:SetScript("OnClick", function()
            lib.Config.colors[selectedAction][1] = preset.r
            lib.Config.colors[selectedAction][2] = preset.g
            lib.Config.colors[selectedAction][3] = preset.b
            
            -- Update legacy color if editing primary
            if selectedAction == "primary" then
                lib:SetColor(preset.r, preset.g, preset.b, lib.Config.color[4])
            end
            
            sliders[1]:SetValue(preset.r)
            sliders[2]:SetValue(preset.g)
            sliders[3]:SetValue(preset.b)
            UpdateAllActionPreviews()
        end)
    end
    
    -- Quick Scheme Buttons
    local schemeTitle = colorMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    schemeTitle:SetPoint("TOPLEFT", presetTitle, "BOTTOMLEFT", 0, -100)
    schemeTitle:SetText("Quick Color Schemes:")
    
    local schemes = {
        {name = "Classic NAG", colors = {
            primary = {0, 1, 0}, -- Green
            left = {0, 0.9, 1}, -- Cyan
            above = {1, 1, 0}, -- Yellow
        }},
        {name = "Fire & Ice", colors = {
            primary = {1, 0, 0}, -- Red
            left = {0, 0.5, 1}, -- Blue
            above = {1, 0.5, 0}, -- Orange
        }},
        {name = "RGB", colors = {
            primary = {1, 0, 0}, -- Red
            left = {0, 1, 0}, -- Green
            above = {0, 0.5, 1}, -- Blue
        }},
    }
    
    for i, scheme in ipairs(schemes) do
        local btn = CreateFrame("Button", nil, colorMenu, "UIPanelButtonTemplate")
        btn:SetSize(90, 22)
        btn:SetText(scheme.name)
        
        local row = math.floor((i-1) / 2)
        local col = (i-1) % 2
        
        btn:SetPoint("TOPLEFT", schemeTitle, "BOTTOMLEFT", col * 110, -8 - (row * 28))
        
        btn:SetScript("OnClick", function()
            for actionType, color in pairs(scheme.colors) do
                lib.Config.colors[actionType][1] = color[1]
                lib.Config.colors[actionType][2] = color[2]
                lib.Config.colors[actionType][3] = color[3]
            end
            
            -- Update primary legacy color
            lib:SetColor(scheme.colors.primary[1], scheme.colors.primary[2], scheme.colors.primary[3], lib.Config.color[4])
            
            -- Update sliders if current action was affected
            UpdateSlidersForAction()
            UpdateAllActionPreviews()
        end)
    end
    
    -- WoW Color Picker Button
    local wowPickerBtn = CreateFrame("Button", nil, colorMenu, "UIPanelButtonTemplate")
    wowPickerBtn:SetSize(240, 25)
    wowPickerBtn:SetPoint("BOTTOM", 0, 16)
    wowPickerBtn:SetText("Use WoW Color Picker")
    wowPickerBtn:SetScript("OnClick", function()
        local color = lib.Config.colors[selectedAction]
        local function OnColorSelect(restore)
            local newR, newG, newB
            if restore then
                newR, newG, newB = restore.r, restore.g, restore.b
            else
                newR, newG, newB = ColorPickerFrame:GetColorRGB()
            end
            
            lib.Config.colors[selectedAction][1] = newR
            lib.Config.colors[selectedAction][2] = newG
            lib.Config.colors[selectedAction][3] = newB
            
            if selectedAction == "primary" then
                lib:SetColor(newR, newG, newB, lib.Config.color[4])
            end
            
            sliders[1]:SetValue(newR)
            sliders[2]:SetValue(newG)
            sliders[3]:SetValue(newB)
            UpdateAllActionPreviews()
        end
        
        RCSF_OpenColorPicker(color[1], color[2], color[3], function() OnColorSelect() end, OnColorSelect)
    end)
    
    -- Open color menu button click handler
    colorPickerBtn:SetScript("OnClick", function()
        if colorMenu:IsShown() then
            colorMenu:Hide()
        else
            UpdateSlidersForAction()
            UpdateAllActionPreviews()
            colorMenu:Show()
        end
    end)
    
    -- Action buttons at bottom
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(150, 25)
    clearBtn:SetPoint("TOPLEFT", colorPickerBtn, "BOTTOMLEFT", 0, -20)
    clearBtn:SetText("Clear All Flashes")
    clearBtn:SetScript("OnClick", function()
        lib:ClearAllFlashes()
        print("RC-SpellFlash: All flashes cleared")
    end)
    
    -- Test button
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetSize(150, 25)
    testBtn:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -8)
    testBtn:SetText("Test Flash (3 sec)")
    testBtn:SetScript("OnClick", function()
        lib:Test()
    end)
    
    -- NAG Colors button
    local nagBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    nagBtn:SetSize(150, 25)
    nagBtn:SetPoint("TOPLEFT", testBtn, "BOTTOMLEFT", 0, -8)
    nagBtn:SetText("NAG Colors")
    nagBtn:SetScript("OnClick", function()
        -- Open NAG color panel
        if SlashCmdList["RCNAGBRIDGE"] then SlashCmdList["RCNAGBRIDGE"]("colors") end
    end)
    
    -- Info text
    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", nagBtn, "BOTTOMLEFT", 0, -16)
    info:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    info:SetJustifyH("LEFT")
    info:SetText("RC-SpellFlash is a library addon used by rotation helpers and other addons to show which spells to cast. Use /rcf to access these options.")
    info:SetTextColor(0.7, 0.7, 0.7)
    
    -- Store panel reference (don't register with Interface Options in MoP)
    lib.optionsPanel = panel
    return panel
end

-- Create options panel on load
local optionsFrame = CreateFrame("Frame")
optionsFrame:RegisterEvent("PLAYER_LOGIN")
optionsFrame:SetScript("OnEvent", function()
    CreateOptionsPanel()
end)

-- Slash command
SLASH_SPELLFLASH1 = "/rcf"
SLASH_SPELLFLASH2 = "/rcflash"
SlashCmdList["SPELLFLASH"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "on" or msg == "enable" then
        lib:SetEnabled(true)
        print("RC-SpellFlash: Enabled")
    elseif msg == "off" or msg == "disable" then
        lib:SetEnabled(false)
        print("RC-SpellFlash: Disabled")
    elseif msg == "clear" then
        lib:ClearAllFlashes()
        print("RC-SpellFlash: All flashes cleared")
    elseif msg == "combat" then
        lib.Config.inCombatOnly = not lib.Config.inCombatOnly
        print("RC-SpellFlash: Combat-only mode " .. (lib.Config.inCombatOnly and "enabled" or "disabled"))
    elseif msg == "config" or msg == "options" or msg == "" then
        -- Open config panel
        if not lib.optionsPanel then
            -- Panel not created yet, create it now
            CreateOptionsPanel()
        end
        
        if lib.optionsPanel then
            -- Show as standalone window
            lib.optionsPanel:Show()
        else
            print("RC-SpellFlash: Error - options panel not available")
        end
    elseif msg == "scan" then
        -- Dump all found buttons and their current action info — diagnose why spells aren't flashing
        local buttons = GetAllActionButtons()
        print("|cff00ff00RC-SpellFlash scan:|r " .. #buttons .. " buttons found")
        local nonZero = 0
        local macroCount = 0
        for _, btn in ipairs(buttons) do
            local name = btn:GetName() or "?"
            local act  = btn.action or "nil"
            if btn.action and btn.action ~= 0 then
                local aType, aId = GetActionInfo(btn.action)
                if aType == "spell" then
                    local sName = GetSpellInfo(aId) or "?"
                    print("  " .. name .. " slot=" .. act .. " → spell #" .. tostring(aId) .. " (" .. sName .. ")")
                    nonZero = nonZero + 1
                elseif aType == "macro" then
                    local macroSpell = GetMacroSpell(aId)
                    local _, macroName, macroBody = GetMacroInfo(aId)
                    local bodyPreview = macroBody and macroBody:gsub("\n", "|") or "?"
                    print(string.format("  %s slot=%s → macro #%s [%s] GetMacroSpell=%s body=[%s]",
                        name, tostring(act), tostring(aId), macroName or "?", tostring(macroSpell), bodyPreview))
                    macroCount = macroCount + 1
                end
            end
        end
        print("  " .. nonZero .. " spell buttons, " .. macroCount .. " macro buttons")
        -- Dump bar2/bar4 specifically — diagnose action=0 fix
        print("  |cffffff00bar2/bar4 diagnostic:|r")
        for barNum = 2, 4, 2 do
            for btnNum = 1, 12 do
                local btn = _G["RCUI32_bar" .. barNum .. "Button" .. btnNum]
                if btn then
                    local act = btn.action
                    local aType, aId = (act and act ~= 0) and GetActionInfo(act) or nil, nil
                    if not aType then aType, aId = GetActionInfo(act) end
                    print(string.format("    bar%dBtn%d: action=%s  GetActionInfo→%s #%s",
                        barNum, btnNum, tostring(act), tostring(aType), tostring(aId)))
                end
            end
        end
        -- Show what NAG bridge has registered to flash
        if lib.FlashSpells then
            local total = 0
            for addonName, data in pairs(lib.FlashSpells) do
                if data.spells then
                    for spellID, _ in pairs(data.spells) do
                        local sName = GetSpellInfo(spellID) or "?"
                        print("  FLASH [" .. addonName .. "] spell #" .. spellID .. " (" .. sName .. ")")
                        total = total + 1
                    end
                end
            end
            if total == 0 then
                print("  No spells registered to flash — check /nagbridge status")
            end
        end
    elseif msg == "traceflash" then
        -- Trace the exact UpdateFlashes logic for Plague Strike and Summon Gargoyle
        local TARGET_IDS = {[45462]=true, [49206]=true}
        print("|cff00ff00RC-SpellFlash traceflash:|r")
        -- Step 1: build activeSpells
        local activeSpells = {}
        if lib.FlashSpells then
            for addonName, spellData in pairs(lib.FlashSpells) do
                if type(spellData) == "table" and spellData.enabled ~= false and spellData.spells then
                    for spellID, flashData in pairs(spellData.spells) do
                        activeSpells[spellID] = flashData
                    end
                end
            end
        end
        print("  activeSpells[45462]=" .. tostring(activeSpells[45462]) .. "  activeSpells[49206]=" .. tostring(activeSpells[49206]))
        -- Step 2: scan buttons
        local buttons = GetAllActionButtons()
        for _, btn in ipairs(buttons) do
            if btn.action and btn.action ~= 0 then
                local aType, aId = GetActionInfo(btn.action)
                if aType == "macro" then
                    local msID = GetMacroSpell(aId)
                    if msID and TARGET_IDS[msID] then
                        local name = btn:GetName() or "?"
                        local match = activeSpells[msID]
                        local flash = btn.RCSpellFlashFrame
                        local btnVis = btn:IsVisible()
                        local flashVis = flash and flash:IsVisible() or false
                        local texAlpha = (flash and flash.texture) and flash.texture:GetAlpha() or 0
                        print(string.format("  %s match=%s btnVis=%s flashVis=%s texAlpha=%.2f",
                            name, tostring(match ~= nil), tostring(btnVis), tostring(flashVis), texAlpha))
                        -- Walk parent chain to find where visibility breaks
                        local f = btn
                        local depth = 0
                        while f and depth < 8 do
                            local pname = f:GetName() or "(unnamed)"
                            local shown = f:IsShown()
                            local alpha = f:GetAlpha()
                            print(string.format("    [%d] %s IsShown=%s alpha=%.2f", depth, pname, tostring(shown), alpha))
                            if not shown then print("    ^^^ HIDDEN HERE ^^^") end
                            f = f:GetParent()
                            depth = depth + 1
                        end
                    end
                end
            end
        end
    elseif msg == "flashtest" then
        -- Flash all action buttons red for 3s to confirm SpellFlash can reach them
        local buttons = GetAllActionButtons()
        local count = 0
        for _, btn in ipairs(buttons) do
            if btn.action and btn.action ~= 0 then
                FlashButton(btn, 1, 0, 0, 1)
                count = count + 1
            end
        end
        print("|cff00ff00RC-SpellFlash:|r flashing " .. count .. " buttons red for 3s")
        C_Timer.After(3, function()
            for _, btn in ipairs(buttons) do StopFlashButton(btn) end
            print("|cff00ff00RC-SpellFlash:|r flashtest done")
        end)
    else
        print("RC-SpellFlash commands:")
        print("  /rcf - Open options menu")
        print("  /rcf on - Enable RCSpellFlash")
        print("  /rcf off - Disable RCSpellFlash")
        print("  /rcf clear - Clear all flashes")
        print("  /rcf combat - Toggle combat-only mode")
        print("  /rcf scan - List all found buttons and registered NAG spells")
        print("  /rcf traceflash - Trace UpdateFlashes logic for Plague Strike / Gargoyle")
        print("  /rcf flashtest - Flash all action buttons red for 3s")
    end
end

-- Test function for debugging
function lib:Test()
    -- Flash a random spell on all buttons for testing
    local buttons = GetAllActionButtons()
    print("RC-SpellFlash Test: Found " .. #buttons .. " action buttons")
    
    for i, button in ipairs(buttons) do
        if button.action then
            FlashButton(button, 1, 0, 0, 1) -- Red flash
        end
    end
    
    C_Timer.After(3, function()
        for _, button in ipairs(buttons) do
            StopFlashButton(button)
        end
        print("RC-SpellFlash Test: Complete")
    end)
end

-- Print version info (commented out to reduce chat spam)
-- print("|cff00ff00RC-SpellFlash|r " .. MINOR_VERSION .. " loaded for MoP Classic")

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

local minimapButton = CreateFrame("Button", "RCSpellFlashMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:EnableMouse(true)
minimapButton:SetMovable(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Minimap button position (saved)
RCSpellFlashCore = RCSpellFlashCore or {}
RCSpellFlashCore.minimapPos = RCSpellFlashCore.minimapPos or 220

-- Button textures - using standard minimap button style
local buttonBg = minimapButton:CreateTexture(nil, "BACKGROUND")
buttonBg:SetSize(21, 21)
buttonBg:SetPoint("CENTER", 0, 0)
buttonBg:SetTexture("Interface\\Icons\\Spell_Holy_MindVision")
buttonBg:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Trim the icon edges

local buttonBorder = minimapButton:CreateTexture(nil, "OVERLAY")
buttonBorder:SetSize(53, 53)
buttonBorder:SetPoint("TOPLEFT", 0, 0)
buttonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local buttonHighlight = minimapButton:CreateTexture(nil, "HIGHLIGHT")
buttonHighlight:SetSize(25, 25)
buttonHighlight:SetPoint("CENTER", 0, 0)
buttonHighlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
buttonHighlight:SetBlendMode("ADD")

-- Position the button around the minimap
local function UpdateMinimapButtonPosition()
    local angle = math.rad(RCSpellFlashCore.minimapPos or 220)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        RCSpellFlashCore.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapButtonPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("RC-SpellFlash", 1, 1, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-Click: Open Menu", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-Click: Toggle Enable", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move Button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- ============================================================================
-- MAIN MENU
-- ============================================================================

local mainMenu = CreateFrame("Frame", "RCSpellFlashMainMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
mainMenu:SetSize(300, 480)
mainMenu:SetPoint("CENTER")
mainMenu:SetFrameStrata("DIALOG")
mainMenu:SetMovable(true)
mainMenu:EnableMouse(true)
mainMenu:SetClampedToScreen(true)
mainMenu:Hide()

-- Backdrop
if mainMenu.SetBackdrop then
    mainMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
end

-- Make draggable
mainMenu:SetScript("OnMouseDown", function(self) self:StartMoving() end)
mainMenu:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

-- Close button
local closeBtn = CreateFrame("Button", nil, mainMenu, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() mainMenu:Hide() end)

-- Title
local title = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -16)
title:SetText("|cffFFD700RC-SpellFlash|r")

-- Subtitle
local subtitle = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
subtitle:SetText("v8.0.6-MoP")
subtitle:SetTextColor(0.6, 0.6, 0.6)

-- Status indicator
local statusText = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
statusText:SetPoint("TOP", subtitle, "BOTTOM", 0, -8)

local function UpdateStatusText()
    if lib.Config.enabled then
        statusText:SetText("|cff00ff00● ENABLED|r")
    else
        statusText:SetText("|cffff0000● DISABLED|r")
    end
end

-- Create section header helper
local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    header:SetText("|cffFFD700" .. text .. "|r")
    
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.4, 0, 0.5)
    
    return header
end

-- Create button helper
local function CreateMenuButton(parent, text, yOffset, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(260, 26)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Create checkbox helper
local function CreateMenuCheckbox(parent, text, yOffset, getValue, setValue)
    local check = RCSF_Create("CheckButton", nil, parent, { "InterfaceOptionsCheckButtonTemplate", "UICheckButtonTemplate" })
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    check.Text:SetText(text)
    check:SetChecked(getValue())
    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
        UpdateStatusText()
    end)
    return check
end

-- ============================================================================
-- MENU CONTENT
-- ============================================================================

-- General Settings Section
CreateSectionHeader(mainMenu, "General Settings", -70)

local enableCheck = CreateMenuCheckbox(mainMenu, "Enable RC-SpellFlash", -90,
    function() return lib.Config.enabled end,
    function(v) lib:SetEnabled(v) end
)

local combatCheck = CreateMenuCheckbox(mainMenu, "Only Flash In Combat", -115,
    function() return lib.Config.inCombatOnly end,
    function(v) lib:SetCombatOnly(v) end
)

local outlineCheck = CreateMenuCheckbox(mainMenu, "Show Glowing Outline", -140,
    function() return lib.Config.showOutline end,
    function(v) lib.Config.showOutline = v end
)

-- Visual Settings Section
CreateSectionHeader(mainMenu, "Visual Settings", -175)

-- Brightness slider
local brightnessLabel = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
brightnessLabel:SetPoint("TOPLEFT", mainMenu, "TOPLEFT", 25, -195)
brightnessLabel:SetText("Brightness:")

local brightnessValue = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
brightnessValue:SetPoint("LEFT", brightnessLabel, "RIGHT", 5, 0)
brightnessValue:SetText(string.format("%.1f", lib.Config.brightness))

local brightnessSlider = RCSF_Create("Slider", "RCSpellFlashMenuBrightnessSlider", mainMenu, { "OptionsSliderTemplate", "UISliderTemplateWithLabels" })
brightnessSlider:SetPoint("TOPLEFT", brightnessLabel, "BOTTOMLEFT", 0, -8)
brightnessSlider:SetSize(240, 16)
brightnessSlider:SetMinMaxValues(0.1, 2.0)
brightnessSlider:SetValue(lib.Config.brightness)
brightnessSlider:SetValueStep(0.1)
brightnessSlider:SetObeyStepOnDrag(true)
RCSpellFlashMenuBrightnessSliderLow:SetText("0.1")
RCSpellFlashMenuBrightnessSliderHigh:SetText("2.0")
RCSpellFlashMenuBrightnessSliderText:SetText("")
brightnessSlider:SetScript("OnValueChanged", function(self, value)
    lib:SetBrightness(value)
    brightnessValue:SetText(string.format("%.1f", value))
end)

-- Color Settings Section  
CreateSectionHeader(mainMenu, "Colors", -250)

-- Color picker buttons for each action type
local colorActions = {
    {name = "Primary", key = "primary", yOffset = -275},
    {name = "Left/Right", key = "left", yOffset = -305},
    {name = "Above/AOE", key = "above", yOffset = -335},
}

-- Color preview boxes and buttons
for _, action in ipairs(colorActions) do
    -- Label
    local label = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", mainMenu, "TOPLEFT", 25, action.yOffset)
    label:SetText(action.name .. ":")
    
    -- Color preview box
    local preview = CreateFrame("Frame", nil, mainMenu)
    preview:SetSize(30, 20)
    preview:SetPoint("LEFT", label, "RIGHT", 10, 0)
    
    -- Border (black outline)
    local border = preview:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0, 0, 0, 1)
    
    -- Color fill texture
    local previewTex = preview:CreateTexture(nil, "ARTWORK")
    previewTex:SetAllPoints()
    
    -- Store reference for updating
    action.preview = preview
    action.previewTex = previewTex
    
    -- Update preview color function (stored for later use)
    action.UpdatePreview = function()
        local c = lib.Config.colors[action.key] or {1, 1, 0, 1}
        previewTex:SetColorTexture(c[1], c[2], c[3], 1)
    end
    
    -- Color picker button
    local pickBtn = CreateFrame("Button", nil, mainMenu, "UIPanelButtonTemplate")
    pickBtn:SetSize(80, 20)
    pickBtn:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    pickBtn:SetText("Pick Color")
    pickBtn:SetScript("OnClick", function()
        local c = lib.Config.colors[action.key] or {1, 1, 0, 1}
        
        local function OnColorChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            lib.Config.colors[action.key] = {r, g, b, 1}
            action.UpdatePreview()
            
            -- Update legacy primary color if editing primary
            if action.key == "primary" then
                lib:SetColor(r, g, b, 1)
            end
        end
        
        local function OnCancel(restore)
            if restore then
                lib.Config.colors[action.key] = {restore.r, restore.g, restore.b, 1}
                action.UpdatePreview()
                if action.key == "primary" then
                    lib:SetColor(restore.r, restore.g, restore.b, 1)
                end
            end
        end
        
        RCSF_OpenColorPicker(c[1], c[2], c[3], OnColorChanged, OnCancel)
    end)
end

-- Quick color scheme buttons
local schemeLabel = mainMenu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
schemeLabel:SetPoint("TOPLEFT", mainMenu, "TOPLEFT", 25, -375)
schemeLabel:SetText("Quick Schemes:")

local schemes = {
    {name = "Classic NAG", primary = {0, 1, 0}, left = {0, 0.9, 1}, above = {1, 1, 0}},
    {name = "Fire & Ice", primary = {1, 0, 0}, left = {0, 0.5, 1}, above = {1, 0.5, 0}},
    {name = "RGB", primary = {1, 0, 0}, left = {0, 1, 0}, above = {0, 0.5, 1}},
}

for i, scheme in ipairs(schemes) do
    local btn = CreateFrame("Button", nil, mainMenu, "UIPanelButtonTemplate")
    btn:SetSize(80, 22)
    btn:SetPoint("TOPLEFT", schemeLabel, "BOTTOMLEFT", (i-1) * 85, -5)
    btn:SetText(scheme.name)
    btn:SetScript("OnClick", function()
        lib.Config.colors.primary = {scheme.primary[1], scheme.primary[2], scheme.primary[3], 1}
        lib.Config.colors.left = {scheme.left[1], scheme.left[2], scheme.left[3], 1}
        lib.Config.colors.above = {scheme.above[1], scheme.above[2], scheme.above[3], 1}
        lib:SetColor(scheme.primary[1], scheme.primary[2], scheme.primary[3], 1)
        
        -- Update color previews
        for _, action in ipairs(colorActions) do
            if action.UpdatePreview then
                action.UpdatePreview()
            end
        end
        
        print("|cff00ff00RC-SpellFlash:|r Applied " .. scheme.name .. " color scheme")
    end)
end

-- Debug Section
CreateSectionHeader(mainMenu, "Debug & Testing", -430)

local testBtn = CreateMenuButton(mainMenu, "Test Flash (3 sec)", -455, function()
    lib:Test()
end)

local clearBtn = CreateMenuButton(mainMenu, "Clear All Flashes", -485, function()
    lib:ClearAllFlashes()
    print("|cff00ff00RC-SpellFlash:|r All flashes cleared")
end)

-- NAG Bridge Section (if available)
CreateSectionHeader(mainMenu, "NAG Integration", -520)

local nagStatusBtn = CreateMenuButton(mainMenu, "NAG Status", -545, function()
    if SlashCmdList["RCNAGBRIDGE"] then
        SlashCmdList["RCNAGBRIDGE"]("status")
    else
        print("|cffff0000RC-SpellFlash:|r NAG Bridge not loaded")
    end
end)

local nagDebugBtn = CreateMenuButton(mainMenu, "Toggle NAG Debug", -575, function()
    if SlashCmdList["RCNAGBRIDGE"] then
        SlashCmdList["RCNAGBRIDGE"]("debug")
    else
        print("|cffff0000RC-SpellFlash:|r NAG Bridge not loaded")
    end
end)

local nagTestBtn = CreateMenuButton(mainMenu, "Test NAG Flash", -605, function()
    if SlashCmdList["RCNAGBRIDGE"] then
        SlashCmdList["RCNAGBRIDGE"]("test")
    else
        print("|cffff0000RC-SpellFlash:|r NAG Bridge not loaded")
    end
end)

-- Resize menu to fit all content
mainMenu:SetSize(300, 660)

-- Update color previews when menu is shown
mainMenu:SetScript("OnShow", function()
    for _, action in ipairs(colorActions) do
        if action.UpdatePreview then
            action.UpdatePreview()
        end
    end
end)

-- Click handlers for minimap button
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if mainMenu:IsShown() then
            mainMenu:Hide()
        else
            UpdateStatusText()
            mainMenu:Show()
        end
    elseif button == "RightButton" then
        lib:SetEnabled(not lib.Config.enabled)
        UpdateStatusText()
        if lib.Config.enabled then
            print("|cff00ff00RC-SpellFlash:|r Enabled")
        else
            print("|cffff0000RC-SpellFlash:|r Disabled")
        end
    end
end)

-- Initialize minimap position on load
local minimapInitFrame = CreateFrame("Frame")
minimapInitFrame:RegisterEvent("PLAYER_LOGIN")
minimapInitFrame:SetScript("OnEvent", function()
    C_Timer.After(1, function()
        UpdateMinimapButtonPosition()
        UpdateStatusText()
    end)
end)

-- Add /rcfmenu command
SLASH_RCFMENU1 = "/rcfmenu"
SlashCmdList["RCFMENU"] = function()
    if mainMenu:IsShown() then
        mainMenu:Hide()
    else
        UpdateStatusText()
        mainMenu:Show()
    end
end
