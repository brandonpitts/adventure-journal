-- ============================================================================
-- Utility_DataStore - Tags/TagRegistry.lua
--
-- Tags are the words players search and filter with: "agility", "two-hand",
-- "boss drop", "attunement", "class quest". Every tag is defined once, with the
-- search words that mean it, and any store can use it. Deliberately not a
-- store: stores reference in-game things, and tags are ours.
-- Records carry stored tags in their `tags` field; stores can add computed
-- tags (from client data, stats or links) with AddTagSource. Search treats
-- both the same.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local type = type
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local strlower = string.lower
local strfind = string.find
local gmatch = string.gmatch
local gsub = string.gsub
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Tag definitions: key -> { label, short, group, stores, computed, synonyms }
local tags = {}
-- Search word (lowercase) -> tag key
local words = {}
-- Computed tag sources: storeName -> list of function(key) returning tag keys
local sources = {}
-- Built search index: storeName -> tag key -> { [recordKey] = true }
local index = {}
-- Tags per record, built on demand: storeName -> recordKey -> { [tag] = true }
local recordTags = {}

local function addWord(word, key)
    if type(word) == "string" and word ~= "" then
        words[strlower(word)] = key
    end
end

local function trim(text)
    return (gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function addToIndex(storeIndex, tag, recordKey)
    local bucket = storeIndex[tag]
    if not bucket then
        bucket = {}
        storeIndex[tag] = bucket
    end
    bucket[recordKey] = true
end

-- Index of every tag (stored and computed) on every record in one store.
local function buildIndex(store)
    local storeIndex = {}
    for key in store:EachKey() do
        local record = store:Get(key)
        for _, tag in ipairs(record and record.tags or {}) do
            addToIndex(storeIndex, tag, key)
        end
        for _, source in ipairs(sources[store.name] or {}) do
            for _, tag in ipairs(source(key) or {}) do
                addToIndex(storeIndex, tag, key)
            end
        end
    end
    return storeIndex
end

-- Splits a query into tag keys and plain text terms. Commas separate clauses; inside a
-- clause, the whole clause, then word pairs, then single words are tried as tags.
local function parseQuery(query)
    local tagKeys, textTerms = {}, {}
    for rawClause in gmatch(strlower(query or ""), "[^,;]+") do
        local clause = trim(rawClause)
        if words[clause] then
            tagKeys[#tagKeys + 1] = words[clause]
        elseif clause ~= "" then
            local list = {}
            for word in gmatch(clause, "%S+") do
                list[#list + 1] = word
            end
            local i = 1
            while i <= #list do
                local pair = list[i + 1] and words[list[i] .. " " .. list[i + 1]]
                if pair then
                    tagKeys[#tagKeys + 1] = pair
                    i = i + 2
                else
                    if words[list[i]] then
                        tagKeys[#tagKeys + 1] = words[list[i]]
                    else
                        textTerms[#textTerms + 1] = list[i]
                    end
                    i = i + 1
                end
            end
        end
    end
    return tagKeys, textTerms
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local TagRegistry = {}

--- Sets every tag definition: key -> { label, short, group, stores, computed, synonyms }.
function TagRegistry:SetTags(definitions)
    wipe(tags)
    wipe(words)
    wipe(index)
    for key, def in pairs(definitions or {}) do
        tags[key] = def
        addWord(key, key)
        addWord((gsub(key, "-", " ")), key)
        addWord(def.label, key)
        for _, synonym in ipairs(def.synonyms or {}) do
            addWord(synonym, key)
        end
    end
end

function TagRegistry:GetTag(key)
    return tags[key]
end

--- The tag's label; its short label when `useShort` is true and it has one.
function TagRegistry:GetLabel(key, useShort)
    local def = tags[key]
    if not def then
        return nil
    end
    return (useShort and def.short) or def.label
end

--- The tag key a search word means, or nil.
function TagRegistry:Normalize(word)
    return type(word) == "string" and words[strlower(trim(word))] or nil
end

--- Adds a computed tag source for a store: `fn(key)` returns a list of tag keys.
function TagRegistry:AddTagSource(storeName, fn)
    sources[storeName] = sources[storeName] or {}
    local list = sources[storeName]
    list[#list + 1] = fn
    index[storeName] = nil
end

--- Keys of records in `storeName` matching every tag and text term in `query`. Always a list.
--- Empty when the DataStore is off or Advanced Search is off; the index builds on first use.
function TagRegistry:Search(query, storeName)
    local results = {}
    local store = DataStore[storeName]
    local settings = ns.Settings
    if not (store and DataStore:IsEnabled() and settings and settings:IsAdvancedSearchEnabled()) then
        return results
    end
    local storeIndex = index[storeName]
    if not storeIndex then
        storeIndex = buildIndex(store)
        index[storeName] = storeIndex
    end
    local tagKeys, textTerms = parseQuery(query)
    for key in store:EachKey() do
        local match = true
        for _, tag in ipairs(tagKeys) do
            if not (storeIndex[tag] and storeIndex[tag][key]) then
                match = false
                break
            end
        end
        if match and #textTerms > 0 then
            local label = strlower(store:GetLabel(key) or "")
            for _, term in ipairs(textTerms) do
                if not strfind(label, term, 1, true) then
                    match = false
                    break
                end
            end
        end
        if match then
            results[#results + 1] = key
        end
    end
    return results
end

--- Every tag one record has, stored and computed, as a set: tag key -> true. Cached until ClearIndex.
function TagRegistry:GetRecordTags(storeName, key)
    local cache = recordTags[storeName]
    if not cache then
        cache = {}
        recordTags[storeName] = cache
    end
    local set = cache[key]
    if not set then
        set = {}
        local store = DataStore[storeName]
        local record = store and store:Get(key)
        for _, tag in ipairs(record and record.tags or {}) do
            set[tag] = true
        end
        for _, source in ipairs(sources[storeName] or {}) do
            for _, tag in ipairs(source(key) or {}) do
                set[tag] = true
            end
        end
        cache[key] = set
    end
    return set
end

--- Forgets the search index and cached record tags; they rebuild on next use.
function TagRegistry:ClearIndex()
    wipe(index)
    wipe(recordTags)
end

--- Empties the registry (used when the DataStore unloads).
function TagRegistry:Reset()
    wipe(tags)
    wipe(words)
    wipe(sources)
    wipe(index)
    wipe(recordTags)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
DataStore.TagRegistry = TagRegistry
