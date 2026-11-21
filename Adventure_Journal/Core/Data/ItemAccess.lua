-- ============================================================================
-- Adventure Journal - Core/Data/ItemAccess.lua
-- The data feed for item rows (loot lists and quest rewards): the client's
-- item info where loaded, our ItemStore for category, type label, usability
-- and a stored name while the client's isn't loaded yet.
--   item view: id, name (nil until known), link, quality, texture, category, typeLabel, equipLoc,
--              itemType, itemSubType, classID, subclassID
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local tostring = tostring

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
---@return any
local function itemStore()
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore.ItemStore or nil
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local ItemAccess = {}

--- One item's view. `name` is the client's name, else our stored name, else nil.
--- @param itemID number
function ItemAccess:GetItem(itemID)
    local name, link, quality, _, _, itemType, itemSubType, _, equipLoc, texture, _, classID, subclassID =
        ns.GameApi:GetItemInfo(itemID)
    local items = itemStore()
    if (not name or name == "") and items then
        local stored = items:GetLabel(itemID)
        name = (stored and stored ~= "") and stored or nil
    end
    return {
        id = itemID, name = name, link = link, quality = quality, texture = texture,
        itemType = itemType, itemSubType = itemSubType, equipLoc = equipLoc, classID = classID, subclassID = subclassID,
        category = (items and items:GetCategory(itemID)) or "MISC",
        typeLabel = items and items:GetTypeLabel(itemID),
    }
end

--- Whether the player can use the item (true when the DataStore is off).
function ItemAccess:IsUsableByPlayer(itemID)
    local items = itemStore()
    return not items or items:IsUsableByPlayer(itemID)
end

--- "Item #id": the name shown for an item nothing has named yet.
function ItemAccess:FallbackName(itemID)
    return "Item #" .. tostring(itemID)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data = ns.Data or {}
ns.Data.ItemAccess = ItemAccess
