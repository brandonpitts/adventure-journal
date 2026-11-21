-- ============================================================================
-- Adventure Journal - Core/Data/InstanceSearch.lua
-- How instances and their encounters answer the search box, and how an
-- instance's encounters sort into the boss list's groups (for the instance
-- data feed, InstanceAccess).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local strfind = string.find
local strlower = string.lower

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Access = ns.Data.InstanceAccess

--- An instance's encounters sorted into the boss list's groups, each in list order: `event`, `boss`, `rare`,
--- `minor` and `challenge`. `options`: `match(encounter)` keeps only matches; `isSearching` keeps kinds the
--- settings hide; `showMinor`, `showChallenges`, and `eventSetting` (the showEventBosses setting, checked against
--- active holidays); `hideIncomplete` leaves out encounters known only by name (`isIncomplete`).
function Access:GroupEncounters(view, options)
    local groups = { event = {}, boss = {}, rare = {}, minor = {}, challenge = {} }
    for _, boss in ipairs(self:GetEncounters(view)) do
        local hidden = boss.isIncomplete and options.hideIncomplete and not options.isSearching
        if not hidden and (not options.match or options.match(boss)) then
            local kind = (boss.isEvent and "event") or (boss.isChallenge and "challenge") or (boss.rare and "rare")
                or (boss.isMinor and "minor") or "boss"
            local shown = kind == "boss" or kind == "rare" or options.isSearching
                or (kind == "event" and ns.HolidayManager:ShouldShowEventBoss(boss, options.eventSetting))
                or (kind == "minor" and options.showMinor) or (kind == "challenge" and options.showChallenges)
            if shown then
                local group = groups[kind]
                group[#group + 1] = boss
            end
        end
    end
    return groups
end

--- Whether an encounter matches the search: its name (for a simple query) or any of its loot.
function Access:EncounterMatches(boss, query)
    local Search = ns.Search
    local parsed = Search:Parse(query)
    if parsed.isEmpty then
        return true
    end
    if not Search:IsMultiConstraint(parsed) and strfind(strlower(boss.name or ""), parsed.raw, 1, true) then
        return true
    end
    for _, itemID in ipairs(boss.itemIDs or {}) do
        if Search:ItemMatches(itemID, parsed) then
            return true
        end
    end
    return false
end

--- Whether a list entry matches the search: name, location, levels, aliases, a wing, an encounter or any loot.
function Access:InstanceMatches(view, query)
    local q = strlower(query or ""):match("^%s*(.-)%s*$")
    if q == "" then
        return true
    end
    for _, text in ipairs({ view.fullName, view.location, view.level }) do
        if text and strfind(strlower(text), q, 1, true) then
            return true
        end
    end
    for _, alias in ipairs(view.aliases or {}) do
        if strfind(strlower(alias), q, 1, true) then
            return true
        end
    end
    local targets = view.wingCount > 0 and self:GetWings(view) or { view }
    for _, target in ipairs(targets) do
        if target ~= view and self:InstanceMatches(target, query) then
            return true
        end
        for _, boss in ipairs(self:GetEncounters(target)) do
            if self:EncounterMatches(boss, query) then
                return true
            end
        end
        if self:EncounterMatches({ itemIDs = target.zoneItemIDs }, query) then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.Data.InstanceAccess)
