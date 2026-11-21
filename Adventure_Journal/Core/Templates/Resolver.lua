-- ============================================================================
-- Adventure Journal - Core/Templates/Resolver.lua
-- Fills a template's slots: the field the slot names, from a view; a display
-- override (hide or replace) when the record has one for that slot; else the
-- slot's placeholder. `false` placeholders show nothing.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
---@return any
local function store(name)
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Resolver = {}

--- The value of `slotName` for `view` in `template`, and whether a `hide` override hides it. `storeName` and
--- `key` name the record whose display overrides apply (e.g. "InstanceStore", 389).
--- @return any value, boolean hidden
function Resolver:Slot(template, slotName, view, storeName, key)
    local slot = template.slots[slotName]
    local records = storeName and store(storeName)
    if records and key ~= nil then
        for _, entry in ipairs(records:GetDisplayOverrides(key)) do
            if entry.target == slotName then
                if entry.kind == "hide" then
                    return nil, true
                elseif entry.kind == "replace" then
                    return entry.value, false
                end
            end
        end
    end
    local value = slot.field and view and view[slot.field]
    if value == nil or value == "" then
        value = slot.placeholder
    end
    if value == false then
        value = nil
    end
    return value, false
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Templates.Resolver = Resolver
