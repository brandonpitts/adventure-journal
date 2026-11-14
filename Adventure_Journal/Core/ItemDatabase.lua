-- ============================================================================
-- Journal_Base - Core/ItemDatabase.lua
-- Central item storage engine, load-time bi-directional source & tag indexer,
-- multi-tag + reqLevel query evaluator, and live client cache/tooltip hydrator.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local CreateFrame = CreateFrame
local UnitClass = UnitClass
local C_Item = C_Item
local C_AddOns = C_AddOns
local GetAddOnMetadata = GetAddOnMetadata
local strfind = string.find
local strlower = string.lower
local strmatch = string.match
local gmatch = string.gmatch
local gsub = string.gsub

--Dimensions that require tooltip scanning if not yet statically tagged
local TOOLTIP_DEPENDENT_DIMENSIONS = {
    PRIMARY_STATS = true,
    PHYSICAL_DEFENSE = true,
    CASTER_STATS = true,
    ELEMENTS = true,
    MECHANICS = true,
}

-- Player class proficiency tables
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
-- 2. Internal State & Index Structures
-- ----------------------------------------------------------------------------
local ItemDatabase = {
    isInitialized = false,
    Catalog = {},       -- [itemID] = record
    ItemSources = {},   -- [itemID] = { { kind="dungeon", instanceID=..., encounter=... }, ... }
    TagIndex = {},      -- [canonicalTag] = { [itemID] = true }
}

local updateListeners = {}
local requestedLoadIDs = {}
local parsedQueryCache = {}
local scanTooltip = nil

-- ----------------------------------------------------------------------------
-- 3. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Ensures an item record exists in `ItemDatabase.Catalog` and has an initialized `tagSet`.
--- @param itemID number
--- @return table record
local function ensureCatalogRecord(itemID)
    local rec = ItemDatabase.Catalog[itemID]
    if not rec then
        rec = {
            id = itemID,
            cat = "LOOT",
            tags = {},
            tagSet = {},
            verified = false,
        }
        ItemDatabase.Catalog[itemID] = rec
    elseif not rec.tagSet then
        rec.id = itemID
        rec.tagSet = {}
        if type(rec.tags) == "table" then
            for _, t in ipairs(rec.tags) do
                rec.tagSet[t] = true
            end
        else
            rec.tags = {}
        end
    end
    return rec
end

