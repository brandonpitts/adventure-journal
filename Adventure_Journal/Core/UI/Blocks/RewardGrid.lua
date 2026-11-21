-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/RewardGrid.lua
-- A quest's reward items in two columns under a caption the caller gives
-- (e.g. "Choose one of the following rewards:"). Each reward shows its icon
-- in a quality-colored frame, its name and its type; one the client hasn't
-- loaded yet shows the caller's loading text. Hover and modified clicks act
-- as on loot rows.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local floor = math.floor
local ceil = math.ceil
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local GameApi = ns.GameApi
local COLUMN_GAP = 8
local ROW_HEIGHT = 36
local ROW_GAP = 4

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

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local RewardGrid = {}

--- One reward button on `parent`.
--- @return Button
function RewardGrid:CreateButton(parent)
    local white = Styles.ASSETS.WHITE_8X8
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(white)
    bg:SetVertexColor(0.08, 0.07, 0.06, 0.55)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(white)
    hl:SetVertexColor(1.0, 0.90, 0.65, 0.10)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    row.edges = {
        frameEdge(row, icon, "TOPLEFT", "TOPRIGHT", -1, 1, 1, 1, true),
        frameEdge(row, icon, "BOTTOMLEFT", "BOTTOMRIGHT", -1, -1, 1, -1, true),
        frameEdge(row, icon, "TOPLEFT", "BOTTOMLEFT", -1, 0, -1, 0, false),
        frameEdge(row, icon, "TOPRIGHT", "BOTTOMRIGHT", 1, 0, 1, 0, false),
    }

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
    nameText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    nameText:SetHeight(14)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetMaxLines(1)
    row.nameText = nameText

    local subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
    subText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    subText:SetHeight(12)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    subText:SetMaxLines(1)
    row.subText = subText

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

local function setEdges(row, r, g, b, a)
    for _, edge in ipairs(row.edges) do
        edge:SetVertexColor(r, g, b, a)
    end
end

--- Fills a reward button with `itemID`; `loadingText` shows while the client loads it.
function RewardGrid:SetButton(row, itemID, loadingText)
    local item = ns.Data.ItemAccess:GetItem(itemID)
    row.itemID = itemID
    row.itemLink = nil
    row.icon:SetTexture(item.texture or Styles.ASSETS.MISSING_ICON)
    if item.name then
        row.itemLink = item.link
        local r, g, b = GameApi:GetQualityColor(item.quality or 1)
        row.nameText:SetText(item.name)
        row.nameText:SetTextColor(r, g, b)
        setEdges(row, r, g, b, 0.85)
        row.subText:SetText(item.typeLabel or "")
    else
        row.nameText:SetText(ns.Data.ItemAccess:FallbackName(itemID))
        row.nameText:SetTextColor(0.8, 0.8, 0.8)
        setEdges(row, 0.4, 0.4, 0.4, 0.7)
        row.subText:SetText(loadingText)
    end
end

--- Lays out `itemIDs` as a two-column grid at x, y on `parent`, `width` wide, under `captionText`.
--- `writer` provides `Text(font, r, g, b, wrap, width)` and `Reward()` (pooled widgets). Returns the y below.
function RewardGrid:Layout(writer, parent, itemIDs, x, y, width, captionText, loadingText)
    if not itemIDs or #itemIDs == 0 then
        return y
    end
    local caption = writer:Text("GameFontDisableSmall", 0.75, 0.70, 0.60, false, width)
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    caption:SetText(captionText)
    local top = y - 16
    local itemWidth = floor((width - COLUMN_GAP) / 2)
    for i, itemID in ipairs(itemIDs) do
        local column = (i - 1) % 2
        local rowIndex = floor((i - 1) / 2)
        local row = writer:Reward()
        row:SetSize(itemWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", x + column * (itemWidth + COLUMN_GAP),
            top - rowIndex * (ROW_HEIGHT + ROW_GAP))
        self:SetButton(row, itemID, loadingText)
    end
    return top - ceil(#itemIDs / 2) * (ROW_HEIGHT + ROW_GAP) - 8
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.RewardGrid = RewardGrid
