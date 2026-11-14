-- ============================================================================
-- Utility_MapIcons - UI/MapPinProvider.lua
-- World Map canvas provider, pin frame pooling, responsive zoom scaling,
-- and Retail-style 3-line interactive tooltips.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UnitLevel = UnitLevel
local PlaySound = PlaySound
local math = math
local ipairs = ipairs
local pairs = pairs
local table = table

local Constants = ns.MapIconsConstants

-- ----------------------------------------------------------------------------
-- 2. MapPinProvider Definition
-- ----------------------------------------------------------------------------
local MapPinProvider = {
    activePins = {},
    pinPool = {},
    hoveredPin = nil,
    clickCatcher = nil,
    isInitialized = false,
}

-- ----------------------------------------------------------------------------
-- 3. Pin Creation & Layout
-- ----------------------------------------------------------------------------

--- Creates a single map pin frame parented to WorldMapFrame's canvas.
local function createPinFrame()
    local canvas = _G.WorldMapFrame and _G.WorldMapFrame.GetCanvas and _G.WorldMapFrame:GetCanvas()
    if not canvas then
        return nil
    end

    local pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(Constants.PIN.SIZE, Constants.PIN.SIZE)
    pin:SetFrameStrata(Constants.PIN.FRAME_STRATA)
    pin:SetFrameLevel(Constants.PIN.FRAME_LEVEL)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Base Atlas Texture (Dungeon blue swirl)
    local texture = pin:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetAtlas(Constants.ATLAS.DUNGEON)
    pin.Texture = texture

    -- Hover Highlight Texture (re-enabled for world map pins)
    local highlight = pin:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetAtlas(Constants.ATLAS.DUNGEON)
    highlight:SetBlendMode("ADD")
    highlight:Hide()
    pin.Highlight = highlight

    pin:SetScript("OnMouseDown", function(self, button)
        self.downX, self.downY = _G.GetCursorPosition()
    end)

    pin:SetScript("OnClick", function(self, button)
        if self.downX and self.downY then
            local upX, upY = _G.GetCursorPosition()
            local distance = math.abs(upX - self.downX) + math.abs(upY - self.downY)
            self.downX, self.downY = nil, nil
            -- If cursor moved more than 8 pixels, user was panning the map, not clicking the pin
            if distance > 8 then
                return
            end
        end

        if PlaySound then
            PlaySound(1115) -- IG_MAINMENU_OPTION
        end

        if self.pinData and self.pinData.dungeonID and ns.OpenDungeon then
            ns.OpenDungeon(self.pinData.dungeonID)
        end
    end)

    pin:SetScript("OnEnter", function(self)
        if self.Highlight then
            self.Highlight:Show()
        end
        MapPinProvider:ShowTooltip(self)
    end)

    pin:SetScript("OnLeave", function(self)
        if self.Highlight then
            self.Highlight:Hide()
        end
        MapPinProvider:HideTooltip()
    end)

    return pin
end

--- Positions a pin on the WorldMap canvas according to its percentage coordinates.
local function positionPin(pin)
    local canvas = _G.WorldMapFrame and _G.WorldMapFrame.GetCanvas and _G.WorldMapFrame:GetCanvas()
    if not canvas or not pin.pinData then
        return
    end

    local scale = pin:GetScale() or 1
    if scale <= 0 then scale = 1 end

    local x = (pin.pinData.x or 50) / 100
    local y = (pin.pinData.y or 50) / 100

    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", (canvas:GetWidth() * x) / scale, -(canvas:GetHeight() * y) / scale)
end

--- Rescales all active pins inversely to the canvas zoom level so icons remain crisp.
function MapPinProvider:UpdatePinScale()
    if not _G.WorldMapFrame or not _G.WorldMapFrame.GetCanvasScale then
        return
    end

    local canvasScale = _G.WorldMapFrame:GetCanvasScale() or 1
    if canvasScale <= 0 then canvasScale = 1 end

    local desiredScale = Constants.PIN.POI_SCALE / canvasScale

    for _, pin in ipairs(self.activePins) do
        pin:SetScale(desiredScale)
        positionPin(pin)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Tooltip Management (Retail 3-Line Specification)
-- ----------------------------------------------------------------------------

function MapPinProvider:ShowTooltip(pin)
    local data = pin and pin.pinData
    if not data or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    -- Line 1: Instance Name (White)
    local r1, g1, b1 = unpack(Constants.TOOLTIP.TITLE_COLOR)
    GameTooltip:AddLine(data.name or "Dungeon", r1, g1, b1)

    -- Line 2: Instance Type (Gold "Dungeon" or "Raid")
    local r2, g2, b2 = unpack(Constants.TOOLTIP.SUBTITLE_COLOR)
    GameTooltip:AddLine(data.kind or "Dungeon", r2, g2, b2)

    -- Line 3: Action Prompt (Bright Green "<Click to open Adventure Journal>")
    local r3, g3, b3 = unpack(Constants.TOOLTIP.ACTION_COLOR)
    GameTooltip:AddLine(Constants.TOOLTIP.ACTION_TEXT, r3, g3, b3)

    GameTooltip:Show()
end

function MapPinProvider:HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 5. Pin Lifecycle & Data Filtering
-- ----------------------------------------------------------------------------

