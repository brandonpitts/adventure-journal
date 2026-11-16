-- ============================================================================
-- Utility_MapIcons - Data/FlightPaths.lua
-- Flight master taxi node coordinates, factions, and location names.
-- ============================================================================
local addonName, ns = ...

local FlightPaths = {
    -- Eastern Kingdoms
    [1417] = { -- Arathi Highlands
        { faction = "Alliance", x = 45.8, y = 46.1, name = "Refuge Pointe, Arathi" },
        { faction = "Horde",    x = 73.1, y = 32.6, name = "Hammerfall, Arathi" },
    },
    [1418] = { -- Badlands
        { faction = "Horde",    x = 4.1,  y = 44.9, name = "Kargath, Badlands" },
    },
    [1419] = { -- Blasted Lands
        { faction = "Alliance", x = 65.5, y = 24.4, name = "Nethergarde Keep, Blasted Lands" },
    },
    [1421] = { -- Silverpine Forest
        { faction = "Horde",    x = 45.6, y = 42.4, name = "The Sepulcher, Silverpine Forest" },
    },
    [1422] = { -- Western Plaguelands
        { faction = "Alliance", x = 42.9, y = 85.0, name = "Chillwind Camp, Western Plaguelands" },
    },
    [1423] = { -- Eastern Plaguelands
        { faction = "Alliance", x = 71.7, y = 49.6, name = "Light's Hope Chapel, Eastern Plaguelands" },
        { faction = "Horde",    x = 70.4, y = 47.6, name = "Light's Hope Chapel, Eastern Plaguelands" },
    },
    [1424] = { -- Hillsbrad Foothills
        { faction = "Alliance", x = 49.4, y = 52.1, name = "Southshore, Hillsbrad" },
        { faction = "Horde",    x = 60.2, y = 18.8, name = "Tarren Mill, Hillsbrad" },
    },
    [1425] = { -- The Hinterlands
        { faction = "Alliance", x = 11.1, y = 46.1, name = "Aerie Peak, The Hinterlands" },
        { faction = "Horde",    x = 81.7, y = 81.9, name = "Revantusk Village, The Hinterlands" },
    },
    [1427] = { -- Searing Gorge
        { faction = "Alliance", x = 37.9, y = 30.4, name = "Thorium Point, Searing Gorge" },
        { faction = "Horde",    x = 34.8, y = 30.6, name = "Thorium Point, Searing Gorge" },
    },
    [1428] = { -- Burning Steppes
        { faction = "Alliance", x = 84.4, y = 68.3, name = "Morgan's Vigil, Burning Steppes" },
        { faction = "Horde",    x = 65.6, y = 24.2, name = "Flame Crest, Burning Steppes" },
    },
    [1431] = { -- Duskwood
        { faction = "Alliance", x = 77.6, y = 44.4, name = "Darkshire, Duskwood" },
    },
    [1432] = { -- Loch Modan
        { faction = "Alliance", x = 33.9, y = 50.8, name = "Thelsamar, Loch Modan" },
    },
    [1433] = { -- Redridge Mountains
        { faction = "Alliance", x = 25.3, y = 59.0, name = "Lakeshire, Redridge" },
    },
    [1434] = { -- Stranglethorn Vale
        { faction = "Alliance", x = 27.5, y = 77.7, name = "Booty Bay, Stranglethorn" },
        { faction = "Horde",    x = 26.8, y = 77.0, name = "Booty Bay, Stranglethorn" },
        { faction = "Horde",    x = 32.5, y = 29.3, name = "Grom'gol, Stranglethorn" },
    },
    [1435] = { -- Swamp of Sorrows
        { faction = "Horde",    x = 46.1, y = 54.7, name = "Stonard, Swamp of Sorrows" },
    },
    [1436] = { -- Westfall
        { faction = "Alliance", x = 56.6, y = 52.7, name = "Sentinel Hill, Westfall" },
    },
    [1437] = { -- Wetlands
        { faction = "Alliance", x = 9.5,  y = 59.7, name = "Menethil Harbor, Wetlands" },
    },
    [1453] = { -- Stormwind City
        { faction = "Alliance", x = 71.6, y = 72.3, name = "Stormwind, Elwynn" },
    },
    [1455] = { -- Ironforge
        { faction = "Alliance", x = 55.9, y = 47.9, name = "Ironforge, Dun Morogh" },
    },
    [1458] = { -- Undercity
        { faction = "Horde",    x = 63.1, y = 48.3, name = "Undercity, Tirisfal" },
    },

    -- Kalimdor
    [1411] = { -- Durotar
        { faction = "Horde",    x = 45.3, y = 63.7, name = "Orgrimmar, Durotar" },
    },
    [1412] = { -- Mulgore
        { faction = "Horde",    x = 46.7, y = 49.9, name = "Thunder Bluff, Mulgore" },
    },
    [1413] = { -- The Barrens
        { faction = "Horde",    x = 44.5, y = 59.1, name = "Camp Taurajo, The Barrens" },
        { faction = "Horde",    x = 51.5, y = 30.4, name = "Crossroads, The Barrens" },
        { faction = "Neutral",  x = 63.1, y = 37.1, name = "Ratchet, The Barrens" },
    },
    [1438] = { -- Teldrassil
        { faction = "Alliance", x = 58.4, y = 93.9, name = "Rut'theran Village, Teldrassil" },
    },
    [1439] = { -- Darkshore
        { faction = "Alliance", x = 36.4, y = 45.6, name = "Auberdine, Darkshore" },
    },
    [1440] = { -- Ashenvale
        { faction = "Alliance", x = 34.5, y = 48.0, name = "Astranaar, Ashenvale" },
        { faction = "Horde",    x = 73.3, y = 61.7, name = "Splintertree Post, Ashenvale" },
        { faction = "Horde",    x = 12.2, y = 33.8, name = "Zoram'gar Outpost, Ashenvale" },
    },
    [1441] = { -- Thousand Needles
        { faction = "Horde",    x = 45.0, y = 49.1, name = "Freewind Post, Thousand Needles" },
    },
    [1442] = { -- Stonetalon Mountains
        { faction = "Alliance", x = 36.5, y = 7.2,  name = "Stonetalon Peak, Stonetalon Mountains" },
        { faction = "Horde",    x = 45.2, y = 59.9, name = "Sun Rock Retreat, Stonetalon Mountains" },
    },
    [1443] = { -- Desolace
        { faction = "Alliance", x = 64.7, y = 10.4, name = "Nijel's Point, Desolace" },
        { faction = "Horde",    x = 21.6, y = 74.0, name = "Shadowprey Village, Desolace" },
    },
    [1444] = { -- Feralas
        { faction = "Alliance", x = 30.3, y = 43.3, name = "Feathermoon, Feralas" },
        { faction = "Alliance", x = 89.5, y = 45.9, name = "Thalanaar, Feralas" },
        { faction = "Horde",    x = 75.4, y = 44.3, name = "Camp Mojache, Feralas" },
    },
    [1445] = { -- Dustwallow Marsh
        { faction = "Alliance", x = 67.5, y = 51.2, name = "Theramore, Dustwallow Marsh" },
        { faction = "Horde",    x = 35.6, y = 31.8, name = "Brackenwall Village, Dustwallow Marsh" },
    },
    [1446] = { -- Tanaris
        { faction = "Alliance", x = 51.0, y = 29.3, name = "Gadgetzan, Tanaris" },
        { faction = "Horde",    x = 51.6, y = 25.5, name = "Gadgetzan, Tanaris" },
    },
    [1447] = { -- Azshara
        { faction = "Alliance", x = 11.9, y = 77.5, name = "Talrendis Point, Azshara" },
        { faction = "Horde",    x = 22.0, y = 49.7, name = "Valormok, Azshara" },
    },
    [1448] = { -- Felwood
        { faction = "Alliance", x = 62.5, y = 24.2, name = "Talonbranch Glade, Felwood" },
        { faction = "Horde",    x = 34.4, y = 53.9, name = "Bloodvenom Post, Felwood" },
    },
    [1449] = { -- Un'Goro Crater
        { faction = "Neutral",  x = 45.3, y = 6.0,  name = "Marshal's Refuge, Un'Goro Crater" },
    },
    [1450] = { -- Moonglade
        { faction = "Alliance", x = 47.9, y = 67.1, name = "Moonglade" },
        { faction = "Horde",    x = 32.2, y = 66.3, name = "Moonglade" },
    },
    [1451] = { -- Silithus
        { faction = "Alliance", x = 50.7, y = 34.6, name = "Cenarion Hold, Silithus" },
        { faction = "Horde",    x = 48.8, y = 36.7, name = "Cenarion Hold, Silithus" },
    },
    [1452] = { -- Winterspring
        { faction = "Alliance", x = 62.3, y = 36.6, name = "Everlook, Winterspring" },
        { faction = "Horde",    x = 60.5, y = 36.3, name = "Everlook, Winterspring" },
    },

    -- WoW Forever
    [2482] = { -- Mount Hyjal
        { faction = "Neutral",  x = 68.6, y = 44.1, name = "Summit of Eternity, Mount Hyjal" },
        { faction = "Neutral",  x = 55.1, y = 82.5, name = "Tainted Foothills, Mount Hyjal" },
    },
    [2548] = { -- Riverglades
        { faction = "Alliance", x = 60.6, y = 81.6, name = "Farholde Keep, Riverglades" },
        { faction = "Horde",    x = 59.6, y = 45.1, name = "Rog'mar, Riverglades" },
    },
}

ns.FlightPaths = FlightPaths
