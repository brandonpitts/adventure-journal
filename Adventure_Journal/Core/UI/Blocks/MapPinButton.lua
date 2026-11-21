-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/MapPinButton.lua
-- The map pin beside a quest's source and turn-in: with a map point, the
-- game's untracked waypoint pin that places and tracks a waypoint and opens
-- the world map; without one, the tracked pin greyed out, with a reason.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local format = string.format
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local SetCursor = SetCursor
local ResetCursor = ResetCursor
local SOUNDKIT = SOUNDKIT

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local SIZE = 36
local PIN_AVAILABLE = "Waypoint-MapPin-Untracked"
local PIN_UNAVAILABLE = "Waypoint-MapPin-Tracked"

local function setOffset(btn, x, y)
    btn.icon:SetPoint("CENTER", btn, "CENTER", x, y)
    btn.hl:SetPoint("CENTER", btn, "CENTER", x, y)
end

local function onEnter(btn)
    if btn.isAvailable then
        SetCursor("Interface\\CURSOR\\Point")
        btn.icon:SetVertexColor(1.0, 0.95, 0.60, 1.0)
    end
    local text = btn.text
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if btn.isAvailable then
        GameTooltip:AddLine(text.title, 1.0, 0.82, 0.0)
        if btn.targetLabel and btn.targetLabel ~= "" then
            GameTooltip:AddLine(btn.targetLabel, 1.0, 1.0, 1.0, true)
        end
        GameTooltip:AddLine(btn.coordText, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(text.hint, 0.2, 0.8, 1.0, true)
    else
        GameTooltip:AddLine(text.unavailable, 0.75, 0.75, 0.75)
        if btn.unavailableReason and btn.unavailableReason ~= "" then
            GameTooltip:AddLine(btn.unavailableReason, 0.6, 0.6, 0.6, true)
        end
    end
    GameTooltip:Show()
end

local function onLeave(btn)
    ResetCursor()
    if btn.isAvailable then
        btn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    end
    GameTooltip:Hide()
end

local function onClick(btn)
    if not btn.isAvailable then
        return
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    ns.GameApi:SetWaypoint(btn.mapID, btn.mapX, btn.mapY)
    ns.GameApi:OpenWorldMap(btn.mapID)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local MapPinButton = {}

--- A map pin button on `parent`, drawn above the parent's other contents.
--- @return Button
function MapPinButton:Create(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameLevel(parent:GetFrameLevel() + 25)
    btn:SetHitRectInsets(-4, -4, -4, -4)
    btn:EnableMouse(true)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(SIZE, SIZE)
    btn.icon = icon
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(SIZE, SIZE)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.95, 0.80, 0.35, 0.35)
    btn.hl = hl
    setOffset(btn, 0, 0)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnMouseDown", function(b)
        if b.isAvailable then
            setOffset(b, 1, -1)
        end
    end)
    btn:SetScript("OnMouseUp", function(b)
        setOffset(b, 0, 0)
    end)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", onLeave)
    btn:SetScript("OnClick", onClick)
    return btn
end

--- Points the pin at `mapData` (`{ mapID, x, y, label, targetName }`, x and y 0-1 or 0-100), or greys it out
--- with `unavailableReason` when there is no usable map point. `text` is the tooltip's wording:
--- `{ title, coords (a format for x and y), hint, unavailable, target (the label when there's none) }`.
function MapPinButton:Configure(btn, mapData, fallbackLabel, unavailableReason, text)
    local hasCoords = mapData ~= nil and mapData.mapID ~= nil and mapData.x ~= nil and mapData.y ~= nil
    btn.isAvailable = hasCoords
    btn.unavailableReason = unavailableReason
    btn.text = text
    if hasCoords then
        btn.icon:SetAtlas(PIN_AVAILABLE)
        btn.hl:SetAtlas(PIN_AVAILABLE)
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        btn.hl:SetBlendMode("ADD")
        btn.hl:SetVertexColor(0.95, 0.80, 0.35, 0.35)
        btn.hl:SetAlpha(1.0)
        btn.mapID, btn.mapX, btn.mapY = mapData.mapID, mapData.x, mapData.y
        btn.targetLabel = mapData.label or mapData.targetName or fallbackLabel or text.target
        local nx = (mapData.x > 1) and (mapData.x / 100) or mapData.x
        local ny = (mapData.y > 1) and (mapData.y / 100) or mapData.y
        btn.coordText = format(text.coords, nx * 100, ny * 100)
    else
        btn.icon:SetAtlas(PIN_UNAVAILABLE)
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(0.40, 0.40, 0.40, 0.50)
        btn.hl:SetAlpha(0.0)
        btn.mapID, btn.mapX, btn.mapY, btn.targetLabel, btn.coordText = nil, nil, nil, nil, nil
    end
    btn:EnableMouse(true)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.MapPinButton = MapPinButton
