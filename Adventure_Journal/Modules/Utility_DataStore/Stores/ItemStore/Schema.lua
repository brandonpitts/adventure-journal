-- ============================================================================
-- Utility_DataStore - Stores/ItemStore/Schema.lua
--
-- An item is anything that can sit in your bags or be equipped: weapons, armor,
-- boss loot, quest items, recipes, keys. Keyed by the game's item ID. Holds only
-- our labels and our own layer; names, quality, stats and icons come from the
-- client. Things you click in the world but never carry are fixtures
-- (FixtureStore).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local select = select
local C_Item = C_Item
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers
-- ----------------------------------------------------------------------------
-- GetItemInfoInstant answers without loading: id, type, subtype, equipLoc, icon, classID, subclassID
local function instant(index)
    return function(itemID)
        return (select(index, C_Item.GetItemInfoInstant(itemID)))
    end
end

-- GetItemInfo answers once the item is loaded: name, link, quality, itemLevel, requiredLevel, ...
local function loaded(index)
    return function(itemID)
        return (select(index, C_Item.GetItemInfo(itemID)))
    end
end

-- ----------------------------------------------------------------------------
-- 3. Store Definition
-- ----------------------------------------------------------------------------
DataStore.StoreBase:New({
    name = "ItemStore",
    kind = "Item",
    liveName = "item",
    existsKind = "item",
    fields = {
        stats   = { type = "table", list = true, comment = "Stat keys generated from the client's tooltip (never hand-written)." },
        traits  = { type = "table", list = true, comment = "Effect and binding keys from the tooltip (on-use, bop, ...), generated like stats." },
        classes = { type = "table", list = true, comment = "Class restriction printed on the item, generated from the tooltip." },
        icon          = { type = "number", live = true, comment = "Icon file ID (instant)." },
        equipLoc      = { type = "string", live = true, comment = "Equip slot token (instant)." },
        classID       = { type = "number", live = true, comment = "Item class ID (instant); 12 is quest, 9 is recipe." },
        subclassID    = { type = "number", live = true, comment = "Item subclass ID (instant)." },
        quality       = { type = "number", live = true, comment = "Quality (after load)." },
        itemLevel     = { type = "number", live = true, comment = "Item level (after load)." },
        requiredLevel = { type = "number", live = true, comment = "Required level (after load)." },
    },
    live = {
        icon = instant(5),
        equipLoc = instant(4),
        classID = instant(6),
        subclassID = instant(7),
        quality = loaded(3),
        itemLevel = loaded(4),
        requiredLevel = loaded(5),
    },
})
