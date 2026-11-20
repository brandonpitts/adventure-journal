-- ============================================================================
-- Utility_DataStore - Core/Schema.lua
-- Field definitions for stores, the fields every record shares, and a check
-- that lists every problem in a record. Used by probes and migration tooling.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local DataStore = ns.DataStore
local Constants = DataStore.Constants

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Field spec keys:
--   type      "number" | "string" | "boolean" | "table"
--   required  true when every record must have it
--   live      true when the client answers it (never stored)
--   links     store name this field points at (its value is a key there)
--   list      true when the value is a list (of keys, for links)
--   comment   one line saying what the field holds

-- Fields every record has (section 4.1). `verified` and `source` can be dropped
-- per store with `exempt`, though no store does so today.
local SHARED_FIELDS = {
    label      = { type = "string",  required = true,  comment = "Readable name; shown when the client can't answer." },
    verified   = { type = "boolean", required = true,  comment = "Checked against the game." },
    source     = { type = "string",  required = true,  comment = "client, game, manual, legacy, or reference (an addon intake, unconfirmed)." },
    tags       = { type = "table",   list = true,      comment = "Tag keys from the tag registry." },
    faction    = { type = "string",                    comment = "Alliance or Horde; absent means both." },
    reputation = { type = "table",                     comment = "A reputation faction: { id, label }." },
}

-- Values that mean "missing" and must never be stored (section 4.3)
local PLACEHOLDER_VALUES = { [""] = true, ["??"] = true }

local function checkValue(problems, field, spec, value)
    if spec.live then
        problems[#problems + 1] = field .. ": live field stored in data"
        return
    end
    if type(value) ~= spec.type then
        problems[#problems + 1] = field .. ": expected " .. spec.type .. ", got " .. type(value)
        return
    end
    if PLACEHOLDER_VALUES[value] then
        problems[#problems + 1] = field .. ": placeholder value " .. tostring(value)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Schema = {}

--- Builds a full field table: the shared fields (minus exemptions) plus the store's own.
--- @param storeFields table field name -> spec
--- @param exempt table|nil list of shared field names this store drops
--- @return table
function Schema:BuildFields(storeFields, exempt)
    local fields = {}
    local skip = {}
    for _, name in ipairs(exempt or {}) do
        skip[name] = true
    end
    for name, spec in pairs(SHARED_FIELDS) do
        if not skip[name] then
            fields[name] = spec
        end
    end
    for name, spec in pairs(storeFields or {}) do
        fields[name] = spec
    end
    return fields
end

--- Lists every problem in one record. An empty list means the record is valid.
--- @param fields table built by BuildFields
--- @param record table
--- @return string[] problems
function Schema:Check(fields, record)
    local problems = {}
    if type(record) ~= "table" then
        problems[1] = "record is not a table"
        return problems
    end
    for name, spec in pairs(fields) do
        local value = record[name]
        if value == nil then
            if spec.required then
                problems[#problems + 1] = name .. ": required field missing"
            end
        else
            checkValue(problems, name, spec, value)
        end
    end
    for name in pairs(record) do
        if not fields[name] then
            problems[#problems + 1] = tostring(name) .. ": unknown field"
        end
    end
    if record.source and not Constants.SOURCES[record.source] then
        problems[#problems + 1] = "source: unknown value " .. tostring(record.source)
    end
    if record.faction and not Constants.FACTIONS[record.faction] then
        problems[#problems + 1] = "faction: unknown value " .. tostring(record.faction)
    end
    return problems
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
DataStore.Schema = Schema
