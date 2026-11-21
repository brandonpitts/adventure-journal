-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/EncounterDetail.lua
-- The top of an encounter's page: its medallion, name and level tag, its
-- description below whichever of the two reaches lower, and a divider under
-- the description. The caller places the loot list under the divider.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local max = math.max
local setmetatable = setmetatable

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local MEDALLION_BOTTOM = 6 + 44 -- the medallion's offset plus its height with ring
local LORE = { 0.92, 0.86, 0.72 }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local EncounterDetail = {}
EncounterDetail.__index = EncounterDetail

--- An encounter header on `page`; the description is `width` wide.
function EncounterDetail:Create(page, width)
    local detail = setmetatable({ page = page }, EncounterDetail)
    local medallion = Blocks.Medallion:Create(page, 40, 55)
    medallion:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -6)
    detail.medallion = medallion

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", medallion, "TOPRIGHT", 10, -2)
    title:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetSpacing(2)
    detail.title = title

    local level = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    level:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    level:SetJustifyH("LEFT")
    level:SetWordWrap(false)
    detail.level = level

    local desc = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -66)
    desc:SetWidth(width)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetSpacing(3)
    desc:SetTextColor(LORE[1], LORE[2], LORE[3])
    detail.desc = desc

    detail.divider = Blocks.Divider:CreateHorizontal(page, 4)
    return detail
end

--- Shows `boss` (an encounter view) of `instance`, with `description` under its name (nil leaves it blank) and
--- `icon` in the medallion when it has no portrait.
function EncounterDetail:Show(boss, instance, useDifficultyColor, description, icon)
    Blocks.Medallion:SetEncounterPortrait(self.medallion, boss, icon)
    Blocks.Medallion:SyncRing(self.medallion)
    Blocks.Medallion:SetClassification(self.medallion, boss)
    self.medallion:Show()

    self.title:SetText(boss.name or "Boss")
    self.title:Show()
    Blocks.LevelTag:ApplyEncounter(self.level, boss, useDifficultyColor)
    self.level:Show()

    local textBottom = 2 + self.title:GetStringHeight() + 3 + self.level:GetStringHeight()
    local headerHeight = max(MEDALLION_BOTTOM, textBottom)
    self.desc:ClearAllPoints()
    self.desc:SetPoint("TOPLEFT", self.page, "TOPLEFT", 10, -(headerHeight + 12))
    self.desc:SetText(description or "")
    ns.UI.WindowBackground:ColorBodyText(self.desc, LORE[1], LORE[2], LORE[3])
    self.desc:Show()

    local dividerY = -(headerHeight + 12 + max(28, self.desc:GetStringHeight()) + 12)
    self.divider:ClearAllPoints()
    self.divider:SetPoint("TOPLEFT", self.page, "TOPLEFT", 6, dividerY)
    self.divider:SetPoint("TOPRIGHT", self.page, "TOPRIGHT", -24, dividerY)
    self.divider:SetHeight(4)
    self.divider:Show()
end

--- Hides the header.
function EncounterDetail:Hide()
    self.medallion:Hide()
    self.title:SetText("")
    self.title:Hide()
    self.level:Hide()
    self.desc:Hide()
    self.divider:Hide()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.EncounterDetail = EncounterDetail
