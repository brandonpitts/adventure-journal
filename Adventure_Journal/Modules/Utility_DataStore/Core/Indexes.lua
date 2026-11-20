-- ============================================================================
-- Utility_DataStore - Core/Indexes.lua
-- Lookup tables built from the stores the first time they're needed: which
-- records point at a key (link indexes) and named indexes a store defines
-- (for example "obtained from" for items). Facts are stored once; the reverse
-- direction lives only here.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local type = type
local ipairs = ipairs
local wipe = wipe
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Built indexes: name -> table
local built = {}
-- Named index builders: name -> function() return index end
local builders = {}

local function addEntry(index, value, key)
    local bucket = index[value]
    if not bucket then
        bucket = {}
        index[value] = bucket
    end
    bucket[#bucket + 1] = key
end

-- Link index for one store field: value -> list of record keys whose field holds that value.
local function buildLinkIndex(store, field)
    local index = {}
    for key in store:EachKey() do
        local value = store:GetField(key, field)
        if type(value) == "table" then
            for _, item in ipairs(value) do
                addEntry(index, item, key)
            end
        elseif value ~= nil then
            addEntry(index, value, key)
        end
    end
    return index
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Indexes = {}

--- Registers a named index. `builder()` runs on first use and returns the index table.
function Indexes:Define(name, builder)
    builders[name] = builder
    built[name] = nil
end

--- Returns a named index, building it on first use. Nil when no such index is defined.
function Indexes:Get(name)
    local index = built[name]
    if index == nil and builders[name] then
        index = builders[name]() or {}
        built[name] = index
    end
    return index
end

--- Keys of records in `store` whose `field` holds `value` (or lists it). Always a list.
function Indexes:FindBy(store, field, value)
    local name = "link:" .. store.name .. "." .. field
    local index = built[name]
    if not index then
        index = buildLinkIndex(store, field)
        built[name] = index
    end
    return index[value] or {}
end

--- Forgets every built index; they rebuild on next use.
function Indexes:Clear()
    wipe(built)
end

--- Forgets built indexes and their definitions (used when the DataStore unloads).
function Indexes:Reset()
    wipe(built)
    wipe(builders)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
DataStore.Indexes = Indexes
