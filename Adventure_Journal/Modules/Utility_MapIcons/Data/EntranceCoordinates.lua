-- ============================================================================
-- Utility_MapIcons - Data/EntranceCoordinates.lua
-- World Map entrance coordinates and metadata for Classic & WoW Forever dungeons.
-- Keyed by Blizzard UiMapID.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals
-- ----------------------------------------------------------------------------
local _G = _G

-- ----------------------------------------------------------------------------
-- 2. Entrance Coordinates Registry
-- ----------------------------------------------------------------------------
local EntranceCoordinates = {
    -- ------------------------------------------------------------------------
    -- Eastern Kingdoms
    -- ------------------------------------------------------------------------

    -- Tirisfal Glades (1420)
    [1420] = {
        {
            dungeonID = "ruins_of_lordaeron",
            name = "The Ruins of Lordaeron",
            kind = "Dungeon",
            x = 63.0,
            y = 68.0,
            minLevel = 15,
            maxLevel = 22,
        },
        {
            dungeonID = "sm_graveyard",
            name = "Scarlet Monastery",
            kind = "Dungeon",
            x = 82.6,
            y = 33.8,
            minLevel = 30,
            maxLevel = 45,
        },
    },

    -- Silverpine Forest (1421)
    [1421] = {
        {
            dungeonID = "shadowfang_keep",
            name = "Shadowfang Keep",
            kind = "Dungeon",
            x = 44.8,
            y = 67.8,
            minLevel = 20,
            maxLevel = 30,
        },
    },

    -- Alterac Mountains (1416)
    [1416] = {
        {
            dungeonID = "city_of_dalaran",
            name = "City of Dalaran",
            kind = "Dungeon",
            x = 8.5,
            y = 59.3,
            minLevel = 28,
            maxLevel = 35,
        },
    },

    -- Western Plaguelands (1422)
    [1422] = {
        {
            dungeonID = "scholomance",
            name = "Scholomance",
            kind = "Dungeon",
            x = 69.7,
            y = 73.2,
            minLevel = 58,
            maxLevel = 60,
        },
    },

    -- Eastern Plaguelands (1423)
    [1423] = {
        {
            dungeonID = "stratholme_living",
            name = "Stratholme (Main Gate)",
            kind = "Dungeon",
            x = 27.8,
            y = 11.6,
            minLevel = 58,
            maxLevel = 60,
        },
        {
            dungeonID = "stratholme_undead",
            name = "Stratholme (Service Gate)",
            kind = "Dungeon",
            x = 43.6,
            y = 19.5,
            minLevel = 58,
            maxLevel = 60,
        },
    },

    -- Dun Morogh (1426)
    [1426] = {
        {
            dungeonID = "gnomeregan",
            name = "Gnomeregan",
            kind = "Dungeon",
            x = 24.3,
            y = 39.8,
            minLevel = 29,
            maxLevel = 38,
        },
    },

    -- Ironforge (1455)
    [1455] = {
        {
            dungeonID = "hall_of_thanes",
            name = "Hall of Thanes",
            kind = "Dungeon",
            x = 45.0,
            y = 52.0,
            minLevel = 13,
            maxLevel = 20,
        },
    },

    -- Loch Modan (1432)
    [1432] = {
        {
            dungeonID = "the_drowned_city",
            name = "The Drowned City",
            kind = "Dungeon",
            x = 21.3,
            y = 27.8,
            minLevel = 35,
            maxLevel = 42,
        },
    },

    -- Wetlands (1437)
    [1437] = {
        {
            dungeonID = "excavation_site_wetlands",
            name = "Excavation Site: Wetlands",
            kind = "Dungeon",
            x = 47.8,
            y = 56.2,
            minLevel = 26,
            maxLevel = 33,
        },
    },

    -- Badlands (1418)
    [1418] = {
        {
            dungeonID = "uldaman",
            name = "Uldaman",
            kind = "Dungeon",
            x = 44.6,
            y = 12.1,
            minLevel = 41,
            maxLevel = 51,
        },
    },

    -- Searing Gorge (1427)
    [1427] = {
        {
            dungeonID = "blackrock_depths",
            name = "Blackrock Mountain",
            kind = "Dungeon",
            x = 34.8,
            y = 85.3,
            minLevel = 52,
            maxLevel = 60,
        },
    },

    -- Burning Steppes (1428)
    [1428] = {
        {
            dungeonID = "lower_blackrock_spire",
            name = "Lower Blackrock Spire",
            kind = "Dungeon",
            x = 29.4,
            y = 38.3,
            minLevel = 55,
            maxLevel = 60,
        },
        {
            dungeonID = "upper_blackrock_spire",
            name = "Upper Blackrock Spire",
            kind = "Dungeon",
            x = 29.4,
            y = 38.3,
            minLevel = 59,
            maxLevel = 60,
        },
    },

    -- Stormwind City (1453)
    [1453] = {
        {
            dungeonID = "the_stockade",
            name = "The Stockade",
            kind = "Dungeon",
            x = 52.4,
            y = 70.0,
            minLevel = 24,
            maxLevel = 32,
        },
    },

    -- Westfall (1436)
    [1436] = {
        {
            dungeonID = "the_deadmines",
            name = "The Deadmines",
            kind = "Dungeon",
            x = 42.5,
            y = 71.7,
            minLevel = 17,
            maxLevel = 26,
        },
    },

    -- Swamp of Sorrows (1435)
    [1435] = {
        {
            dungeonID = "sunken_temple",
            name = "Temple of Atal'Hakkar",
            kind = "Dungeon",
            x = 69.9,
            y = 53.6,
            minLevel = 50,
            maxLevel = 60,
        },
    },

    -- ------------------------------------------------------------------------
    -- Kalimdor
    -- ------------------------------------------------------------------------

    -- Orgrimmar (1454)
    [1454] = {
        {
            dungeonID = "ragefire_chasm",
            name = "Ragefire Chasm",
            kind = "Dungeon",
            x = 52.6,
            y = 49.0,
            minLevel = 13,
            maxLevel = 18,
        },
    },

    -- The Barrens (1413)
    [1413] = {
        {
            dungeonID = "wailing_caverns",
            name = "Wailing Caverns",
            kind = "Dungeon",
            x = 46.0,
            y = 36.4,
            minLevel = 15,
            maxLevel = 24,
        },
        {
            dungeonID = "razorfen_kraul",
            name = "Razorfen Kraul",
            kind = "Dungeon",
            x = 42.9,
            y = 90.2,
            minLevel = 29,
            maxLevel = 38,
        },
        {
            dungeonID = "razorfen_downs",
            name = "Razorfen Downs",
            kind = "Dungeon",
            x = 49.0,
            y = 93.9,
            minLevel = 37,
            maxLevel = 46,
        },
    },

    -- Ashenvale (1440)
    [1440] = {
        {
            dungeonID = "blackfathom_deeps",
            name = "Blackfathom Deeps",
            kind = "Dungeon",
            x = 14.5,
            y = 14.2,
            minLevel = 24,
            maxLevel = 32,
        },
    },

    -- Riverglades (2548)
    [2548] = {
        {
            dungeonID = "kroldok_stronghold",
            name = "Krol'dok Stronghold",
            kind = "Dungeon",
            x = 37.5,
            y = 37.3,
            minLevel = 40,
            maxLevel = 47,
        },
    },

    -- Desolace (1443)
    [1443] = {
        {
            dungeonID = "maraudon",
            name = "Maraudon",
            kind = "Dungeon",
            x = 29.1,
            y = 62.5,
            minLevel = 46,
            maxLevel = 55,
        },
    },

    -- Dustwallow Marsh (1445)
    [1445] = {
        {
            dungeonID = "alcaz_prison",
            name = "Alcaz Prison",
            kind = "Dungeon",
            x = 75.3,
            y = 14.1,
            minLevel = 48,
            maxLevel = 55,
        },
    },

    -- Tanaris (1446)
    [1446] = {
        {
            dungeonID = "zulfarrak",
            name = "Zul'Farrak",
            kind = "Dungeon",
            x = 38.7,
            y = 20.0,
            minLevel = 44,
            maxLevel = 54,
        },
    },

    -- Feralas (1444)
    [1444] = {
        {
            dungeonID = "dire_maul_north",
            name = "Dire Maul (North)",
            kind = "Dungeon",
            x = 62.5,
            y = 24.9,
            minLevel = 56,
            maxLevel = 60,
        },
        {
            dungeonID = "dire_maul_west",
            name = "Dire Maul (West)",
            kind = "Dungeon",
            x = 60.3,
            y = 30.2,
            minLevel = 56,
            maxLevel = 60,
        },
        {
            dungeonID = "dire_maul_east",
            name = "Dire Maul (East)",
            kind = "Dungeon",
            x = 64.8,
            y = 30.2,
            minLevel = 54,
            maxLevel = 60,
        },
    },

    -- Azshara (1447)
    [1447] = {
        {
            dungeonID = "blackmaw_hold",
            name = "Blackmaw Hold",
            kind = "Dungeon",
            x = 38.6,
            y = 33.2,
            minLevel = 55,
            maxLevel = 60,
        },
    },

    -- Un'Goro Crater (1449)
    [1449] = {
        {
            dungeonID = "shapers_terrace",
            name = "Shaper's Terrace",
            kind = "Dungeon",
            x = 48.1,
            y = 6.1,
            minLevel = 58,
            maxLevel = 60,
        },
    },
}

