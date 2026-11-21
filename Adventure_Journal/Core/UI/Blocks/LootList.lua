-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/LootList.lua
-- A scrolling loot list grouped into categories, each under a gold header
-- with its count ("Equipment (4)"), then any loot sets (loot that depends on
-- circumstances, such as kill order) each under its own header. Grey equipment
-- is left out. Entries can carry where the item drops, shown as a third line.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local next = next
local unpack = unpack
local setmetatable = setmetatable
local format = string.format
local max = math.max
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local ROW_GAP = 4
local HEADER_STEP = 26     -- header height plus the gap under it
local CATEGORY_GAP = 6
local EMPTY_HEIGHT = 60

-- The list's categories in order, when the caller gives none
local DEFAULT_CATEGORIES = {
    { id = "EQUIPMENT", title = "Equipment" },
    { id = "RECIPE", title = "Recipes" },
    { id = "QUEST", title = "Quest Items & Keys" },
    { id = "COLLECTIBLE", title = "Collectibles" },
    { id = "MISC", title = "Other" },
}

local function createHeader(parent)
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetHeight(24)
    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", hdr, "TOPLEFT", 4, -2)
    title:SetTextColor(1.0, 0.82, 0.20)
    hdr.title = title
    local line = hdr:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 2, 2)
    line:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -4, 2)
    line:SetTexture(Styles.ASSETS.WHITE_8X8)
    line:SetVertexColor(0.68, 0.52, 0.20, 0.40)
    return hdr
end

local function acquire(pool, index, create)
    local item = pool[index]
    if not item then
        item = create()
        pool[index] = item
    end
    item:Show()
    return item
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local LootList = {}
LootList.__index = LootList

--- A loot list on `parent`, `width` wide. Anchor `list.scroll` (leave room on its right for the bar).
function LootList:Create(parent, width)
    local list = setmetatable({ headers = {}, rows = {}, listedItemIDs = {} }, LootList)
    list.scroll = ns.UI.ScrollFrame:Create(parent)
    list.child = CreateFrame("Frame", nil, list.scroll)
    list.child:SetSize(width, 340)
    list.scroll:SetScrollChild(list.child)
    list.emptyText = list.child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    list.emptyText:SetPoint("TOPLEFT", list.child, "TOPLEFT", 12, -20)
    list.emptyText:Hide()
    return list
end

function LootList:ShowEmpty(text)
    self.emptyText:SetText(text)
    self.emptyText:Show()
    self.child:SetHeight(EMPTY_HEIGHT)
    ns.UI.ScrollFrame:UpdateBar(self.scroll, EMPTY_HEIGHT)
end

--- The items of `entries` the list shows: kept by `filter`, grey equipment left out, each with its display name.
local function shownItems(entries, filter)
    local ItemAccess = ns.Data.ItemAccess
    local items = {}
    for _, entry in ipairs(entries) do
        local item = ItemAccess:GetItem(entry.itemID)
        if (not filter or filter(entry, item)) and not (item.category == "EQUIPMENT" and item.quality == 0) then
            item.displayName = item.name or ItemAccess:FallbackName(item.id)
            item.source = entry.source
            items[#items + 1] = item
        end
    end
    return items
end

--- Draws `entries` (`{ itemID, source }`) by category, then each of `options.sets` (`{ title, entries }`, loot that
--- depends on circumstances) under its own header. `options`: `filter(entry, item)` keeps an entry when true (no
--- filter keeps all); `emptyText` when there are no entries; `noMatchText` when the filter leaves none;
--- `categories`. Afterwards `listedItemIDs` holds every item the list covers, shown or filtered out.
function LootList:Render(entries, options)
    entries = entries or {}
    local sets = options.sets or {}
    self.listedItemIDs = {}
    for _, list in ipairs({ entries, unpack(sets) }) do
        for _, entry in ipairs(list.entries or list) do
            self.listedItemIDs[entry.itemID] = true
        end
    end
    for _, hdr in ipairs(self.headers) do hdr:Hide() end
    for _, row in ipairs(self.rows) do row:Hide() end
    if next(self.listedItemIDs) == nil then
        self:ShowEmpty(options.emptyText)
        return
    end
    self.emptyText:Hide()

    -- Sections in order: one per category with items, then one per loot set
    local sections = {}
    local categories = options.categories or DEFAULT_CATEGORIES
    local byCategory = {}
    for _, category in ipairs(categories) do
        byCategory[category.id] = { title = category.title, items = {} }
        sections[#sections + 1] = byCategory[category.id]
    end
    for _, item in ipairs(shownItems(entries, options.filter)) do
        local section = byCategory[item.category] or byCategory.MISC
        section.items[#section.items + 1] = item
    end
    for _, set in ipairs(sets) do
        sections[#sections + 1] = { title = set.title, items = shownItems(set.entries, options.filter) }
    end

    local y, headerCount, rowCount = 0, 0, 0
    for _, section in ipairs(sections) do
        if #section.items > 0 then
            headerCount = headerCount + 1
            local hdr = acquire(self.headers, headerCount, function() return createHeader(self.child) end)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.child, "TOPLEFT", 4, y)
            hdr:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -4, y)
            hdr.title:SetText(format("%s (%d)", section.title, #section.items))
            y = y - HEADER_STEP
            for _, item in ipairs(section.items) do
                rowCount = rowCount + 1
                local row = acquire(self.rows, rowCount, function() return ns.UI.Blocks.ItemRow:Create(self.child) end)
                ns.UI.Blocks.ItemRow:Set(row, item, item.category, item.source)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 4, y)
                row:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -4, y)
                y = y - (row:GetHeight() + ROW_GAP)
            end
            y = y - CATEGORY_GAP
        end
    end

    if headerCount == 0 then
        self:ShowEmpty(options.filter and options.noMatchText or options.emptyText)
        return
    end
    local height = -y + 12
    self.child:SetHeight(max(1, height))
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.LootList = LootList
