-- ============================================================================
-- Journal_Base - UI/MinimapButton.lua
-- Native circular minimap launcher button, perimeter drag math, and tooltip.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local math = math
local CreateFrame = CreateFrame
local Minimap = Minimap
local UIParent = UIParent
local GameTooltip = GameTooltip
local GetCursorPosition = GetCursorPosition
local PlaySound = PlaySound
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Calculates the cursor's angle (in degrees) relative to the Minimap center.
--- @return number|nil
local function computeCursorAngleOnMinimap()
    if not Minimap or not GetCursorPosition or not UIParent then
        return nil
    end

    local mx, my = Minimap:GetCenter()
    if not mx or not my then
        return nil
    end

    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    cx = cx / scale
    cy = cy / scale

    return math.deg(math.atan2(cy - my, cx - mx))
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local MinimapButton = {
    button = nil,
}

--- Creates and initializes the circular minimap button on `Minimap`.
function MinimapButton:Init()
    if self.button or not Minimap then
        return
    end

    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(Constants.MINIMAP.SIZE, Constants.MINIMAP.SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    self:CreateVisualLayers(button)
    self:SetupScripts(button)

    self.button = button
    self:UpdatePosition()
    self:RefreshVisibility()
end

--- Builds the background circle, book icon, bronze tracking border, and hover glow.
--- @param button Button
function MinimapButton:CreateVisualLayers(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(Constants.MINIMAP.ICON_SIZE, Constants.MINIMAP.ICON_SIZE)
    bg:SetPoint("CENTER")
    bg:SetTexture(Constants.ASSETS.MINIMAP_BG)
    button.Background = bg

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Constants.MINIMAP.ICON_SIZE, Constants.MINIMAP.ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetTexture(Constants.ASSETS.FALLBACK_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(Constants.MINIMAP.BORDER_SIZE, Constants.MINIMAP.BORDER_SIZE)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    border:SetTexture(Constants.ASSETS.MINIMAP_BORDER)
    button.Border = border

    button:SetHighlightTexture(Constants.ASSETS.MINIMAP_HIGHLIGHT, "ADD")
end

--- Attaches click, drag, and tooltip handlers to `button`.
--- @param button Button
function MinimapButton:SetupScripts(button)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if PlaySound then
                PlaySound(Constants.SOUNDS.CLICK)
            end
            if _G.JournalBase then
                _G.JournalBase:OpenSettings()
            end
            return
        end

        if _G.JournalBase then
            _G.JournalBase:Toggle()
        end
    end)

    button:SetScript("OnDragStart", function(btn)
        btn:SetScript("OnUpdate", function()
            local angle = computeCursorAngleOnMinimap()
            if angle then
                ns.Database:SetMinimapAngle(angle)
                self:UpdatePosition()
            end
        end)
    end)

    button:SetScript("OnDragStop", function(btn)
        btn:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(btn)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        GameTooltip:AddLine(Constants.TITLE, 1.0, 0.82, 0.0)

        local boundKey = ns.KeybindManager:GetCurrentBindingText()
        if boundKey then
            GameTooltip:AddLine("Left-Click: Toggle Journal (" .. boundKey .. ")", 1.0, 1.0, 1.0)
        else
            GameTooltip:AddLine("Left-Click: Toggle Journal", 1.0, 1.0, 1.0)
        end

        GameTooltip:AddLine("Right-Click: Open Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: Move Icon", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

--- Positions the button along the Minimap's circular perimeter at the saved angle.
function MinimapButton:UpdatePosition()
    if not self.button or not Minimap then
        return
    end

    local angleRad = math.rad(ns.Database:GetMinimapAngle())
    local mapWidth = Minimap:GetWidth() or 140
    local mapHeight = Minimap:GetHeight() or 140
    local radius = (math.max(mapWidth, mapHeight) * 0.5) + Constants.MINIMAP.RADIUS_OFFSET

    self.button:ClearAllPoints()
    self.button:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angleRad) * radius,
        math.sin(angleRad) * radius
    )
end

--- Updates button visibility to match `Database:IsMinimapHidden()`.
function MinimapButton:RefreshVisibility()
    if not self.button then
        return
    end
    local shouldShow = not ns.Database:IsMinimapHidden()
    self.button:SetShown(shouldShow)
    if shouldShow then
        self:UpdatePosition()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MinimapButton = MinimapButton

