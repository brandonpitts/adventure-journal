-- ============================================================================
-- Adventure Journal - Core/Templates/Registry.lua
-- Template definitions: a page's text, sections, tabs and slots, kept apart
-- from the blocks that draw them. A
-- template can extend another and replace only what differs. Text is looked
-- up by key; "{noun}" and "{noun_lower}" in it become the template's noun
-- ("Dungeon", "Raid").
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local pairs = pairs
local type = type
local select = select
local tostring = tostring
local format = string.format
local gsub = string.gsub
local lower = string.lower

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local defs = {}

--- A copy of `base` with `over` laid on top: tables with keys merge, lists (and everything else) replace.
local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do
        out[k] = v
    end
    for k, v in pairs(over) do
        local isList = type(v) == "table" and v[1] ~= nil
        if type(v) == "table" and not isList and type(out[k]) == "table" then
            out[k] = merge(out[k], v)
        else
            out[k] = v
        end
    end
    return out
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Templates = {}

--- Registers template `name`. Returns the definition.
function Templates:Register(name, def)
    def.name = name
    defs[name] = def
    return def
end

--- Registers `name` as `baseName` with `def` laid on top (see `merge`).
function Templates:Extend(baseName, name, def)
    local merged = merge(defs[baseName], def)
    merged.base = baseName
    return self:Register(name, merged)
end

--- The template named `name`, or nil.
function Templates:Get(name)
    return defs[name]
end

--- Every registered template: name -> definition.
function Templates:All()
    return defs
end

--- The template's text for `key`, with its noun filled in and `...` formatted into it. A missing key shows as
--- "[key]" so the gap is visible (the offline test fails on it).
function Templates:Text(template, key, ...)
    return self:TextWithNoun(template, template.noun, key, ...)
end

--- As Text, with `noun` filled in instead of the template's own: a template shown inside another (the quest
--- group inside a dungeon book) speaks of its host ("inside the dungeon").
function Templates:TextWithNoun(template, noun, key, ...)
    local text = template.text[key]
    if not text then
        return "[" .. key .. "]"
    end
    noun = noun or ""
    text = gsub(gsub(text, "{noun_lower}", lower(noun)), "{noun}", noun)
    if select("#", ...) > 0 then
        return format(text, ...)
    end
    return text
end

--- Problems with template `name`: slots without a placeholder, sections without a kind, tabs without text.
--- Returns a list of strings (empty when it's sound).
function Templates:Check(name)
    local template, problems = defs[name], {}
    for slot, def in pairs(template.slots or {}) do
        if def.placeholder == nil then
            problems[#problems + 1] = name .. ": slot " .. slot .. " has no placeholder"
        end
    end
    for i, section in pairs(template.encounterSections or {}) do
        if not section.kind then
            problems[#problems + 1] = name .. ": encounter section " .. i .. " has no kind"
        end
    end
    for i, section in pairs(template.listSections or {}) do
        if not section.kind then
            problems[#problems + 1] = name .. ": list section " .. i .. " has no kind"
        end
    end
    for _, section in pairs(template.detailSections or {}) do
        if not (template.slots and template.slots["quest." .. section]) then
            problems[#problems + 1] = name .. ": detail section " .. tostring(section) .. " has no slot"
        end
    end
    if template.quests and not defs[template.quests] then
        problems[#problems + 1] = name .. ": quest template " .. tostring(template.quests) .. " doesn't exist"
    end
    for _, tab in pairs(template.tabs or {}) do
        if not (template.text and template.text[tab.title]) then
            problems[#problems + 1] = name .. ": tab " .. tostring(tab.key) .. " has no title text"
        end
    end
    return problems
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Templates = Templates