--- Adds a canonical tag to an item record and updates the inverted `TagIndex`.
--- @param rec table
--- @param tag string|nil
local function addTagToRecord(rec, tag)
    if not tag or tag == "" then
        return
    end
    if not rec.tagSet then
        rec.tagSet = {}
    end
    if not rec.tagSet[tag] then
        rec.tagSet[tag] = true
        rec.tags[#rec.tags + 1] = tag
    end
    local bucket = ItemDatabase.TagIndex[tag]
    if not bucket then
        bucket = {}
        ItemDatabase.TagIndex[tag] = bucket
    end
    bucket[rec.id] = true
end

--- Hydrates instant DBC metadata (`C_Item.GetItemInfoInstant`) for an item record once.
--- @param rec table
local function hydrateInstantFields(rec)
    if rec.instantHydrated then
        return
    end
    rec.instantHydrated = true

    local itemID = rec.id
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if not getInstant then
        return
    end

    local _, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = getInstant(itemID)
    if not classID then
        return
    end

    rec.itemType = rec.itemType or itemType
    rec.itemSubType = rec.itemSubType or itemSubType
    rec.equipLoc = rec.equipLoc or itemEquipLoc
    rec.icon = rec.icon or icon
    rec.classID = rec.classID or classID
    rec.subclassID = rec.subclassID or subclassID

    local overrideCat = ns.ItemCategoryOverrides and ns.ItemCategoryOverrides[itemID]
    if overrideCat then
        rec.cat = overrideCat
    end

    local taxonomy = ns.TagTaxonomy
    if taxonomy then
        local instantTags, slotLabel, subTypeLabel, resolvedCat =
            taxonomy:ClassifyInstant(classID, subclassID, itemEquipLoc, overrideCat or rec.cat)
        if not rec.slot and slotLabel then
            rec.slot = slotLabel
        end
        if not rec.subType and subTypeLabel then
            rec.subType = subTypeLabel
        end
        if (not rec.cat or rec.cat == "LOOT") and resolvedCat and resolvedCat ~= "LOOT" then
            rec.cat = resolvedCat
        end
        for _, t in ipairs(instantTags) do
            addTagToRecord(rec, t)
        end
    end
end

--- Hydrates full `GetItemInfo` fields (`name`, `q`, `iLevel`, `reqLevel`) when available in client cache.
--- @param rec table
--- @return boolean isCached
local function hydrateLiveItemInfo(rec)
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not getInfo then
        return false
    end

    local name, link, quality, iLevel, reqLevel, itemType, itemSubType, _, itemEquipLoc, icon, _, classID, subclassID =
        getInfo(rec.id)
    if not name or name == "" then
        return false
    end

    rec.liveName = name
    rec.name = rec.name or name
    rec.link = link
    if quality ~= nil then rec.q = quality end
    if iLevel and iLevel > 0 then rec.iLevel = iLevel end
    if reqLevel and reqLevel > 0 then rec.reqLevel = reqLevel end
    rec.itemType = itemType or rec.itemType
    rec.itemSubType = itemSubType or rec.itemSubType
    rec.equipLoc = itemEquipLoc or rec.equipLoc
    rec.icon = icon or rec.icon
    rec.classID = classID or rec.classID
    rec.subclassID = subclassID or rec.subclassID
    rec.isCached = true

    if not rec.instantHydrated then
        hydrateInstantFields(rec)
    end
    return true
end

-- ----------------------------------------------------------------------------
-- 4. Initialization & Load-Time Indexing
-- ----------------------------------------------------------------------------

--- Initializes the central item catalog. Defers full inverted tag and source indexing
--- until Advanced Searching is enabled or the Development inspector requests it.
function ItemDatabase:Init()
    if self.isUnloaded then
        return
    end
    if self.isInitialized then
        return
    end
    self.isInitialized = true

    self.Catalog = ns.ItemsCatalog or {}
    self.ItemSources = {}
    self.TagIndex = {}

    for itemID, rec in pairs(self.Catalog) do
        rec.id = itemID
    end

    if ns.ItemCategoryOverrides then
        for itemID, cat in pairs(ns.ItemCategoryOverrides) do
            local rec = self.Catalog[itemID]
            if rec then
                rec.cat = cat
            else
                self.Catalog[itemID] = { id = itemID, cat = cat, tags = {}, verified = false }
            end
        end
    end

    if ns.Database and ns.Database.IsAdvancedSearchEnabled and ns.Database:IsAdvancedSearchEnabled() then
        self:EnsureAdvancedIndex()
    end
end

--- Purges the static item catalog, source links, and inverted tag indexes from memory
--- when all content modules consuming item data (e.g. Dungeons) are unloaded.
function ItemDatabase:Unload()
    self.isUnloaded = true
    self.isInitialized = false
    self.isAdvancedIndexed = false

    if self.Catalog and type(self.Catalog) == "table" then
        table.wipe(self.Catalog)
    end
    if self.ItemSources and type(self.ItemSources) == "table" then
        table.wipe(self.ItemSources)
    end
    if self.TagIndex and type(self.TagIndex) == "table" then
        table.wipe(self.TagIndex)
    end
    if ns.ItemsCatalog and type(ns.ItemsCatalog) == "table" then
        table.wipe(ns.ItemsCatalog)
        ns.ItemsCatalog = nil
    end
    if ns.ItemCategoryOverrides and type(ns.ItemCategoryOverrides) == "table" then
        table.wipe(ns.ItemCategoryOverrides)
        ns.ItemCategoryOverrides = nil
    end
    if ns.EncounterAliases and type(ns.EncounterAliases) == "table" then
        table.wipe(ns.EncounterAliases)
        ns.EncounterAliases = nil
    end
end

--- Builds the bi-directional source links and inverted `TagIndex` on demand when Advanced Searching is active.
function ItemDatabase:EnsureAdvancedIndex()
    if self.isUnloaded then
        return
    end
    self:Init()
    if self.isAdvancedIndexed then
        return
    end
    self.isAdvancedIndexed = true

    -- 1. Index existing catalog records & their static tags
    for itemID, rec in pairs(self.Catalog) do
        rec.id = itemID
        rec.tagSet = {}
        if type(rec.tags) == "table" then
            for _, tag in ipairs(rec.tags) do
                rec.tagSet[tag] = true
                local bucket = self.TagIndex[tag]
                if not bucket then
                    bucket = {}
                    self.TagIndex[tag] = bucket
                end
                bucket[itemID] = true
            end
        else
            rec.tags = {}
        end
    end

    -- 2. Apply explicit category override tags
    if ns.ItemCategoryOverrides then
        for itemID, cat in pairs(ns.ItemCategoryOverrides) do
            local rec = ensureCatalogRecord(itemID)
            rec.cat = cat
            if cat == "QUEST" then
                addTagToRecord(rec, "quest")
            elseif cat == "RECIPE" then
                addTagToRecord(rec, "recipe")
            end
        end
    end

    -- 3. Bi-directionally link Dungeon Drops & Overrides
    local aliases = ns.EncounterAliases or {}
    local function indexSourceTable(sourceTbl, sourceKind)
        if not sourceTbl then return end
        for instanceID, encounters in pairs(sourceTbl) do
            for rawEncounter, itemList in pairs(encounters) do
                local canonicalEncounter = aliases[rawEncounter] or rawEncounter
                local isZoneDrop = (canonicalEncounter == "Zone Drops")
                local isEvent = (canonicalEncounter == "Crown Chemical Co."
                    or canonicalEncounter == "Coren Direbrew"
                    or canonicalEncounter == "Headless Horseman")

                for _, itemID in ipairs(itemList) do
                    local rec = ensureCatalogRecord(itemID)
                    addTagToRecord(rec, sourceKind)
                    if isZoneDrop then
                        addTagToRecord(rec, "zone-drop")
                    else
                        addTagToRecord(rec, "boss-drop")
                    end
                    if isEvent then
                        addTagToRecord(rec, "event")
                    end

                    local srcList = self.ItemSources[itemID]
                    if not srcList then
                        srcList = {}
                        self.ItemSources[itemID] = srcList
                    end
                    srcList[#srcList + 1] = {
                        kind = sourceKind,
                        instanceID = instanceID,
                        encounter = canonicalEncounter,
                        rawEncounter = rawEncounter,
                    }
                end
            end
        end
    end

    indexSourceTable(ns.DropsDungeons, "dungeon")
    indexSourceTable(ns.SourcesOverrides, "dungeon")

    -- 4. Merge any persisted DevTelemetry scanned items from SavedVariables
    self:MergeSavedDevTelemetry()
end

--- Merges previously scanned item telemetry from `JournalBaseDB.DevTelemetry.scannedItems` into the live catalog.
function ItemDatabase:MergeSavedDevTelemetry()
    local rawDB = _G.JournalBaseDB
    local devTel = rawDB and rawDB.DevTelemetry
    local scanned = devTel and devTel.scannedItems
    if type(scanned) ~= "table" then
        return
    end
    for itemID, data in pairs(scanned) do
        local numID = tonumber(itemID)
        if numID then
            self:ApplyScannedItemData(numID, data)
        end
    end
end

--- Applies enriched metadata and tags discovered by the tooltip scanner to an item record.
--- @param itemID number
--- @param data table `{ name, q, reqLevel, iLevel, slot, subType, cat, tags = {...} }`
function ItemDatabase:ApplyScannedItemData(itemID, data)
    if not itemID or type(data) ~= "table" then
        return
    end
    local rec = ensureCatalogRecord(itemID)
    if data.name and data.name ~= "" then rec.name = data.name end
    if data.q ~= nil then rec.q = data.q end
    if data.reqLevel and data.reqLevel > 0 then rec.reqLevel = data.reqLevel end
    if data.iLevel and data.iLevel > 0 then rec.iLevel = data.iLevel end
    if data.slot and data.slot ~= "" then rec.slot = data.slot end
    if data.subType and data.subType ~= "" then rec.subType = data.subType end
    if data.cat and data.cat ~= "" and not (ns.ItemCategoryOverrides and ns.ItemCategoryOverrides[itemID]) then
        rec.cat = data.cat
    end
    if type(data.tags) == "table" then
        for _, tag in ipairs(data.tags) do
            addTagToRecord(rec, tag)
        end
    end
    rec.verified = true
    rec.tooltipScanned = true
end

-- ----------------------------------------------------------------------------
-- 5. Live Tooltip Stat & Level Scanner
-- ----------------------------------------------------------------------------

--- Scans an item's tooltip if the item is cached in the client, extracting stat tags and `reqLevel`.
--- @param itemID number
--- @return boolean success, table|nil record
function ItemDatabase:ScanItemTooltip(itemID)
    if not itemID or itemID <= 0 then
        return false, nil
    end
    self:Init()
    local rec = ensureCatalogRecord(itemID)
    hydrateInstantFields(rec)
    local isCached = hydrateLiveItemInfo(rec)
    if not isCached then
        return false, rec
    end

    if not scanTooltip and CreateFrame then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "AdventureJournalItemScanTooltip", nil, "GameTooltipTemplate")
        if ok and tip then
            scanTooltip = tip
        end
    end
    if not scanTooltip then
        return false, rec
    end

    local ok = pcall(function()
        scanTooltip:SetOwner(_G.UIParent or _G.WorldFrame, "ANCHOR_NONE")
        scanTooltip:ClearLines()
        scanTooltip:SetHyperlink("item:" .. itemID)
    end)
    if not ok then
        return false, rec
    end

    local numLines = (scanTooltip.NumLines and scanTooltip:NumLines()) or 0
    if numLines < 2 then
        return false, rec
    end

    local discoveredTags = {}
    local discoveredMeta = {}
    local taxonomy = ns.TagTaxonomy

    for i = 1, numLines do
        local leftFS = _G["AdventureJournalItemScanTooltipTextLeft" .. i]
        local rightFS = _G["AdventureJournalItemScanTooltipTextRight" .. i]
        local leftText = leftFS and leftFS.GetText and leftFS:GetText()
        local rightText = rightFS and rightFS.GetText and rightFS:GetText()

        if leftText and leftText ~= "" and taxonomy then
            taxonomy:ParseTooltipLine(leftText, discoveredTags, discoveredMeta)
        end
        if rightText and rightText ~= "" and taxonomy then
            taxonomy:ParseTooltipLine(rightText, discoveredTags, discoveredMeta)
        end
    end

    if discoveredMeta.reqLevel and (not rec.reqLevel or rec.reqLevel <= 0) then
        rec.reqLevel = discoveredMeta.reqLevel
    end
    if discoveredMeta.iLevel and (not rec.iLevel or rec.iLevel <= 0) then
        rec.iLevel = discoveredMeta.iLevel
    end

    for tag in pairs(discoveredTags) do
        addTagToRecord(rec, tag)
    end

    rec.tooltipScanned = true
    rec.verified = true
    return true, rec
