-- ============================================================================
-- Journal_Dungeons - Data/Items/ItemsManager.lua
-- Lightweight module facade delegating item lookups, multi-tag + reqLevel
-- queries, category classification, and player usability to Core/ItemDatabase.lua.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ItemDB = parent.ItemDatabase

-- Backwards-compatible namespace aliases pointing to Core/Data/Sources/
ns.ItemCategoryOverrides = parent.ItemCategoryOverrides
ns.ItemsClassic = parent.DropsDungeons
ns.ItemsOverrides = parent.SourcesOverrides

-- ----------------------------------------------------------------------------
-- 2. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local ItemsManager = {}

function ItemsManager:RegisterUpdateListener(func)
    return ItemDB and ItemDB:RegisterUpdateListener(func)
end

function ItemsManager:UnregisterUpdateListener(func)
    return ItemDB and ItemDB:UnregisterUpdateListener(func)
end

function ItemsManager:GetItem(itemID)
    return ItemDB and ItemDB:GetItem(itemID)
end

function ItemsManager:GetItemName(itemID)
    return ItemDB and ItemDB:GetItemName(itemID)
end

function ItemsManager:ParseQuery(query)
    return ItemDB and ItemDB:ParseQuery(query)
end

function ItemsManager:ItemMatchesQuery(itemID, query)
    if not ItemDB then return false, nil end
    local parsed = type(query) == "table" and query or ItemDB:ParseQuery(query)
    return ItemDB:ItemMatchesParsedQuery(itemID, parsed)
end

function ItemsManager:BossMatchesQuery(dungeonID, boss, query)
    return ItemDB and ItemDB:BossMatchesQuery(dungeonID, boss, query)
end

function ItemsManager:IsItemUsableByPlayer(itemType, itemSubType, itemEquipLoc)
    if not ItemDB then return true end
    return ItemDB:IsItemUsableByPlayer(itemType, itemSubType, itemEquipLoc)
end

function ItemsManager:GetItemCategory(itemType, itemSubType, itemEquipLoc, itemID, itemName, classID, subclassID)
    if not ItemDB then return "MISC" end
    return ItemDB:GetItemCategory(itemType, itemSubType, itemEquipLoc, itemID, itemName, classID, subclassID)
end

function ItemsManager:GetEncounterDrops(dungeonID, bossIdentifier)
    if not ItemDB then return {} end
    return ItemDB:GetEncounterDrops(dungeonID, bossIdentifier)
end

-- ----------------------------------------------------------------------------
-- 3. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.ItemsManager = ItemsManager
