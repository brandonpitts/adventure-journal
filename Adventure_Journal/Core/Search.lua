-- ============================================================================
-- Adventure Journal - Core/Search.lua
-- The header search box's item search. Parses what the player typed into tags,
-- required-level limits and plain words, and checks items against it using the
-- DataStore (ItemStore names, TagRegistry tags). Off when the DataStore is off.
--   "1h sword", "cloth, intellect", "lvl 30-40", ">=50", "40+", "vancleef"
-- With Advanced Search off, only item names are matched.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local type = type
local tonumber = tonumber
local strfind = string.find
local strlower = string.lower
local strmatch = string.match
local gmatch = string.gmatch
local wipe = wipe

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local EMPTY_QUERY = { isEmpty = true, raw = "", tags = {}, textTerms = {} }
local parsedCache = {}

local function trim(text)
    return strmatch(text, "^%s*(.-)%s*$") or ""
end

local function registry()
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore.TagRegistry
end

-- A level limit in one word or clause: "30-40", ">=50", ">50", "<=35", "<35", "40+". Sets parsed limits.
local function readLevelLimit(parsed, text)
    local low, high = strmatch(text, "^(%d+)%s*%-%s*(%d+)$")
    if low then
        parsed.minLevel, parsed.maxLevel = tonumber(low), tonumber(high)
        return true
    end
    local op, value = strmatch(text, "^([><]=?)%s*(%d+)$")
    if op then
        local n = tonumber(value)
        if op == ">=" then parsed.minLevel = n
        elseif op == ">" then parsed.minLevel = n + 1
        elseif op == "<=" then parsed.maxLevel = n
        else parsed.maxLevel = n - 1
        end
        return true
    end
    local plus = strmatch(text, "^(%d+)%+$")
    if plus then
        parsed.minLevel = tonumber(plus)
        return true
    end
    return false
end

-- One clause: a level limit, a whole tag, a run of tags and limits, or plain text.
local function readClause(parsed, clause, tagRegistry, onlyClause)
    local stripped = clause:gsub("^level%s+", ""):gsub("^lvl%s*", ""):gsub("^req%s+", ""):gsub("^min%s+", "")
    if readLevelLimit(parsed, stripped) then
        return
    end
    local maxValue = strmatch(clause, "^max%s+l?v?l?%s*(%d+)$")
    if maxValue then
        parsed.maxLevel = tonumber(maxValue)
        return
    end
    local exact = strmatch(clause, "^lvl%s*(%d+)$") or strmatch(clause, "^level%s*(%d+)$") or strmatch(clause, "^req%s*(%d+)$")
    if exact then
        parsed.minLevel, parsed.maxLevel = tonumber(exact), tonumber(exact)
        return
    end
    local whole = tagRegistry and tagRegistry:Normalize(clause)
    if whole then
        -- A single word that is also a tag matches the tag or a name ("shadow")
        if onlyClause and not parsed.minLevel and not parsed.maxLevel then
            parsed.singleTagOrText = whole
        end
        parsed.tags[#parsed.tags + 1] = whole
        return
    end
    local words = {}
    for word in gmatch(clause, "%S+") do
        words[#words + 1] = word
    end
    if #words > 1 and tagRegistry then
        local found, i = {}, 1
        while i <= #words do
            local pair = words[i + 1] and tagRegistry:Normalize(words[i] .. " " .. words[i + 1])
            local single = tagRegistry:Normalize(words[i])
            if pair then
                found[#found + 1] = pair
                i = i + 2
            elseif single then
                found[#found + 1] = single
                i = i + 1
            elseif readLevelLimit(parsed, words[i]) then
                i = i + 1
            else
                found = nil
                break
            end
        end
        if found and (#found > 0 or parsed.minLevel or parsed.maxLevel) then
            for _, tag in ipairs(found) do
                parsed.tags[#parsed.tags + 1] = tag
            end
            return
        end
    end
    parsed.textTerms[#parsed.textTerms + 1] = clause
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Search = {}

--- Parses a search string: { isEmpty, raw, tags, textTerms, minLevel, maxLevel, singleTagOrText }.
function Search:Parse(rawQuery)
    local trimmed = trim(strlower(rawQuery or ""))
    if trimmed == "" then
        return EMPTY_QUERY
    end
    if parsedCache[trimmed] then
        return parsedCache[trimmed]
    end
    local parsed = { isEmpty = false, raw = trimmed, tags = {}, textTerms = {} }
    local clauses = {}
    for rawClause in gmatch(trimmed, "[^,;]+") do
        local clause = trim(rawClause)
        if clause ~= "" then
            clauses[#clauses + 1] = clause
        end
    end
    local tagRegistry = registry()
    for _, clause in ipairs(clauses) do
        readClause(parsed, clause, tagRegistry, #clauses == 1)
    end
    parsedCache[trimmed] = parsed
    return parsed
end

--- True when a query asks for more than one thing (several tags, a level limit, or a tag plus words).
function Search:IsMultiConstraint(parsed)
    return parsed and ((#parsed.tags > 1) or parsed.minLevel or parsed.maxLevel
        or (#parsed.tags == 1 and #parsed.textTerms > 0)) and true or false
end

--- Whether an item matches a parsed query (or a raw string). Returns the match, then the item's name.
function Search:ItemMatches(itemID, parsed)
    if type(parsed) ~= "table" then
        parsed = self:Parse(parsed)
    end
    local DataStore = ns.DataStore
    if not (DataStore and DataStore:IsEnabled()) then
        return false, nil
    end
    local items = DataStore.ItemStore
    local name = items:GetLabel(itemID)
    if parsed.isEmpty then
        return true, name
    end
    local lowerName = strlower(name or "")
    if not (ns.Settings and ns.Settings:IsAdvancedSearchEnabled()) then
        return strfind(lowerName, parsed.raw, 1, true) ~= nil, name
    end

    local tags = DataStore.TagRegistry:GetRecordTags("ItemStore", itemID)
    if parsed.singleTagOrText and #parsed.tags == 1 and #parsed.textTerms == 0 then
        return (tags[parsed.singleTagOrText] or strfind(lowerName, parsed.raw, 1, true)) and true or false, name
    end
    for _, tag in ipairs(parsed.tags) do
        if not tags[tag] then
            return false, name
        end
    end
    if #parsed.textTerms > 0 then
        local slot = strlower(items:GetSlotLabel(itemID) or "")
        local kind = strlower(items:GetTypeLabel(itemID) or "")
        for _, term in ipairs(parsed.textTerms) do
            if not (strfind(lowerName, term, 1, true) or strfind(slot, term, 1, true) or strfind(kind, term, 1, true)) then
                return false, name
            end
        end
    end
    if parsed.minLevel or parsed.maxLevel then
        local required = items:GetRequiredLevel(itemID)
        if not required or required <= 0
            or (parsed.minLevel and required < parsed.minLevel)
            or (parsed.maxLevel and required > parsed.maxLevel) then
            return false, name
        end
    end
    return true, name
end

--- Forgets parsed queries (tag words may have changed).
function Search:ClearCache()
    wipe(parsedCache)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Search = Search
