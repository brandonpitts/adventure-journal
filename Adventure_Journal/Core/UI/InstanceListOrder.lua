-- ============================================================================
-- Adventure Journal - Core/UI/InstanceListOrder.lua
-- The order of an instance list: its instances filtered by the search box,
-- sorted by the list's sort setting (level, name or group size), and grouped
-- under headers by the template's `listGroups` (raids by tier).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local sort = table.sort

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- List order: by the top of the level range, then the bottom, then name
local function compareByLevel(a, b)
    local maxA, maxB = a.maxLevel or 0, b.maxLevel or 0
    if maxA ~= maxB then
        return maxA < maxB
    end
    local minA, minB = a.minLevel or 0, b.minLevel or 0
    if minA ~= minB then
        return minA < minB
    end
    return (a.name or "") < (b.name or "")
end

-- Highest level range first; equal ranges stay A-Z
local function compareByLevelDesc(a, b)
    local maxA, maxB = a.maxLevel or 0, b.maxLevel or 0
    if maxA ~= maxB then
        return maxA > maxB
    end
    local minA, minB = a.minLevel or 0, b.minLevel or 0
    if minA ~= minB then
        return minA > minB
    end
    return (a.name or "") < (b.name or "")
end

local function compareByName(a, b)
    return (a.name or "") < (b.name or "")
end

-- By group size, smallest first; equal sizes A-Z
local function compareBySize(a, b)
    local sizeA, sizeB = a.maxPlayers or 0, b.maxPlayers or 0
    if sizeA ~= sizeB then
        return sizeA < sizeB
    end
    return (a.name or "") < (b.name or "")
end

-- Largest group first; equal sizes A-Z
local function compareBySizeDesc(a, b)
    local sizeA, sizeB = a.maxPlayers or 0, b.maxPlayers or 0
    if sizeA ~= sizeB then
        return sizeA > sizeB
    end
    return (a.name or "") < (b.name or "")
end

local COMPARE = {
    alphabetical = compareByName, name = compareByName, levelDesc = compareByLevelDesc,
    sizeAsc = compareBySize, sizeDesc = compareBySizeDesc,
}

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local InstanceListOrder = {}

--- The list's instances of `instanceType`, filtered by the search box and sorted ("level", "levelDesc",
--- "alphabetical", "sizeAsc" or "sizeDesc").
function InstanceListOrder:Filtered(instanceType, searchQuery, sortOrder)
    local Access = ns.Data.InstanceAccess
    local results = {}
    for _, dungeon in ipairs(Access:GetInstanceList(instanceType)) do
        if Access:InstanceMatches(dungeon, searchQuery) then
            results[#results + 1] = dungeon
        end
    end
    sort(results, COMPARE[sortOrder] or compareByLevel)
    return results
end

--- `instances` (sorted) in sections by the template's `listGroups` field, lowest value first, each titled with
--- its header text; those without the field last, untitled. Without grouping, one untitled section.
function InstanceListOrder:Grouped(template, instances, isOn)
    local groups = template.listGroups
    if not (groups and isOn) then
        return { { entries = instances } }
    end
    local byValue, values, rest = {}, {}, {}
    for _, instance in ipairs(instances) do
        local value = instance[groups.field]
        if value == nil then
            rest[#rest + 1] = instance
        else
            if not byValue[value] then
                byValue[value] = {}
                values[#values + 1] = value
            end
            local list = byValue[value]
            list[#list + 1] = instance
        end
    end
    sort(values)
    local sections = {}
    for i, value in ipairs(values) do
        sections[i] = { title = ns.Templates:Text(template, groups.text, value), entries = byValue[value] }
    end
    sections[#sections + 1] = { entries = rest }
    return sections
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.InstanceListOrder = InstanceListOrder
