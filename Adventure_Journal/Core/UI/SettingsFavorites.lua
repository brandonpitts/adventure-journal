-- ============================================================================
-- Adventure Journal - Core/UI/SettingsFavorites.lua
-- The Dungeons section's "Show Favorites Section" row: whether favorite
-- dungeons and wings (right-click a card) are also copied into a Favorites
-- section at the top of the Dungeons tab list. Their stars show either way.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Constants = ns.Constants
local SETTING_KEY = "showFavoritesSection"
local TITLE = "Show Favorites Section"
local DESCRIPTION = "Right-click a dungeon on the Dungeons tab list, or a wing on a dungeon's wing page, to add it to "
    .. "your Favorites (right-click again to remove it). Favorites show a gold star in their top-right corner.\n\n"
    .. "When enabled, favorite dungeons and wings are also listed under their own Favorites header at the top of the "
    .. "Dungeons tab list, above every dungeon. When disabled, only the stars mark them."

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local SettingsPanel = ns.UI.SettingsPanel

--- Adds the "Show Favorites Section" row under `anchor` (a row label). Returns its label.
--- @param panel Frame
--- @param anchor FontString
--- @return FontString
function SettingsPanel:CreateFavoritesRow(panel, anchor)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -22)
    label:SetText(TITLE)

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)
    checkbox:SetScript("OnEnter", function(cb)
        GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
        GameTooltip:AddLine(TITLE, 1.0, 0.82, 0.0)
        GameTooltip:AddLine(DESCRIPTION, 1.0, 1.0, 1.0, true)
        GameTooltip:Show()
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    checkbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        ns.Settings:SetDungeonSetting(SETTING_KEY, isChecked)
    end)
    self.FavoritesSectionCheckbox = checkbox
    return label
end

--- Shows the row's saved value.
function SettingsPanel:RefreshFavoritesRow()
    if self.FavoritesSectionCheckbox then
        self.FavoritesSectionCheckbox:SetChecked(ns.Settings:GetDungeonSetting(SETTING_KEY) == true)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.SettingsPanel)