end

-- ----------------------------------------------------------------------------
-- 6. Event Dispatcher (`GET_ITEM_INFO_RECEIVED`)
-- ----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local pendingListenerNotify = nil
local LISTENER_BATCH_DELAY = 0.12

eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:SetScript("OnEvent", function(frame, event, itemID, success)
    if event == "GET_ITEM_INFO_RECEIVED" and itemID then
        local rec = ItemDatabase.Catalog and ItemDatabase.Catalog[itemID]
        if rec then
            hydrateLiveItemInfo(rec)
        end
        pendingListenerNotify = LISTENER_BATCH_DELAY
        frame:SetScript("OnUpdate", function(f, elapsed)
            if not pendingListenerNotify then
                f:SetScript("OnUpdate", nil)
                return
            end
            pendingListenerNotify = pendingListenerNotify - (elapsed or 0)
            if pendingListenerNotify <= 0 then
                pendingListenerNotify = nil
                f:SetScript("OnUpdate", nil)
                for listener in pairs(updateListeners) do
                    listener(itemID, success)
                end
            end
        end)
    end
end)

function ItemDatabase:RegisterUpdateListener(func)
    if type(func) == "function" then
        updateListeners[func] = true
    end
end

function ItemDatabase:UnregisterUpdateListener(func)
    if func then
        updateListeners[func] = nil
    end
