-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/PageHeader.lua
-- A book's left page header: the instance's art in a medallion, its name and
-- a meta line ("Lv 17-26 • Moonbrook, Westfall"), a faction crest at the
-- right for capital-city instances, and a divider underneath. The medallion
-- and name are one button; hovering lights them.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local CREST = { Horde = "Interface\\Timer\\Horde-Logo", Alliance = "Interface\\Timer\\Alliance-Logo" }
local TITLE = { 1.0, 1.0, 1.0 }
local TITLE_HOVER = { 1.0, 0.96, 0.72 }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local PageHeader = {}
PageHeader.__index = PageHeader

--- A header on `page`. `onClick()` runs when the medallion or name is clicked; `onTooltip(owner)` fills and
--- shows the tooltip (return false to show none).
function PageHeader:Create(page, onClick, onTooltip)
    local header = setmetatable({ page = page }, PageHeader)
    local sizes = Styles.SIZES
    local medallion = Blocks.Medallion:Create(page, sizes.HEADER_MEDALLION, sizes.HEADER_RING)
    medallion:SetPoint("TOPLEFT", page, "TOPLEFT", 2, sizes.HEADER_MEDALLION_Y)
    header.medallion = medallion

    local button = CreateFrame("Button", nil, page)
    button:SetPoint("TOPLEFT", medallion, "TOPLEFT", -6, 6)
    button:SetPoint("BOTTOMLEFT", medallion, "BOTTOMLEFT", -6, -6)
    button:SetPoint("RIGHT", page, "RIGHT", -50, 0)
    button:SetFrameLevel(medallion:GetFrameLevel() + 10)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function()
        PlaySound(Styles.SOUNDS.CLICK)
        onClick()
    end)
    button:SetScript("OnEnter", function(b)
        Blocks.Medallion:SetHighlighted(medallion, true)
        header.title:SetTextColor(TITLE_HOVER[1], TITLE_HOVER[2], TITLE_HOVER[3])
        onTooltip(b)
    end)
    button:SetScript("OnLeave", function()
        Blocks.Medallion:SetHighlighted(medallion, false)
        header.title:SetTextColor(TITLE[1], TITLE[2], TITLE[3])
        GameTooltip:Hide()
    end)

    local crest = page:CreateTexture(nil, "OVERLAY", nil, 6)
    crest:SetSize(38, 38)
    crest:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    crest:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    crest:Hide()
    header.crest = crest

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    header.title = title

    local meta = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    meta:SetJustifyH("LEFT")
    meta:SetTextColor(0.82, 0.72, 0.52)
    header.meta = meta
    header:AnchorText(page, -12)

    local divider = Blocks.Divider:CreateHorizontal(page, 4)
    divider:SetPoint("TOPLEFT", page, "TOPLEFT", 6, sizes.HEADER_DIVIDER_Y)
    divider:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, sizes.HEADER_DIVIDER_Y)
    header.divider = divider
    return header
end

--- Title and meta run from the medallion to `right` (the page, or the crest).
function PageHeader:AnchorText(right, x)
    local point = right == self.page and "RIGHT" or "LEFT"
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", self.medallion, "TOPRIGHT", 10, -Styles.SIZES.HEADER_TITLE_DROP)
    self.title:SetPoint("RIGHT", right, point, x, 0)
    self.meta:ClearAllPoints()
    self.meta:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -3)
    self.meta:SetPoint("RIGHT", right, point, x, 0)
end

--- Shows `instance` (an instance view): its art, `title`, `metaText` under it, and `faction`'s crest ("Horde" or
--- "Alliance"; nil for none).
function PageHeader:Set(instance, title, metaText, faction)
    Blocks.Medallion:SetInstanceArt(self.medallion, instance)
    Blocks.Medallion:SyncRing(self.medallion)
    self.title:SetText(title)
    local crest = CREST[faction]
    if crest then
        self.crest:SetTexture(crest)
        self.crest:SetTexCoord(0, 1, 0, 1)
        self.crest:SetSize(38, 38)
        self.crest:ClearAllPoints()
        self.crest:SetPoint("RIGHT", self.page, "RIGHT", -12, 0)
        self.crest:SetPoint("CENTER", self.medallion, "CENTER", 0, 0)
        self.crest:Show()
        self:AnchorText(self.crest, -8)
    else
        self.crest:Hide()
        self:AnchorText(self.page, -12)
    end
    self.meta:SetText(metaText)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.PageHeader = PageHeader
