-- ============================================================================
-- Journal_Dungeons - Data/Items/ItemsManager.lua
-- Item querying, category classification, client cache resolution,
-- player usability checking, and AtlasLoot version validation.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

local ipairs = ipairs
local pairs = pairs
local type = type
local select = select
local UnitClass = UnitClass
local C_AddOns = C_AddOns
local GetAddOnMetadata = GetAddOnMetadata

-- ----------------------------------------------------------------------------
-- 1. Class Proficiencies
-- ----------------------------------------------------------------------------
local _, playerClass = UnitClass("player")

local CLASS_ARMOR = {
    WARRIOR = { Cloth = true, Leather = true, Mail = true, Plate = true, Shield = true, Shields = true },
    PALADIN = { Cloth = true, Leather = true, Mail = true, Plate = true, Shield = true, Shields = true },
    HUNTER  = { Cloth = true, Leather = true, Mail = true },
    SHAMAN  = { Cloth = true, Leather = true, Mail = true, Shield = true, Shields = true },
    ROGUE   = { Cloth = true, Leather = true },
    DRUID   = { Cloth = true, Leather = true },
    MAGE    = { Cloth = true },
    PRIEST  = { Cloth = true },
    WARLOCK = { Cloth = true },
}

local CLASS_WEAPONS = {
    WARRIOR = {
        ["Daggers"] = true, ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true,
        ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true,
        ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["Polearms"] = true, ["Staves"] = true, ["Fist Weapons"] = true,
        ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true, ["Thrown"] = true,
    },
    PALADIN = {
        ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true,
        ["Polearms"] = true,
    },
    HUNTER = {
        ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true,
        ["Daggers"] = true, ["One-Handed Swords"] = true, ["Two-Handed Swords"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true,
        ["Polearms"] = true, ["Staves"] = true, ["Fist Weapons"] = true, ["Thrown"] = true,
    },
    ROGUE = {
        ["Daggers"] = true, ["One-Handed Swords"] = true, ["One-Handed Maces"] = true,
        ["Fist Weapons"] = true, ["Bows"] = true, ["Crossbows"] = true, ["Guns"] = true, ["Thrown"] = true,
    },
    PRIEST = {
        ["Daggers"] = true, ["One-Handed Maces"] = true, ["Staves"] = true, ["Wands"] = true,
    },
    SHAMAN = {
        ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["One-Handed Axes"] = true, ["Two-Handed Axes"] = true,
        ["Daggers"] = true, ["Staves"] = true, ["Fist Weapons"] = true,
    },
    MAGE = {
        ["Daggers"] = true, ["One-Handed Swords"] = true, ["Staves"] = true, ["Wands"] = true,
    },
    WARLOCK = {
        ["Daggers"] = true, ["One-Handed Swords"] = true, ["Staves"] = true, ["Wands"] = true,
    },
    DRUID = {
        ["One-Handed Maces"] = true, ["Two-Handed Maces"] = true,
        ["Staves"] = true, ["Daggers"] = true, ["Polearms"] = true, ["Fist Weapons"] = true,
    },
}

-- ----------------------------------------------------------------------------
-- 2. ItemsManager Module
-- ----------------------------------------------------------------------------
local ItemsManager = {}
ns.ItemsManager = ItemsManager

local updateListeners = {}
local itemNameCache = {}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:SetScript("OnEvent", function(self, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" and itemID then
        local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(itemID)) or (_G.GetItemInfo and _G.GetItemInfo(itemID))
        if name and name ~= "" then
            itemNameCache[itemID] = name
        end
        for listener in pairs(updateListeners) do
            listener(itemID, success)
        end
    end
end)

function ItemsManager:RegisterUpdateListener(func)
    if type(func) == "function" then
        updateListeners[func] = true
    end
end

function ItemsManager:UnregisterUpdateListener(func)
    if func then
        updateListeners[func] = nil
    end
end

--- Returns the cached or loaded item name for itemID.
--- Requests load from server if not yet available in client memory.
--- @param itemID number
--- @return string|nil
function ItemsManager:GetItemName(itemID)
    if not itemID then return nil end
    local cached = itemNameCache[itemID]
    if cached then
        return cached
    end
    local name = nil
    if C_Item and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(itemID)
    end
    if not name and _G.GetItemInfo then
        name = _G.GetItemInfo(itemID)
    end
    if name and name ~= "" then
        itemNameCache[itemID] = name
        return name
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return nil
end

--- Checks if a boss or any of its encounter loot drops match a case-insensitive query string.
--- @param dungeonID string
--- @param boss table
--- @param query string (already lowercased and trimmed)
--- @return boolean isMatch
--- @return table|nil matchedItem
function ItemsManager:BossMatchesQuery(dungeonID, boss, query)
    if not boss or not query or query == "" then
        return true, nil
    end

    -- 1. Check Boss Name
    if boss.name and strfind(strlower(boss.name), query, 1, true) then
        return true, nil
    end

    -- 2. Check Boss Encounter Drops
    local bossKey = (boss.isZone or boss.isTrash) and "Zone Drops" or boss.name
    local dropIDs = self:GetEncounterDrops(dungeonID, bossKey)
    if dropIDs then
        for _, itemID in ipairs(dropIDs) do
            local itemName = self:GetItemName(itemID)
            if itemName and strfind(strlower(itemName), query, 1, true) then
                return true, { id = itemID, name = itemName }
            end
        end
    end

    return false, nil
end

-- ----------------------------------------------------------------------------
-- 3. Item Usability
-- ----------------------------------------------------------------------------
function ItemsManager:IsItemUsableByPlayer(itemType, itemSubType, itemEquipLoc)
    if not playerClass then
        _, playerClass = UnitClass("player")
    end

    if itemType == "Armor" then
        if itemEquipLoc == "INVTYPE_CLOAK" or itemEquipLoc == "INVTYPE_TRINKET"
            or itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_NECK"
            or itemEquipLoc == "INVTYPE_BODY" or itemEquipLoc == "INVTYPE_TABARD" then
            return true
        end

        if itemEquipLoc == "INVTYPE_SHIELD" then
            local allowed = CLASS_ARMOR[playerClass]
            return allowed and (allowed["Shield"] or allowed["Shields"]) or false
        end

        local allowed = CLASS_ARMOR[playerClass]
        if not allowed then return true end
        return allowed[itemSubType] or false
    elseif itemType == "Weapon" then
        local allowed = CLASS_WEAPONS[playerClass]
        if not allowed then return true end
        return allowed[itemSubType] or false
    end

    return true
end

local TRADESKILL_SUBTYPES = {
    ["Leatherworking"] = true,
    ["Tailoring"] = true,
    ["Engineering"] = true,
    ["Blacksmithing"] = true,
    ["Cooking"] = true,
    ["Alchemy"] = true,
    ["First Aid"] = true,
    ["Enchanting"] = true,
    ["Fishing"] = true,
    ["Jewelcrafting"] = true,
    ["Mining"] = true,
    ["Poisons"] = true,
}

-- ----------------------------------------------------------------------------
-- 4. Category Classification
-- ----------------------------------------------------------------------------
function ItemsManager:GetItemCategory(itemType, itemSubType, itemEquipLoc, itemID, itemName, classID, subclassID)
    -- 0. EXPLICIT ITEM CATEGORY OVERRIDES
    if itemID and ns.ItemCategoryOverrides and ns.ItemCategoryOverrides[itemID] then
        return ns.ItemCategoryOverrides[itemID]
    end

    if (not classID or not itemEquipLoc or itemEquipLoc == "") and itemID then
        local getInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
        if getInstant then
            local _, iType, iSubType, iEquip, _, cID, scID = getInstant(itemID)
            if not classID then classID = cID end
            if not subclassID then subclassID = scID end
            if not itemEquipLoc or itemEquipLoc == "" then itemEquipLoc = iEquip end
            if not itemType or itemType == "" then itemType = iType end
            if not itemSubType or itemSubType == "" then itemSubType = iSubType end
        end
    end

    -- 1. TRADESKILL RECIPES (Patterns, Plans, Schematics, Formulas, Recipes, First Aid Manuals)
    -- Evaluated first so items with recipe prefixes or tradeskill crafting categories are NEVER misclassified as equipment or other.
    if itemName then
        if itemName:find("^Pattern:") or itemName:find("^Plans:") or itemName:find("^Recipe:")
            or itemName:find("^Schematic:") or itemName:find("^Formula:") or itemName:find("^Manual:") then
            return "RECIPE"
        end
    end
    if (itemType == "Recipe" or classID == 9) and (itemSubType ~= "Book") then
        return "RECIPE"
    end
    if itemSubType and TRADESKILL_SUBTYPES[itemSubType] and (not itemEquipLoc or itemEquipLoc == "" or itemEquipLoc == "INVTYPE_NON_EQUIP") then
        return "RECIPE"
    end

    -- 2. CLASS SKILL BOOKS (Non-equippable spell-teaching books)
    -- In WoW, all class skill books (tomes, grimoires, tablets, codices) have itemSubType == "Book".
    -- Equipment and trinkets never have itemSubType == "Book" (trinkets/offhands have "Miscellaneous").
    if itemSubType == "Book" or itemType == "Book" then
        return "MISC"
    end

    -- 3. QUEST ITEMS & KEYS
    -- Evaluated before equippable gear so quest medallions, rods, keys, tablets, and cards are NEVER misclassified as equipment.
    if classID == 12 or classID == 13 or itemType == "Quest" or itemType == "Key" or itemSubType == "Key" or itemSubType == "Quest" then
        return "QUEST"
    end
    if itemName then
        if itemName:find("^Ace of ") or itemName:find("^Two of ") or itemName:find("^Three of ")
            or itemName:find("^Four of ") or itemName:find("^Five of ") or itemName:find("^Six of ")
            or itemName:find("^Seven of ") or itemName:find("^Eight of ")
            or itemName:find("^Nine of ") or itemName:find("^Ten of ")
            or (itemName:find(" Deck$") and not itemName:find("^Darkmoon Card:")) then
            return "QUEST"
        end
        if itemName:find(" Tablet$") or itemName:find("^Tablet of ") or itemName:find(" Key$") or itemName:find("Troll Temper") then
            return "QUEST"
        end
    end

    -- 4. TABARDS AND BAGS
    if itemEquipLoc == "INVTYPE_TABARD" or itemSubType == "Tabard" or itemType == "Tabard" then
        return "COLLECTIBLE"
    end
    if itemEquipLoc == "INVTYPE_BAG" or itemType == "Container" or classID == 1 then
        return "MISC"
    end

    -- 5. EQUIPPABLE GEAR (Weapons, Armor, Off-hands, Shields, Jewelry, Trinkets, Relics)
    local isEquippable = itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP"
    if isEquippable then
        return "EQUIPMENT"
    end
    if classID == 2 or classID == 4 or itemType == "Armor" or itemType == "Weapon" then
        return "EQUIPMENT"
    end

    -- 6. Non-equippable Tomes / Grimoires / Codexes fallback
    if (not isEquippable) and itemName then
        if itemName:find("^Tome of ") or itemName:find("^Grimoire of ") or itemName:find("^Codex: ") then
            return "MISC"
        end
    end

    -- 7. COLLECTIBLES (Pets, Mounts)
    if classID == 17 or (classID == 15 and (subclassID == 2 or subclassID == 5))
        or itemSubType == "Companion Pets" or itemSubType == "Mount" then
        return "COLLECTIBLE"
    end

    -- 8. EVERYTHING ELSE (Reagents, consumables, junk)
    return "MISC"
end

-- ----------------------------------------------------------------------------
-- 5. Drops Retrieval
-- ----------------------------------------------------------------------------
function ItemsManager:GetEncounterDrops(dungeonID, bossIdentifier)
    local drops = {}
    local seen = {}

    local function addDrops(list)
        if not list then return end
        for _, id in ipairs(list) do
            if not seen[id] then
                seen[id] = true
                drops[#drops + 1] = id
            end
        end
    end

    local function querySource(tbl)
        if not tbl or not tbl[dungeonID] then return end
        local dData = tbl[dungeonID]
        addDrops(dData[bossIdentifier])

        if bossIdentifier == "Crown Chemical Co." or bossIdentifier == "Apothecary Hummel" or bossIdentifier == "Apothecary Hummel <Crown Chemical Co.>" then
            addDrops(dData["Crown Chemical Co."])
            addDrops(dData["Apothecary Hummel <Crown Chemical Co.>"])
            addDrops(dData["Apothecary Hummel"])
        elseif bossIdentifier == "Zone Drops" or bossIdentifier == "trash" then
            addDrops(dData["Zone Drops"])
            addDrops(dData["trash"])
            addDrops(dData["Trash"])
            addDrops(dData["Dark Coffer"])
            addDrops(dData["Plans"])
            addDrops(dData["Baelog's Chest"])
            addDrops(dData["Conspicuous Urn"])
            addDrops(dData["Shadowforge Cache"])
            addDrops(dData["Tablet of Will"])
            addDrops(dData["Darkstone Tablet"])
            addDrops(dData["Knot Thimblejack's Cache"])
            addDrops(dData["Plunder"])
        elseif bossIdentifier == "The Grim Guzzler" or bossIdentifier == "Guzzler" then
            addDrops(dData["The Grim Guzzler"])
            addDrops(dData["Guzzler"])
        elseif bossIdentifier == "The Seven" or bossIdentifier == "Chest of The Seven" then
            addDrops(dData["The Seven"])
            addDrops(dData["Chest of The Seven"])
        elseif bossIdentifier == "The Lost Dwarves" then
            addDrops(dData["Baelog"])
            addDrops(dData["Olaf"])
        elseif bossIdentifier == "Dreamscythe & Weaver" then
            addDrops(dData["Dreamscythe"])
            addDrops(dData["Weaver"])
        elseif bossIdentifier == "Morphaz & Hazzas" then
            addDrops(dData["Morphaz"])
            addDrops(dData["Hazzas"])
        elseif bossIdentifier == "Marduk Blackpool & Vectus" then
            addDrops(dData["Marduk Blackpool"])
            addDrops(dData["Vectus"])
        elseif bossIdentifier == "Jarien and Sothos" or bossIdentifier == "Sothos and Jarien" or bossIdentifier == "Sothos and Jarien's Heirlooms" then
            addDrops(dData["Jarien and Sothos"])
            addDrops(dData["Sothos and Jarien's Heirlooms"])
            addDrops(dData["Sothos and Jarien"])
        end
    end

    if ns.ItemsOverrides then querySource(ns.ItemsOverrides) end
    if ns.ItemsClassic then querySource(ns.ItemsClassic) end

    return drops
end

-- ----------------------------------------------------------------------------
-- 6. AtlasLoot Version Detection
-- ----------------------------------------------------------------------------
function ItemsManager:GetAtlasLootVersionStatus()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local installedVersion = getMeta and (getMeta("AtlasLootClassic", "Version") or getMeta("AtlasLoot", "Version"))
    local syncedVersion = ns.ItemsMetadata and ns.ItemsMetadata.syncedVersion or "v1.3.8"

    local isInstalled = installedVersion ~= nil and installedVersion ~= ""
    local isMismatch = isInstalled and (installedVersion ~= syncedVersion)

    return {
        isInstalled = isInstalled,
        installedVersion = installedVersion,
        syncedVersion = syncedVersion,
        isMismatch = isMismatch,
    }
end