--- Checks whether a dungeon entrance should be shown given player level and user settings.
local function shouldShowPin(pinData)
    if not pinData then
        return false
    end

    -- Verify Map Icons utility module is enabled
    if ns.IsPluginEnabled and not ns.IsPluginEnabled("map_icons") then
        return false
    end

    -- Raid Pins Handling (Groundwork - default disabled while under construction)
    if pinData.kind == "Raid" then
        if ns.IsPluginEnabled and not ns.IsPluginEnabled("raids") then
            return false
        end
        local raidSetting = "disabled"
        if ns.Database and ns.Database.GetMapIconsSetting then
            raidSetting = ns.Database:GetMapIconsSetting("worldMapRaidIcons", "disabled")
        end
        if raidSetting == "disabled" then
            return false
        end
        if raidSetting == "always" then
            return true
        end
        local playerLevel = UnitLevel("player") or 1
        local minLevel = pinData.minLevel or 50
        local maxLevel = pinData.maxLevel or 60
        if raidSetting == "min_level" then
            return playerLevel >= minLevel
        elseif raidSetting == "bracket" then
            return playerLevel >= minLevel and playerLevel <= maxLevel
        end
        return true
    end

    -- Verify supporting content module is active (dungeons)
    if ns.IsPluginEnabled and not ns.IsPluginEnabled("dungeons") then
        return false
    end

    local setting = "min_level"
    if ns.Database and ns.Database.GetMapIconsSetting then
        setting = ns.Database:GetMapIconsSetting("worldMapDungeonIcons", "min_level")
    elseif ns.Database and ns.Database.GetDungeonSetting then
        setting = ns.Database:GetDungeonSetting("worldMapDungeonIcons", "min_level")
    end

    if setting == "disabled" then
        return false
    end

    if setting == "always" then
        return true
    end

    local playerLevel = UnitLevel("player") or 1
    local minLevel = pinData.minLevel or 1
    local maxLevel = pinData.maxLevel or 60

    if pinData.dungeonID and ns.Data and ns.Data.DungeonsData and ns.Data.DungeonsData.GetByID then
        local d = ns.Data.DungeonsData:GetByID(pinData.dungeonID)
        if d then
            minLevel = d.minLevel or minLevel
            maxLevel = d.maxLevel or maxLevel
        end
    end

    if setting == "min_level" then
        return playerLevel >= minLevel
    elseif setting == "bracket" then
        return playerLevel >= minLevel and playerLevel <= maxLevel
    end

    return true
end

--- Recycles all active pins back into the frame pool.
function MapPinProvider:ReleaseAllPins()
    self:HideTooltip()
    for i = #self.activePins, 1, -1 do
        local pin = self.activePins[i]
        if pin.Highlight then
            pin.Highlight:Hide()
        end
        pin:Hide()
        pin:ClearAllPoints()
        pin.pinData = nil
        self.pinPool[#self.pinPool + 1] = pin
        self.activePins[i] = nil
    end
end

--- Acquires a pin frame and populates it for the current map.
function MapPinProvider:AddPin(pinData)
    local pin = table.remove(self.pinPool) or createPinFrame()
    if not pin then
        return
    end

    pin.pinData = pinData

    local canvasScale = (_G.WorldMapFrame and _G.WorldMapFrame.GetCanvasScale and _G.WorldMapFrame:GetCanvasScale()) or 1
    if canvasScale <= 0 then canvasScale = 1 end

    pin:SetScale(Constants.PIN.POI_SCALE / canvasScale)

    local atlas = (pinData.kind == "Raid") and Constants.ATLAS.RAID or Constants.ATLAS.DUNGEON
    pin.Texture:SetAtlas(atlas)
    if pin.Highlight then
        pin.Highlight:SetAtlas(atlas)
        pin.Highlight:Hide()
    end

    positionPin(pin)
    pin:Show()

    self.activePins[#self.activePins + 1] = pin
end

--- Refreshes pins on the current World Map based on active mapID and level filter.
function MapPinProvider:Refresh()
    if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then
        return
    end

    self:ReleaseAllPins()

    local mapID = _G.WorldMapFrame.mapID or (_G.WorldMapFrame.GetMapID and _G.WorldMapFrame:GetMapID())
    if not mapID or not ns.EntranceCoordinates then
        return
    end

    local candidates = ns.EntranceCoordinates[mapID]
    if not candidates then
        return
    end

    for _, pinData in ipairs(candidates) do
        if shouldShowPin(pinData) then
            self:AddPin(pinData)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 6. Initialization & Blizzard Map Hooks
-- ----------------------------------------------------------------------------

function MapPinProvider:Init()
    if self.isInitialized then
        return
    end
    if not _G.WorldMapFrame then
        return
    end

    self.isInitialized = true

    -- Hook canvas scale and size changes to keep pins crisp and accurately positioned
    if _G.WorldMapFrame.HookScript then
        _G.WorldMapFrame:HookScript("OnSizeChanged", function()
            MapPinProvider:UpdatePinScale()
        end)
    end

    if _G.hooksecurefunc then
        _G.hooksecurefunc(_G.WorldMapFrame, "OnCanvasScaleChanged", function()
            MapPinProvider:UpdatePinScale()
        end)
        _G.hooksecurefunc(_G.WorldMapFrame, "OnMapChanged", function()
            MapPinProvider:Refresh()
        end)
    end

    -- Refresh whenever the world map is toggled open
    _G.WorldMapFrame:HookScript("OnShow", function()
        MapPinProvider:Refresh()
    end)
    _G.WorldMapFrame:HookScript("OnHide", function()
        MapPinProvider:ReleaseAllPins()
    end)
end

-- ----------------------------------------------------------------------------
-- 7. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.MapPinProvider = MapPinProvider
