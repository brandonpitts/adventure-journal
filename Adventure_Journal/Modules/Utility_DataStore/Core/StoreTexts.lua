-- ============================================================================
-- Utility_DataStore - Core/StoreTexts.lua
-- Every store's free text: descriptions and other
-- texts, and hints aimed at one field. Base texts come from the migration and
-- syncs; hand-kept text overrides sit on top and correct or add to them.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local UnitFactionGroup = UnitFactionGroup
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local EMPTY = {}

-- Text overrides for one record that apply to the player's faction.
local function eachTextOverride(store, key)
    local list = store.textOverrides[key] or EMPTY
    local playerFaction = UnitFactionGroup("player")
    local i = 0
    return function()
        repeat
            i = i + 1
            local entry = list[i]
            if entry and (not entry.faction or entry.faction == playerFaction) then
                return entry
            end
        until entry == nil
    end
end

-- ----------------------------------------------------------------------------
-- 3. Store Text Calls (added to every store)
-- ----------------------------------------------------------------------------
local Store = DataStore.StoreBase.Store

--- Sets texts: key -> { description = { text, from }, hints = { { field, text, from } } }.
function Store:SetTexts(texts)
    self.texts = texts or {}
end

--- Sets hand-kept text overrides, a list like SetOverrides (section 9 format):
---   { key, text = "<kind>", value, type = "correction" }      replaces that text
---   { key, hint = "<field>", value, type = "correction" }     replaces every hint on that field
---   { key, hint = "<field>", value, type = "addition" }       adds a hint on that field
--- Optional: faction (applies to that faction only), from (default "manual"), note.
function Store:SetTextOverrides(entries)
    self.textOverrides = {}
    for _, entry in ipairs(entries or EMPTY) do
        local list = self.textOverrides[entry.key]
        if not list then
            list = {}
            self.textOverrides[entry.key] = list
        end
        list[#list + 1] = entry
    end
end

--- A text of one kind ("description", "objective", ...): its text, then where it came from.
--- A text override of that kind replaces the base text.
function Store:GetText(key, kind)
    if not DataStore:IsEnabled() then
        return nil
    end
    local text, from
    local entry = self.texts[key] and self.texts[key][kind]
    if entry then
        text, from = entry.text, entry.from
    end
    for override in eachTextOverride(self, key) do
        if override.text == kind then
            text, from = override.value, override.from or "manual"
        end
    end
    return text, from
end

--- Hints aimed at one field of a record (section 4.10), after text overrides. Always a list.
function Store:GetHints(key, field)
    local result = {}
    if not DataStore:IsEnabled() then
        return result
    end
    local hints = self.texts[key] and self.texts[key].hints
    for _, hint in ipairs(hints or EMPTY) do
        if hint.field == field then
            result[#result + 1] = hint
        end
    end
    for override in eachTextOverride(self, key) do
        if override.hint == field then
            local hint = { field = field, text = override.value, from = override.from or "manual" }
            if override.type == "correction" then
                result = { hint }
            else
                result[#result + 1] = hint
            end
        end
    end
    return result
end
