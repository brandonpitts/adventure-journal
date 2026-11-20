-- ============================================================================
-- Utility_DataStore - Stores/ItemStore/ItemCalls.lua
-- ItemStore's own calls: an item's loot-page category, whether the player can
-- use it, its slot and type names, where it can be obtained, and the tags the
-- search index works out for it. Everything
-- here reads the client's instant item data plus Rules.lua; nothing is stored.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local type = type
local select = select
local C_Item = C_Item
local UnitClass = UnitClass
local DataStore = ns.DataStore
local ItemStore = DataStore.ItemStore
local Rules = ItemStore.Rules

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local CLASS_WEAPON, CLASS_ARMOR, CLASS_RECIPE = 2, 4, 9

-- Stored tags that force a loot-page category (see GetCategory)
local CATEGORY_TAGS = { quest = "QUEST", recipe = "RECIPE", collectible = "COLLECTIBLE", miscellaneous = "MISC" }

-- Armor slots every class can wear
local ANY_CLASS_SLOTS = {
    INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true, INVTYPE_CLOAK = true,
    INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_HOLDABLE = true,
}

-- Tags from the item's class alone: classID -> tags, or classID -> subclassID -> tags
local CLASS_TAGS = {
    [0] = { "consumable" }, [1] = { "container" }, [5] = { "reagent" }, [12] = { "quest" }, [13] = { "key" },
    [15] = { [2] = { "pet" }, [5] = { "mount" } },
}

-- equipLoc, classID, subclassID from the client's instant data (no load needed)
local function instant(itemID)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return equipLoc, classID, subclassID
end

local function typeRule(classID, subclassID)
    if classID == CLASS_WEAPON then
        return Rules.weaponTypes[subclassID]
    elseif classID == CLASS_ARMOR then
        return Rules.armorTypes[subclassID]
    elseif classID == CLASS_RECIPE then
        return Rules.recipeTypes[subclassID]
    end
end

