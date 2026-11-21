-- ============================================================================
-- Utility_DataStore - Core/StoreBase.lua
-- What every store is built from: the read calls (Get, GetLabel, GetField,
-- Exists, FindBy), putting each record together from base data plus
-- overrides, and the missing-reference marker. Texts and hints: StoreTexts.lua.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local tostring = tostring
local format = string.format
local setmetatable = setmetatable
local wipe = wipe
local UnitFactionGroup = UnitFactionGroup
local DataStore = ns.DataStore
local Constants = DataStore.Constants

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local EMPTY = {}

local function shallowCopy(source)
    local copy = {}
    for k, v in pairs(source) do
        copy[k] = v
    end
    return copy
end

-- Applies one override entry to a record (or creates the record). Returns the record.
local function applyOverride(record, entry)
    if entry.field == nil then
        return shallowCopy(entry.value)
    end
    record = record or {}
    record[entry.field] = entry.value
    return record
end

-- ----------------------------------------------------------------------------
-- 3. Store Definition
-- ----------------------------------------------------------------------------
local Store = {}
Store.__index = Store

--- Sets the generated base data: key -> record.
function Store:SetBase(base)
    self.base = base or {}
    self:Invalidate()
end

--- Sets the overrides list (section 9 format). Faction entries apply only to that faction.
function Store:SetOverrides(entries)
    self.overrides = {}
    for _, entry in ipairs(entries or EMPTY) do
        local list = self.overrides[entry.key]
        if not list then
            list = {}
            self.overrides[entry.key] = list
        end
        list[#list + 1] = entry
    end
    self:Invalidate()
end

--- Drops built records and indexes after data changes.
function Store:Invalidate()
    wipe(self.composed)
    self.keyList = nil
    if DataStore.Indexes then
        DataStore.Indexes:Clear()
    end
    if DataStore.TagRegistry then
        DataStore.TagRegistry:ClearIndex()
    end
end

-- Puts one record together: base, then static overrides, then the player's faction overrides.
function Store:Compose(key)
    local record = self.base[key] and shallowCopy(self.base[key])
    local playerFaction = UnitFactionGroup("player")
    for _, entry in ipairs(self.overrides[key] or EMPTY) do
        if not entry.faction or entry.faction == playerFaction then
            record = applyOverride(record, entry)
        end
    end
    return record
end

--- The record for `key`, or nil. Treat it as read-only.
function Store:Get(key)
    if key == nil or not DataStore:IsEnabled() then
        return nil
    end
    local record = self.composed[key]
    if record == nil then
        record = self:Compose(key) or false
        self.composed[key] = record
    end
    return record or nil
end

function Store:Exists(key)
    return self:Get(key) ~= nil
end

--- One field. Live fields are answered by the client through the store's `live` functions.
function Store:GetField(key, field)
    local liveField = self.live and self.live[field]
    if liveField then
        return DataStore:IsEnabled() and liveField(key) or nil
    end
    local record = self:Get(key)
    return record and record[field]
end

--- The name to show: the client's answer, else the label (marked when the client says the
--- game record doesn't exist), else "Unknown <kind> <key>". Nil when the DataStore is off.
function Store:GetLabel(key)
    if not DataStore:IsEnabled() then
        return nil
    end
    local record = self:Get(key)
    if not record then
        return format(Constants.UNKNOWN_RECORD_FORMAT, self.kind, tostring(key))
    end
    local live = DataStore.Live
    local liveKind = self.liveName
    if type(liveKind) == "function" then
        liveKind = liveKind(key, record)
    end
    if liveKind and type(key) == "number" then
        local name = live:GetName(liveKind, key)
        if name then
            return name
        end
    end
    if self.existsKind and type(key) == "number" and live:Exists(self.existsKind, key) == false then
        return record.label .. Constants.MISSING_REFERENCE_SUFFIX
    end
    return record.label
end

--- Keys of records whose `field` points at `value`. Always a list.
function Store:FindBy(field, value)
    if not DataStore:IsEnabled() then
        return EMPTY
    end
    return DataStore.Indexes:FindBy(self, field, value)
end

--- Iterates every key: base records plus records that overrides add.
function Store:EachKey()
    if not self.keyList then
        local seen, list = {}, {}
        for key in pairs(self.base) do
            seen[key] = true
            list[#list + 1] = key
        end
        for key in pairs(self.overrides) do
            if not seen[key] and self:Compose(key) then
                list[#list + 1] = key
            end
        end
        self.keyList = list
    end
    local i = 0
    return function()
        i = i + 1
        return self.keyList[i]
    end
end

function Store:Count()
    local n = 0
    for _ in self:EachKey() do
        n = n + 1
    end
    return n
end

--- Problems in one record, checked against the schema. Empty when valid.
function Store:Check(key)
    return DataStore.Schema:Check(self.fields, self:Compose(key))
end

--- Every invalid record: key -> problems. Empty when the whole store is valid.
function Store:CheckAll()
    local invalid = {}
    for key in self:EachKey() do
        local problems = self:Check(key)
        if next(problems) then
            invalid[key] = problems
        end
    end
    return invalid
end

--- Empties the store (used when the DataStore unloads).
function Store:Reset()
    self.base, self.overrides, self.texts, self.textOverrides, self.displayOverrides = {}, {}, {}, {}, {}
    wipe(self.composed)
    self.keyList = nil
end

-- ----------------------------------------------------------------------------
-- 4. Factory & Namespace Attachment
-- ----------------------------------------------------------------------------
local StoreBase = {}

--- Creates and registers a store.
--- def: name, kind (shown in "Unknown <kind> <key>"), description, fields, exempt,
---      liveName (Live kind for the label, or function(key, record) returning one),
---      existsKind (Live kind for the existence check),
---      live (field -> function(key) for live fields)
function StoreBase:New(def)
    local store = setmetatable({
        name = def.name,
        kind = def.kind,
        description = def.description,
        fields = DataStore.Schema:BuildFields(def.fields, def.exempt),
        liveName = def.liveName,
        existsKind = def.existsKind,
        live = def.live,
        base = {}, overrides = {}, texts = {}, textOverrides = {}, composed = {},
    }, Store)
    DataStore:RegisterStore(store)
    return store
end

StoreBase.Store = Store
DataStore.StoreBase = StoreBase
