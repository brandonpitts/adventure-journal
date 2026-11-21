-- ============================================================================
-- Adventure Journal - Core/LevelColors.lua
-- Difficulty colors for levels and level ranges, from the game's own
-- GetRelativeDifficultyColor (Blizzard_FrameXMLUtil DifficultyUtil): red,
-- orange, yellow, green, grey by the player's level, with the game's own
-- thresholds. The one rule of ours: a range is compared at its level nearest
-- the player, so anything whose range the player is in reads yellow.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local tonumber = tonumber
local tostring = tostring
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitLevel = UnitLevel

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- A level the data doesn't know (no level given)
local UNKNOWN = { 0.92, 0.86, 0.70 }
-- Skull ("??") levels; the data stores them as -1
local SKULL_LEVEL = -1

local function playerLevel()
    return (UnitEffectiveLevel and UnitEffectiveLevel("player")) or (UnitLevel and UnitLevel("player")) or 1
end

local function unpackColor(color)
    if color then
        return color.r, color.g, color.b
    end
    return UNKNOWN[1], UNKNOWN[2], UNKNOWN[3]
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local LevelColors = {}

--- The color of `minLevel`-`maxLevel` for the player (`maxLevel` defaults to `minLevel`). A skull level is the
--- game's "impossible" red; a missing level is a neutral tan.
--- @param minLevel number|nil
--- @param maxLevel number|nil
--- @return number r, number g, number b
function LevelColors:ForRange(minLevel, maxLevel)
    if minLevel == SKULL_LEVEL or maxLevel == SKULL_LEVEL then
        return unpackColor(QuestDifficultyColors and QuestDifficultyColors.impossible)
    end
    if not minLevel then
        return UNKNOWN[1], UNKNOWN[2], UNKNOWN[3]
    end
    maxLevel = maxLevel or minLevel
    local player = playerLevel()
    local nearest = (player < minLevel and minLevel) or (player > maxLevel and maxLevel) or player
    if not GetRelativeDifficultyColor then
        return UNKNOWN[1], UNKNOWN[2], UNKNOWN[3]
    end
    return unpackColor(GetRelativeDifficultyColor(player, nearest))
end

--- The color of one level for the player.
--- @param level number|nil
--- @return number r, number g, number b
function LevelColors:ForLevel(level)
    return self:ForRange(level, level)
end

--- The color of a level written as text: "30", "30-38" (spaces allowed) or "??".
--- @param text string|number|nil
--- @return number r, number g, number b
function LevelColors:ForText(text)
    text = text and tostring(text)
    if not text or text == "" then
        return UNKNOWN[1], UNKNOWN[2], UNKNOWN[3]
    end
    if text:find("%?%?") then
        return self:ForRange(SKULL_LEVEL)
    end
    local low, high = text:match("^%s*(%d+)%s*%-%s*(%d+)%s*$")
    if low then
        return self:ForRange(tonumber(low), tonumber(high))
    end
    return self:ForLevel(tonumber(text:match("%d+")))
end

--- `r, g, b` as a "rrggbb" hex string for |c color codes.
--- @return string
function LevelColors:ToHex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.LevelColors = LevelColors