end

-- ----------------------------------------------------------------------------
-- 7. Core Item Lookup & Resolution API
-- ----------------------------------------------------------------------------

--- Returns the enriched catalog record for `itemID`, hydrating instant DBC and cached live info.
--- @param itemID number
--- @return table|nil
function ItemDatabase:GetItem(itemID)
    if not itemID then return nil end
    self:Init()
    local rec = ensureCatalogRecord(itemID)
    hydrateInstantFields(rec)
    hydrateLiveItemInfo(rec)
    return rec
end

--- Returns the localized or static item name for `itemID`.
--- Immediately returns the static catalog name on a cold cache while requesting live server data in the background.
--- @param itemID number
--- @return string|nil
function ItemDatabase:GetItemName(itemID)
    if not itemID then return nil end
    self:Init()
    local rec = ensureCatalogRecord(itemID)

    if rec.liveName then
        return rec.liveName
    end
    if hydrateLiveItemInfo(rec) and rec.liveName then
        return rec.liveName
    end

    -- Request asynchronous load from server at most once per session per itemID
    if not requestedLoadIDs[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
        requestedLoadIDs[itemID] = true
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end

    return rec.name
end

--- Returns all recorded drop/reward sources for `itemID`.
--- @param itemID number
--- @return table
function ItemDatabase:GetItemSources(itemID)
    if not itemID then return {} end
    self:EnsureAdvancedIndex()
    return self.ItemSources[itemID] or {}
end

--- Returns the ordered, deduplicated list of `itemID`s for a specific dungeon encounter.
--- @param instanceID string
--- @param encounterIdentifier string
--- @return table
function ItemDatabase:GetEncounterDrops(instanceID, encounterIdentifier)
    if not instanceID or not encounterIdentifier then
        return {}
    end
    self:Init()

    local drops = {}
    local seen = {}

    local function addList(list)
        if not list then return end
        for _, id in ipairs(list) do
            if not seen[id] then
                seen[id] = true
                drops[#drops + 1] = id
            end
        end
    end

    local aliases = ns.EncounterAliases or {}
    local composites = ns.CompositeEncounters or {}
    local canonicalKey = aliases[encounterIdentifier] or encounterIdentifier
    local compositeKeys = composites[encounterIdentifier] or composites[canonicalKey]

    local function queryTable(tbl)
        local dData = tbl and tbl[instanceID]
        if not dData then return end

        addList(dData[encounterIdentifier])
        if canonicalKey ~= encounterIdentifier then
            addList(dData[canonicalKey])
        end
        if compositeKeys then
            for _, subKey in ipairs(compositeKeys) do
                addList(dData[subKey])
            end
        end
    end

    queryTable(ns.SourcesOverrides)
    queryTable(ns.DropsDungeons)

    return drops
end

-- ----------------------------------------------------------------------------
-- 8. Multi-Tag + `reqLevel` + Free-Text Query Parser & Evaluator
-- ----------------------------------------------------------------------------

--- Parses a raw search string into structured tag filters, required level bounds, and text terms.
--- Supports:
---   - Comma-separated multi-tag queries: `"one handed, sword, spell power"`
---   - Space-separated tag combinations: `"1h sword"`, `"cloth intellect"`
---   - Required character level filters: `"lvl 30-40"`, `">=50"`, `"<=35"`, `"lvl 40+"`
---   - Substring text search: `"vancleef"`, `"shadowfang"`, `"sm"`
--- @param rawQuery string|nil
--- @return table parsedQuery
function ItemDatabase:ParseQuery(rawQuery)
    if not rawQuery or rawQuery == "" then
        return { isEmpty = true, raw = "", tags = {}, textTerms = {}, needsTooltipScan = false }
    end

    local trimmed = strlower(rawQuery):match("^%s*(.-)%s*$")
    if trimmed == "" then
        return { isEmpty = true, raw = "", tags = {}, textTerms = {}, needsTooltipScan = false }
    end

    if parsedQueryCache[trimmed] then
        return parsedQueryCache[trimmed]
    end

    local parsed = {
        isEmpty = false,
        raw = trimmed,
        tags = {},
        textTerms = {},
        minLevel = nil,
        maxLevel = nil,
        singleTagOrText = nil,
        needsTooltipScan = false,
    }

    local taxonomy = ns.TagTaxonomy
    local tagSet = {}
    local function addParsedTag(tag)
        if tag and not tagSet[tag] then
            tagSet[tag] = true
            parsed.tags[#parsed.tags + 1] = tag
            local dim = taxonomy and taxonomy.TAG_DIMENSION and taxonomy.TAG_DIMENSION[tag]
            if dim and TOOLTIP_DEPENDENT_DIMENSIONS[dim] then
                parsed.needsTooltipScan = true
            end
        end
    end

    -- Split by comma or semicolon into clauses
    local clauses = {}
    if strfind(trimmed, "[,;]") then
        for clause in gmatch(trimmed, "([^,;]+)") do
            local c = clause:match("^%s*(.-)%s*$")
            if c ~= "" then
                clauses[#clauses + 1] = c
            end
        end
    else
        clauses[1] = trimmed
    end

    for _, clause in ipairs(clauses) do
        local working = clause

        -- 1. Extract level range expressions: "lvl 30-40", "req 30-40", "level 30-40", or standalone "30-40"
        local strippedLvl = working:gsub("^level%s+", ""):gsub("^lvl%s*", ""):gsub("^req%s+", ""):gsub("^min%s+", "")
        local rMin, rMax = strmatch(strippedLvl, "^(%d+)%s*%-%s*(%d+)$")
        if rMin and rMax then
            parsed.minLevel = tonumber(rMin)
            parsed.maxLevel = tonumber(rMax)
            working = ""
        end

        -- 2. Extract >= / <= / > / < / + level expressions
        if working ~= "" then
            local op, val = strmatch(strippedLvl, "^([><]=?)%s*(%d+)$")
            if op and val then
                local n = tonumber(val)
                if op == ">=" then parsed.minLevel = n
                elseif op == ">" then parsed.minLevel = n + 1
                elseif op == "<=" then parsed.maxLevel = n
                elseif op == "<" then parsed.maxLevel = n - 1
                end
                working = ""
            end
        end
        if working ~= "" then
            local plusVal = strmatch(strippedLvl, "^(%d+)%+$")
                or strmatch(working, "^min%s+l?v?l?%s*(%d+)$")
            if plusVal then
                parsed.minLevel = tonumber(plusVal)
                working = ""
            end
        end
        if working ~= "" then
            local maxVal = strmatch(working, "^max%s+l?v?l?%s*(%d+)$")
            if maxVal then
                parsed.maxLevel = tonumber(maxVal)
                working = ""
            end
        end
        if working ~= "" then
            local exactLvl = strmatch(working, "^lvl%s*(%d+)$")
                or strmatch(working, "^level%s*(%d+)$")
                or strmatch(working, "^req%s*(%d+)$")
            if exactLvl then
                local n = tonumber(exactLvl)
                parsed.minLevel = n
                parsed.maxLevel = n
                working = ""
            end
        end

        -- 3. Resolve canonical tags or text terms
        if working ~= "" and taxonomy then
            local wholeTag = taxonomy:NormalizeToken(working)
            if wholeTag then
                -- If the entire query is just a single word without commas (e.g. "sword" or "shadow"),
                -- record it as singleTagOrText so it matches EITHER the tag OR item/boss/dungeon names!
                if #clauses == 1 and not parsed.minLevel and not parsed.maxLevel then
                    parsed.singleTagOrText = wholeTag
                end
                addParsedTag(wholeTag)
            else
                -- Check if a space-separated clause consists entirely of valid tags/level tokens (e.g. "1h sword >=40")
                local words = {}
                for w in gmatch(working, "%S+") do
                    words[#words + 1] = w
                end
                if #words > 1 then
                    local allWordsMatched = true
                    local matchedTags = {}
                    local i = 1
                    while i <= #words do
                        local w = words[i]
                        local twoWord = (i < #words) and (w .. " " .. words[i + 1]) or nil
                        local twoTag = twoWord and taxonomy:NormalizeToken(twoWord)
                        if twoTag then
                            matchedTags[#matchedTags + 1] = twoTag
                            i = i + 2
                        else
                            local oneTag = taxonomy:NormalizeToken(w)
                            if oneTag then
                                matchedTags[#matchedTags + 1] = oneTag
                                i = i + 1
                            else
                                local op, val = strmatch(w, "^([><]=?)(%d+)$")
                                local rngMin, rngMax = strmatch(w, "^(%d+)%-(%d+)$")
                                local plusNum = strmatch(w, "^(%d+)%+$")
                                if op and val then
                                    local n = tonumber(val)
                                    if op == ">=" then parsed.minLevel = n
                                    elseif op == ">" then parsed.minLevel = n + 1
                                    elseif op == "<=" then parsed.maxLevel = n
                                    elseif op == "<" then parsed.maxLevel = n - 1
                                    end
                                    i = i + 1
                                elseif rngMin and rngMax then
                                    parsed.minLevel = tonumber(rngMin)
                                    parsed.maxLevel = tonumber(rngMax)
                                    i = i + 1
                                elseif plusNum then
                                    parsed.minLevel = tonumber(plusNum)
                                    i = i + 1
                                else
                                    allWordsMatched = false
                                    break
                                end
                            end
                        end
                    end

                    if allWordsMatched and (#matchedTags > 0 or parsed.minLevel or parsed.maxLevel) then
                        for _, t in ipairs(matchedTags) do
                            addParsedTag(t)
                        end
                    else
                        parsed.textTerms[#parsed.textTerms + 1] = working
                    end
                else
                    parsed.textTerms[#parsed.textTerms + 1] = working
                end
            end
        elseif working ~= "" then
            parsed.textTerms[#parsed.textTerms + 1] = working
        end
    end

    parsedQueryCache[trimmed] = parsed
    return parsed
end

--- Evaluates whether `itemID` satisfies a parsed multi-tag + `reqLevel` + text query.
--- When Advanced Searching is disabled in Settings (and `forceAdvanced` is not set),
--- performs a fast, lightweight item name substring check without tag indexing or tooltip scanning.
--- @param itemID number
--- @param parsedQuery table
--- @param forceAdvanced boolean|nil
--- @return boolean matches, string|nil displayName
function ItemDatabase:ItemMatchesParsedQuery(itemID, parsedQuery, forceAdvanced)
    if not itemID then return false, nil end
    self:Init()
    local rec = self.Catalog[itemID]
    local fastName = rec and (rec.liveName or rec.name) or nil

    if not parsedQuery or parsedQuery.isEmpty then
        return true, fastName or self:GetItemName(itemID)
    end

    local isAdv = forceAdvanced or (ns.Database and ns.Database.IsAdvancedSearchEnabled and ns.Database:IsAdvancedSearchEnabled())
    if not isAdv then
        if not fastName and rec then
            hydrateLiveItemInfo(rec)
            fastName = rec.liveName or rec.name
        end
        if fastName and strfind(strlower(fastName), parsedQuery.raw, 1, true) then
            return true, fastName
        end
        return false, fastName
    end

    self:EnsureAdvancedIndex()
    rec = ensureCatalogRecord(itemID)
    hydrateInstantFields(rec)
    local itemName = rec.liveName or rec.name
    if not itemName then
        hydrateLiveItemInfo(rec)
        itemName = rec.liveName or rec.name
    end

    local taxonomy = ns.TagTaxonomy
    local dimMap = taxonomy and taxonomy.TAG_DIMENSION

    -- 1. Fast Reject on Instant / Static Tags FIRST (e.g. "2h", "sword", "plate", "head")
    -- This filters out non-matching item types in microseconds before touching tooltips or server requests.
    if not (parsedQuery.singleTagOrText and #parsedQuery.tags == 1 and #parsedQuery.textTerms == 0) then
        for _, reqTag in ipairs(parsedQuery.tags) do
            local dim = dimMap and dimMap[reqTag]
            if not (dim and TOOLTIP_DEPENDENT_DIMENSIONS[dim]) then
                if not (rec.tagSet and rec.tagSet[reqTag]) then
                    return false, itemName
                end
            end
        end
    end

    -- 2. Evaluate Free-Text Substring Terms early if present
    if #parsedQuery.textTerms > 0 then
        local lowerName = itemName and strlower(itemName) or ""
        local lowerSlot = rec.slot and strlower(rec.slot) or ""
        local lowerSubType = rec.subType and strlower(rec.subType) or ""
        for _, term in ipairs(parsedQuery.textTerms) do
            local matchedTerm = false
            if lowerName ~= "" and strfind(lowerName, term, 1, true) then
                matchedTerm = true
            elseif lowerSlot ~= "" and strfind(lowerSlot, term, 1, true) then
                matchedTerm = true
            elseif lowerSubType ~= "" and strfind(lowerSubType, term, 1, true) then
                matchedTerm = true
            end
            if not matchedTerm then
                return false, itemName
            end
        end
    end

    -- 3. Hydrate Live Info & Lazily Scan Tooltip for Candidate Items when Tooltip/Level Data is Needed
    if (parsedQuery.needsTooltipScan or parsedQuery.minLevel or parsedQuery.maxLevel) and not rec.tooltipScanned then
        local isEquippableOrLevel = (rec.classID == 2 or rec.classID == 4)
            or (parsedQuery.minLevel ~= nil or parsedQuery.maxLevel ~= nil)
        if isEquippableOrLevel then
            if not rec.isCached then
                hydrateLiveItemInfo(rec)
            end
            if rec.isCached then
                self:ScanItemTooltip(itemID)
            elseif not requestedLoadIDs[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
                requestedLoadIDs[itemID] = true
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
        end
    end

    -- 4. Evaluate Required Character Level (`minLevel` / `maxLevel`)
    if parsedQuery.minLevel or parsedQuery.maxLevel then
        local reqLvl = rec.reqLevel
        if not reqLvl or reqLvl <= 0 then
            return false, itemName
        end
        if parsedQuery.minLevel and reqLvl < parsedQuery.minLevel then
            return false, itemName
        end
        if parsedQuery.maxLevel and reqLvl > parsedQuery.maxLevel then
            return false, itemName
        end
    end

    -- 5. Single-token hybrid mode (e.g. user typed "sword" or "shadow" -> matches tag OR item name)
    if parsedQuery.singleTagOrText and #parsedQuery.tags == 1 and #parsedQuery.textTerms == 0 then
        local tag = parsedQuery.singleTagOrText
        if rec.tagSet and rec.tagSet[tag] then
            return true, itemName or ("Item #" .. itemID)
        end
        if itemName and strfind(strlower(itemName), parsedQuery.raw, 1, true) then
            return true, itemName
        end
        return false, itemName
    end

    -- 6. Evaluate All Required Canonical Tags (including tooltip-derived stat tags)
    for _, reqTag in ipairs(parsedQuery.tags) do
        if not (rec.tagSet and rec.tagSet[reqTag]) then
            return false, itemName
        end
    end

    return true, itemName or ("Item #" .. itemID)
end

--- Checks if a boss or any of its encounter drops match a query string.
--- @param instanceID string
--- @param boss table
--- @param query string
--- @return boolean isMatch, table|nil matchedItem
function ItemDatabase:BossMatchesQuery(instanceID, boss, query)
    if not boss or not query or query == "" then
        return true, nil
    end

    local isAdv = (ns.Database and ns.Database.IsAdvancedSearchEnabled and ns.Database:IsAdvancedSearchEnabled())
    if not isAdv then
        self:Init()
        local qLower = strlower(query):match("^%s*(.-)%s*$")
        if qLower == "" then
            return true, nil
        end
        if boss.name and strfind(strlower(boss.name), qLower, 1, true) then
            return true, nil
        end
        local bossKey = (boss.isZone or boss.isTrash) and "Zone Drops" or boss.name
        local dropIDs = self:GetEncounterDrops(instanceID, bossKey)
        if dropIDs then
            for _, itemID in ipairs(dropIDs) do
                local rec = self.Catalog[itemID]
                local itemName = rec and (rec.liveName or rec.name) or nil
                if itemName and strfind(strlower(itemName), qLower, 1, true) then
                    return true, { id = itemID, name = itemName }
                end
            end
        end
        return false, nil
    end

    local parsed = self:ParseQuery(query)
    if parsed.isEmpty then
        return true, nil
    end

    -- 1. Check Boss Name if query is a simple text search without level/multi-tag constraints
    local isMultiConstraint = (#parsed.tags > 1) or parsed.minLevel or parsed.maxLevel or (#parsed.tags == 1 and #parsed.textTerms > 0)
    if not isMultiConstraint and boss.name and strfind(strlower(boss.name), parsed.raw, 1, true) then
        return true, nil
    end

    -- 2. Check Boss Encounter Drops against the parsed query
    local bossKey = (boss.isZone or boss.isTrash) and "Zone Drops" or boss.name
    local dropIDs = self:GetEncounterDrops(instanceID, bossKey)
    if dropIDs then
        for _, itemID in ipairs(dropIDs) do
            local matches, itemName = self:ItemMatchesParsedQuery(itemID, parsed)
            if matches then
                return true, { id = itemID, name = itemName or ("Item #" .. itemID) }
            end
        end
    end

    return false, nil
end

--- Executes a global catalog query and returns matching item records.
--- @param queryStrOrSpec string|table
--- @return table results Array of catalog records
function ItemDatabase:Query(queryStrOrSpec)
    self:EnsureAdvancedIndex()
    local parsed = type(queryStrOrSpec) == "string" and self:ParseQuery(queryStrOrSpec) or queryStrOrSpec
    local results = {}
    for itemID, rec in pairs(self.Catalog) do
        local ok = self:ItemMatchesParsedQuery(itemID, parsed, true)
        if ok then
            results[#results + 1] = rec
        end
    end
    return results
end

-- ----------------------------------------------------------------------------
-- 9. Category Classification & Player Usability
-- ----------------------------------------------------------------------------

function ItemDatabase:IsItemUsableByPlayer(itemType, itemSubType, itemEquipLoc)
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

function ItemDatabase:GetItemCategory(itemType, itemSubType, itemEquipLoc, itemID, itemName, classID, subclassID)
    self:Init()

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

    -- 1. TRADESKILL RECIPES
    if itemName then
        if itemName:find("^Pattern:") or itemName:find("^Plans:") or itemName:find("^Recipe:")
            or itemName:find("^Schematic:") or itemName:find("^Formula:") or itemName:find("^Manual:")
            or itemName:find("^Blueprint:") then
            return "RECIPE"
        end
    end
    if (itemType == "Recipe" or classID == 9) and (itemSubType ~= "Book") then
        return "RECIPE"
    end
    if itemSubType and TRADESKILL_SUBTYPES[itemSubType] and (not itemEquipLoc or itemEquipLoc == "" or itemEquipLoc == "INVTYPE_NON_EQUIP") then
        return "RECIPE"
    end

    -- 2. CLASS SKILL BOOKS
    if itemSubType == "Book" or itemType == "Book" then
        return "MISC"
    end

    -- 3. QUEST ITEMS & KEYS
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

    -- 5. EQUIPPABLE GEAR
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

    -- 8. Check Static Catalog Category Fallback
    if itemID and self.Catalog[itemID] then
        local cat = self.Catalog[itemID].cat
        if cat == "QUEST" or cat == "RECIPE" or cat == "COLLECTIBLE" then
            return cat
        end
    end

    return "MISC"
end

function ItemDatabase:GetAtlasLootVersionStatus()
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

-- ----------------------------------------------------------------------------
-- 10. Developer Telemetry & Deficit Reporting API
-- ----------------------------------------------------------------------------

--- Computes live catalog coverage telemetry across all indexed records.
--- @return table telemetry
function ItemDatabase:GetCatalogTelemetry()
    self:EnsureAdvancedIndex()
    local total = 0
    local withName = 0
    local withQuality = 0
    local withSlot = 0
    local withReqLevel = 0
    local verified = 0
    local unverified = 0
    local tagCounts = 0

    for _, rec in pairs(self.Catalog) do
        total = total + 1
        if rec.name and rec.name ~= "" then withName = withName + 1 end
        if rec.q ~= nil then withQuality = withQuality + 1 end
        if rec.slot or rec.subType then withSlot = withSlot + 1 end
        if rec.reqLevel and rec.reqLevel > 0 then withReqLevel = withReqLevel + 1 end
        if rec.verified then
            verified = verified + 1
        else
            unverified = unverified + 1
        end
        if rec.tags then
            tagCounts = tagCounts + #rec.tags
        end
    end

    local uniqueTagsUsed = 0
    for _ in pairs(self.TagIndex) do
        uniqueTagsUsed = uniqueTagsUsed + 1
    end

    return {
        total = total,
        withName = withName,
        withQuality = withQuality,
        withSlot = withSlot,
        withReqLevel = withReqLevel,
        verified = verified,
        unverified = unverified,
        totalTagLinks = tagCounts,
        uniqueTagsUsed = uniqueTagsUsed,
    }
end

--- Returns a sorted list of unverified `itemID`s (prioritizing items missing names first).
--- @return table itemIDs
function ItemDatabase:GetUnverifiedItemIDs()
    self:Init()
    local missingNames = {}
    local needsScan = {}
    for itemID, rec in pairs(self.Catalog) do
        if not rec.verified then
            if not rec.name or rec.name == "" then
                missingNames[#missingNames + 1] = itemID
            else
                needsScan[#needsScan + 1] = itemID
            end
        end
    end
    table.sort(missingNames)
    table.sort(needsScan)
    for _, id in ipairs(needsScan) do
        missingNames[#missingNames + 1] = id
    end
    return missingNames
end

-- ----------------------------------------------------------------------------
-- 11. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.ItemDatabase = ItemDatabase
ns.Items = ItemDatabase
