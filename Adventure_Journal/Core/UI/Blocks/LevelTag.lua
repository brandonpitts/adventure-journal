-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/LevelTag.lua
-- Level text and its color: an encounter's tag ("Lv 30", "Rare 30",
-- "Event ??", "Zone"), and levels written inline in a color code. Difficulty
-- colors come from LevelColors; with them turned off, each kind of tag keeps
-- its own fixed color.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local floor = math.floor
local format = string.format

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Tag colors when difficulty colors are off
local PLAIN = {
    event = { 1.0, 0.75, 0.30 },
    rare = { 0.75, 0.85, 0.95 },
    level = { 0.80, 0.72, 0.55 },
}
local ZONE_COLOR = { 0.80, 0.72, 0.55 }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local LevelTag = {}

--- An encounter's tag text and color.
--- @param boss table an encounter view (or the Zone Drops entry)
--- @param useDifficultyColor boolean
--- @return string text, number r, number g, number b
function LevelTag:ForEncounter(boss, useDifficultyColor)
    if boss.isZone then
        return "Zone", ZONE_COLOR[1], ZONE_COLOR[2], ZONE_COLOR[3]
    end
    local level = boss.level or "??"
    local text, kind
    if boss.isEvent then
        text, kind = "Event ??", "event"
    elseif boss.rare and not boss.isChallenge then
        text, kind = "Rare " .. level, "rare"
    else
        text, kind = "Lv " .. level, "level"
    end
    if useDifficultyColor then
        local r, g, b = ns.LevelColors:ForText(level)
        return text, r, g, b
    end
    local c = PLAIN[kind]
    return text, c[1], c[2], c[3]
end

--- Sets a font string to an encounter's tag.
function LevelTag:ApplyEncounter(fontString, boss, useDifficultyColor)
    local text, r, g, b = self:ForEncounter(boss, useDifficultyColor)
    fontString:SetText(text)
    fontString:SetTextColor(r, g, b)
end

--- An instance's (or wing's) level range colored for the player.
--- @param view table|nil an instance or wing view
--- @return number r, number g, number b
function LevelTag:InstanceColor(view)
    if view and view.minLevel then
        return ns.LevelColors:ForRange(view.minLevel, view.maxLevel)
    end
    return ns.LevelColors:ForText(view and view.level)
end

--- `text` wrapped in a color code for r, g, b (0-1).
function LevelTag:Colorize(text, r, g, b)
    return format("|cff%02x%02x%02x%s|r", floor(r * 255), floor(g * 255), floor(b * 255), text)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.LevelTag = LevelTag
