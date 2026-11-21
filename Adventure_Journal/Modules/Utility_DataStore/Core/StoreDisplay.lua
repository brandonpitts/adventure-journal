-- ============================================================================
-- Utility_DataStore - Core/StoreDisplay.lua
-- Display overrides for every store: hand-kept entries that change how a
-- record is shown, never what it is. Each
-- store's DisplayOverrides.lua sets them; sync scripts never touch it.
--   { key = <key>, kind = "note" | "replace" | "hide" | "banner" | "place" | "layout",
--     target = "<slot or slot.field>", value = <what the kind needs>, note = "<why>" }
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local DataStore = ns.DataStore
local EMPTY = {}

-- The kinds a display override can be
local KINDS = { note = true, replace = true, hide = true, banner = true, place = true, layout = true }

-- ----------------------------------------------------------------------------
-- 3. Store Methods
-- ----------------------------------------------------------------------------
local Store = DataStore.StoreBase.Store

--- Sets the store's display overrides (a list of entries; see the file header).
function Store:SetDisplayOverrides(entries)
    self.displayOverrides = {}
    for _, entry in ipairs(entries or EMPTY) do
        local list = self.displayOverrides[entry.key]
        if not list then
            list = {}
            self.displayOverrides[entry.key] = list
        end
        list[#list + 1] = entry
    end
end

--- The display overrides for `key` (a list, empty when there are none), or only those of `kind`.
function Store:GetDisplayOverrides(key, kind)
    local list = DataStore:IsEnabled() and self.displayOverrides and self.displayOverrides[key] or EMPTY
    if not kind then
        return list
    end
    local matching = {}
    for _, entry in ipairs(list) do
        if entry.kind == kind then
            matching[#matching + 1] = entry
        end
    end
    return matching
end

--- The first display override for `key` of `kind` on `target`, or nil.
function Store:GetDisplayOverride(key, kind, target)
    for _, entry in ipairs(self:GetDisplayOverrides(key, kind)) do
        if entry.target == target then
            return entry
        end
    end
end

--- Every entry in the store that breaks the format: { { key, problem } }.
function Store:CheckDisplayOverrides()
    local problems = {}
    for key, list in pairs(self.displayOverrides or EMPTY) do
        for _, entry in ipairs(list) do
            if not KINDS[entry.kind] then
                problems[#problems + 1] = { key = key, problem = "unknown kind " .. tostring(entry.kind) }
            elseif type(entry.target) ~= "string" or entry.target == "" then
                problems[#problems + 1] = { key = key, problem = "no target" }
            elseif type(entry.note) ~= "string" or entry.note == "" then
                problems[#problems + 1] = { key = key, problem = "no note" }
            end
        end
    end
    return problems
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
DataStore.DisplayKinds = KINDS
