-- ============================================================================
-- Adventure Journal - Core/UI/InstanceTooltip.lua
-- The tooltip of an instance or wing card (the instance list, a dungeon's
-- wing page): its name, levels and location (a wing adds "Dungeon Wing"), its
-- lore, an instance's wings, and the click hints.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local concat = table.concat
local GameTooltip = GameTooltip

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local TITLE_COLOR = { 1.0, 0.82, 0.0 }
local META_COLOR = { 0.90, 0.82, 0.62 }
local LORE_COLOR = { 0.85, 0.85, 0.85 }
local HINT_COLOR = { 0.25, 0.92, 0.32 }

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local InstanceTooltip = {}

--- Fills GameTooltip (already owned) for `view` (an instance or wing view) from `template`'s text.
--- "Level 60 • Dustwallow Marsh" (a list whose cards show the group size adds it after the level; a wing adds
--- "Dungeon Wing" last). The favorites hint shows when the template has favorites.
function InstanceTooltip:Fill(template, view)
    local T = ns.Templates
    GameTooltip:AddLine(view.fullName or view.name, TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
    local parts = { T:Text(template, "listLevel", view.level or "?") }
    if template.listInfo == "size" and view.maxPlayers then
        parts[#parts + 1] = T:Text(template, "size", view.maxPlayers)
    end
    if view.location then
        parts[#parts + 1] = view.location
    end
    if view.wingKey then
        parts[#parts + 1] = T:Text(template, "wingLabel")
    end
    GameTooltip:AddLine(concat(parts, " • "), META_COLOR[1], META_COLOR[2], META_COLOR[3])
    if view.description and view.description ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(view.description, LORE_COLOR[1], LORE_COLOR[2], LORE_COLOR[3], true)
    end
    -- An instance with wings lists them in order, each with its levels
    if view.wingCount and view.wingCount > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T:Text(template, "listWings"), TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
        for _, wing in ipairs(ns.Data.InstanceAccess:GetWings(view)) do
            GameTooltip:AddDoubleLine(wing.name, wing.level and T:Text(template, "listLevel", wing.level) or "",
                0.95, 0.95, 0.95, META_COLOR[1], META_COLOR[2], META_COLOR[3])
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T:Text(template, "listOpen"), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    local Favorites = ns.UI.InstanceFavorites
    if Favorites:IsOn(template) then
        local key = Favorites:IsFavorite(template, view) and "favoriteRemove" or "favoriteAdd"
        GameTooltip:AddLine(T:Text(template, key), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.InstanceTooltip = InstanceTooltip