-- ----------------------------------------------------------------------------
-- 3. Namespace Attachment & Lookup Helpers
-- ----------------------------------------------------------------------------
ns.EntranceCoordinates = EntranceCoordinates

--- Finds entrance coordinates and metadata for a given dungeon ID.
--- @param dungeonID string
--- @return table|nil { uiMapID = number, x = number, y = number, name = string, kind = string, minLevel = number, maxLevel = number }
function ns.GetDungeonMapLocation(dungeonID)
    if not dungeonID then return nil end
    local target = dungeonID
    if target == "ragefire" then target = "ragefire_chasm" end
    if target == "ubrs" then target = "upper_blackrock_spire" end
    if target == "lbrs" then target = "lower_blackrock_spire" end
    for uiMapID, entries in pairs(EntranceCoordinates) do
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if entry.dungeonID == target or entry.dungeonID == dungeonID then
                    return {
                        uiMapID = uiMapID,
                        x = entry.x,
                        y = entry.y,
                        name = entry.name,
                        kind = entry.kind,
                        minLevel = entry.minLevel,
                        maxLevel = entry.maxLevel,
                    }
                end
            end
        end
    end
    return nil
end

if ns.Dungeons then
    ns.Dungeons.GetDungeonMapLocation = ns.GetDungeonMapLocation
end

if _G.JournalBase then
    _G.JournalBase.GetDungeonMapLocation = ns.GetDungeonMapLocation
end

_G.AdventureJournal_GetDungeonMapLocation = ns.GetDungeonMapLocation