local function addAll(list, tags)
    for _, tag in ipairs(tags or {}) do
        list[#list + 1] = tag
    end
end

-- "Obtained from": itemID -> list of { kind, key }. Encounters (loot and loot sets), instances (instance-wide
-- drops) and quests (rewards); vendors and crafting slot in later the same way.
local function buildObtainedFrom()
    local index = {}
    local function add(itemID, kind, key)
        local list = index[itemID]
        if not list then
            list = {}
            index[itemID] = list
        end
        list[#list + 1] = { kind = kind, key = key }
    end
    local encounters, instances, quests = DataStore.EncounterStore, DataStore.InstanceStore, DataStore.QuestStore
    for key in encounters:EachKey() do
        local record = encounters:Get(key)
        for _, itemID in ipairs(record.itemIDs or {}) do
            add(itemID, "encounter", key)
        end
        for _, set in ipairs(record.lootSets or {}) do
            for _, itemID in ipairs(set.itemIDs or {}) do
                add(itemID, "encounter", key)
            end
        end
    end
    for key in instances:EachKey() do
        for _, itemID in ipairs(instances:Get(key).itemIDs or {}) do
            add(itemID, "instance", key)
        end
    end
    for key in quests:EachKey() do
        for _, itemID in ipairs(quests:Get(key).rewardItemIDs or {}) do
            add(itemID, "quest", key)
        end
    end
    return index
end

-- "dungeon" or "raid" for an instance or wing key
local function instanceKind(instanceKey)
    local instances = DataStore.InstanceStore
    local record = instances:Get(instanceKey)
    if record and record.instanceID then
        record = instances:Get(record.instanceID)
    end
    return record and record.type
end

-- Tags the search index works out for one item (section 7, computed tags)
local function computedTags(itemID)
    local tags = {}
    local equipLoc, classID, subclassID = instant(itemID)
    local slot = equipLoc and Rules.equipLocs[equipLoc]
    addAll(tags, slot and slot.tags)
    local rule = typeRule(classID, subclassID)
    addAll(tags, rule and rule.tags)
    local byClass = CLASS_TAGS[classID]
    if byClass and type(byClass[1]) == "string" then
        addAll(tags, byClass)
    elseif byClass then
        addAll(tags, byClass[subclassID])
    end
    local record = ItemStore:Get(itemID)
    addAll(tags, record and record.stats)
    addAll(tags, record and record.traits)
    for _, source in ipairs(ItemStore:GetObtainedFrom(itemID)) do
        if source.kind == "quest" then
            tags[#tags + 1] = "quest-reward"
        else
            tags[#tags + 1] = "loot"
            local encounter = source.kind == "encounter" and DataStore.EncounterStore:Get(source.key)
            tags[#tags + 1] = encounter and "boss-drop" or "zone-drop"
            if encounter and encounter.holidayID then
                tags[#tags + 1] = "event"
            end
            local kind = instanceKind(encounter and (encounter.wingKey or encounter.instanceID) or source.key)
            if kind then
                tags[#tags + 1] = kind
            end
        end
    end
    return tags
end

-- ----------------------------------------------------------------------------
-- 3. ItemStore Calls
-- ----------------------------------------------------------------------------

--- Every way to obtain an item: a list of { kind = "encounter" | "instance" | "quest", key }.
function ItemStore:GetObtainedFrom(itemID)
    if not DataStore:IsEnabled() then
        return {}
    end
    local index = DataStore.Indexes:Get("item.obtainedFrom")
    return index and index[itemID] or {}
end

--- The loot-page category: "EQUIPMENT", "RECIPE", "QUEST", "COLLECTIBLE" or "MISC".
--- A stored category tag wins; otherwise the item's class decides.
function ItemStore:GetCategory(itemID)
    local record = self:Get(itemID)
    for _, tag in ipairs(record and record.tags or {}) do
        if CATEGORY_TAGS[tag] then
            return CATEGORY_TAGS[tag]
        end
    end
    local equipLoc, classID, subclassID = instant(itemID)
    if classID == CLASS_RECIPE then
        return subclassID == 0 and "MISC" or "RECIPE"
    elseif classID == 12 or classID == 13 then
        return "QUEST"
    elseif equipLoc == "INVTYPE_TABARD" then
        return "COLLECTIBLE"
    elseif equipLoc == "INVTYPE_BAG" or classID == 1 then
        return "MISC"
    elseif (equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP")
        or classID == CLASS_WEAPON or classID == CLASS_ARMOR then
        return "EQUIPMENT"
    elseif classID == 17 or (classID == 15 and (subclassID == 2 or subclassID == 5)) then
        return "COLLECTIBLE"
    end
    return "MISC"
end

--- Whether the player's class can use the item's armor or weapon type. True for everything else.
function ItemStore:IsUsableByPlayer(itemID)
    local equipLoc, classID, subclassID = instant(itemID)
    local _, playerClass = UnitClass("player")
    if classID == CLASS_ARMOR then
        if ANY_CLASS_SLOTS[equipLoc] or subclassID == 0 then
            return true
        end
        local allowed = Rules.classArmor[playerClass]
        return not allowed or allowed[subclassID] == true
    elseif classID == CLASS_WEAPON then
        local allowed = Rules.classWeapons[playerClass]
        return not allowed or allowed[subclassID] == true
    end
    return true
end

--- The item's type name ("Two-Handed Sword", "Plate", "Tailoring"), or its short form; nil when it has none.
function ItemStore:GetTypeLabel(itemID, useShort)
    local _, classID, subclassID = instant(itemID)
    local rule = typeRule(classID, subclassID)
    return rule and ((useShort and rule.short) or rule.label)
end

--- The item's slot name ("Head", "One-Hand"), or its short form; nil when it isn't worn.
function ItemStore:GetSlotLabel(itemID, useShort)
    local equipLoc = instant(itemID)
    local rule = equipLoc and Rules.equipLocs[equipLoc]
    return rule and ((useShort and rule.short) or rule.label)
end

--- The item's required level once the client has loaded it; nil before that.
function ItemStore:GetRequiredLevel(itemID)
    return (select(5, C_Item.GetItemInfo(itemID)))
end

-- ----------------------------------------------------------------------------
-- 4. Registration
-- ----------------------------------------------------------------------------
DataStore.Indexes:Define("item.obtainedFrom", buildObtainedFrom)
DataStore.TagRegistry:AddTagSource("ItemStore", computedTags)
