-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/ItemRow.lua
-- One loot row: the item's icon in a quality-colored frame, its name in its
-- quality color, a type line on the left (slot, recipe kind, ...) and on the
-- right (armor or weapon type, red when the player can't use it), and an
-- optional third line naming where it drops. Hover shows the item tooltip;
-- Shift-click links it, Ctrl-click previews it.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local GameApi = ns.GameApi
local SUBTEXT = { 0.75, 0.70, 0.60 }
local UNUSABLE = { 0.90, 0.20, 0.20 }
-- Slots any class wears: no armor or weapon type shown
local UNIVERSAL_SLOTS = {
    INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true, INVTYPE_CLOAK = true,
    INVTYPE_HOLDABLE = true, INVTYPE_BODY = true, INVTYPE_TABARD = true,
}
-- Client subtype words that say nothing about the item
local VAGUE = { Miscellaneous = true, Junk = true }

-- Also the row's UpdateTooltip, which the tooltip calls while hovered, so Shift-compare follows Shift mid-hover
local function showTooltip(row)
    if row.itemID then
        GameApi:ShowItemTooltip(row, row.itemID, row.itemLink)
    end
end

local function frameEdge(row, icon, a1, a2, x1, y1, x2, y2, horizontal)
    local tex = row:CreateTexture(nil, "OVERLAY")
    if horizontal then tex:SetHeight(1) else tex:SetWidth(1) end
    tex:SetPoint(a1, icon, a1, x1, y1)
    tex:SetPoint(a2, icon, a2, x2, y2)
    tex:SetTexture(Styles.ASSETS.WHITE_8X8)
    return tex
end

--- The left and right type lines for an item in `category`.
local function typeLines(item, category)
    if category == "EQUIPMENT" then
        local slot = (item.equipLoc and _G[item.equipLoc]) or item.itemType or ""
        if item.equipLoc == "INVTYPE_HOLDABLE" then
            slot = "Off-hand"
        end
        local subType = item.typeLabel or ""
        if UNIVERSAL_SLOTS[item.equipLoc] or VAGUE[subType] then
            return slot, ""
        end
        return slot, subType, not ns.Data.ItemAccess:IsUsableByPlayer(item.id)
    elseif category == "RECIPE" then
        return item.itemSubType or "Recipe", ""
    elseif category == "QUEST" then
        local sub = item.itemSubType or "Quest"
        if VAGUE[sub] or sub == "Armor" or sub == "" then
            sub = "Quest"
        end
        return sub, ""
    elseif category == "COLLECTIBLE" then
        local label = (item.equipLoc == "INVTYPE_TABARD" and _G.INVTYPE_TABARD) or item.itemSubType or "Collectible"
        return VAGUE[label] and "Collectible" or label, ""
    end
    local label = item.itemSubType or item.itemType or "Other"
    return VAGUE[label] and "Other" or label, ""
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local ItemRow = {}

--- A loot row on `parent`; anchor its left and right edges.
--- @return Button
function ItemRow:Create(parent)
    local white = Styles.ASSETS.WHITE_8X8
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(36)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(white)
    bg:SetVertexColor(0.08, 0.07, 0.06, 0.35)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(white)
    hl:SetVertexColor(1.0, 0.90, 0.65, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    row.edges = {
        frameEdge(row, icon, "TOPLEFT", "TOPRIGHT", -1, 1, 1, 1, true),
        frameEdge(row, icon, "BOTTOMLEFT", "BOTTOMRIGHT", -1, -1, 1, -1, true),
        frameEdge(row, icon, "TOPLEFT", "BOTTOMLEFT", -1, 0, -1, 0, false),
        frameEdge(row, icon, "TOPRIGHT", "BOTTOMRIGHT", 1, 0, 1, 0, false),
    }

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local subLeft = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subLeft:SetHeight(12)
    subLeft:SetJustifyH("LEFT")
    subLeft:SetWordWrap(false)
    subLeft:SetMaxLines(1)
    subLeft:SetTextColor(SUBTEXT[1], SUBTEXT[2], SUBTEXT[3])
    row.subLeftText = subLeft

    local subRight = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subRight:SetHeight(12)
    subRight:SetJustifyH("RIGHT")
    subRight:SetWordWrap(false)
    subRight:SetMaxLines(1)
    row.subRightText = subRight

    local source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    source:SetJustifyH("LEFT")
    source:SetWordWrap(false)
    source:SetTextColor(0.92, 0.78, 0.42)
    source:Hide()
    row.sourceText = source

    row.UpdateTooltip = showTooltip
    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(r)
        GameApi:HandleItemClick(r.itemLink)
    end)
    return row
end

--- Fills a row with `item` (an ItemAccess view plus `displayName`) of loot `category`, and `source` (where it
--- drops) as a third line when given.
function ItemRow:Set(row, item, category, source)
    row.itemID = item.id
    row.itemLink = item.link or ("item:" .. item.id)
    local hasSource = source ~= nil and source ~= ""
    row:SetHeight(hasSource and 48 or 36)

    row.icon:ClearAllPoints()
    if hasSource then
        row.icon:SetSize(34, 34)
        row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    else
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    end
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon:SetTexture(item.texture or Styles.ASSETS.MISSING_ICON)

    local r, g, b = GameApi:GetQualityColor(item.quality or 1)
    for _, edge in ipairs(row.edges) do
        edge:SetVertexColor(r, g, b, 1.0)
    end

    row.nameText:ClearAllPoints()
    row.subLeftText:ClearAllPoints()
    row.subRightText:ClearAllPoints()
    if hasSource then
        row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -3)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.subLeftText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -18)
        row.subRightText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -18)
        row.sourceText:ClearAllPoints()
        row.sourceText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -32)
        row.sourceText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.sourceText:SetText(source)
        row.sourceText:Show()
    else
        row.nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.subLeftText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
        row.subRightText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 3)
        row.sourceText:Hide()
    end

    row.nameText:SetText(item.displayName)
    row.nameText:SetTextColor(r, g, b)

    local left, right, unusable = typeLines(item, category)
    row.subLeftText:SetText(left)
    row.subRightText:SetText(right)
    local c = unusable and UNUSABLE or SUBTEXT
    row.subRightText:SetTextColor(c[1], c[2], c[3])
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.ItemRow = ItemRow
