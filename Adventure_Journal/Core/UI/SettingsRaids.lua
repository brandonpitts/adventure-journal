-- ============================================================================
-- Adventure Journal - Core/UI/SettingsRaids.lua
-- The Settings panel's "Raid Module" section, under the Dungeons section:
-- grouping the raid list by tier, its sort order, and its layout.
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
local MODULE_KEY = "raids"
local GROUP_KEY = "groupRaidsByTier"

-- The raid list's dropdowns (the same shape as the Dungeons section's)
local RAID_DROPDOWNS = {
    sort = {
        moduleKey = MODULE_KEY, key = "raidListSort", default = "sizeAsc",
        options = {
            { text = "Group Size Ascending (Default)", value = "sizeAsc" },
            { text = "Group Size Descending", value = "sizeDesc" },
        },
    },
    layout = {
        moduleKey = MODULE_KEY, key = "raidListLayout", default = "four",
        options = {
            { text = "4 per Row (Default)", value = "four" },
            { text = "3 per Row", value = "three" },
            { text = "2 per Row (Large)", value = "two_large" },
            { text = "2 per Row (Compact)", value = "two_compact" },
        },
    },
}

local function showTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1.0, 0.82, 0.0)
    GameTooltip:AddLine(text, 1.0, 1.0, 1.0, true)
    GameTooltip:Show()
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local SettingsPanel = ns.UI.SettingsPanel

--- Builds the "Raid Module" section: its header and every Raids option row.
--- @param panel Frame
function SettingsPanel:CreateRaidModuleSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.IncompleteBossesLabel, "BOTTOMLEFT", -6, -26)
    sectionHeader:SetText("Raid Module")
    self.RaidModuleHeader = sectionHeader

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Options and display preferences for the Raids tab.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)

    -- Row 1: "Group Raids by Raid Tier"
    local groupLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 6, -16)
    groupLabel:SetText("Group Raids by Raid Tier")

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", groupLabel, "CENTER", 0, 0)
    checkbox:SetScript("OnEnter", function(cb)
        showTooltip(cb, "Group Raids by Raid Tier", "When enabled, the Raids tab list shows each raid tier under its "
            .. "own header (Tier 1, Tier 2, ...), with raids outside any tier last. The sort order applies within "
            .. "each tier.")
    end)
    checkbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    checkbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        ns.Settings:SetModuleSetting(MODULE_KEY, GROUP_KEY, isChecked)
    end)
    self.RaidGroupByTierCheckbox = checkbox

    -- Row 2: "Sort Raid List by"
    local sortLabel = self:CreateSettingDropdownRow(panel, RAID_DROPDOWNS.sort, "Sort Raid List by",
        "AdventureJournalRaidSortDropdown", "TOPLEFT", groupLabel, "BOTTOMLEFT", 0, -22,
        "Controls how raid cards are ordered on the Raids tab list (within each tier when grouped by tier):\n\n"
        .. "• Group Size Ascending: smallest raids first (Default).\n• Group Size Descending: largest raids first.")

    -- Row 3: "Raid List Layout"
    self.RaidSectionLastLabel = self:CreateSettingDropdownRow(panel, RAID_DROPDOWNS.layout, "Raid List Layout",
        "AdventureJournalRaidLayoutDropdown", "TOPLEFT", sortLabel, "BOTTOMLEFT", 0, -22,
        "How many raid cards sit in each row of the Raids tab list:\n\n• 2 per Row (Compact) and (Large): wide "
        .. "cards with the name, group size, and zone.\n• 3 per Row: the name, group size, and zone.\n• 4 per Row: "
        .. "small cards with the name and group size centered (Default).")
end

--- Shows the Raids section's saved values (its dropdowns refresh with the panel's others).
function SettingsPanel:RefreshRaidSection()
    if self.RaidGroupByTierCheckbox then
        self.RaidGroupByTierCheckbox:SetChecked(ns.Settings:GetModuleSetting(MODULE_KEY, GROUP_KEY) == true)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.SettingsPanel)
