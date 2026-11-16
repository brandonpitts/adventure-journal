-- ============================================================================
-- Utility_MapIcons - Data/ZoneLevels.lua
-- Canonical zone level brackets and fishing skill requirement metadata.
-- ============================================================================
local addonName, ns = ...

local ZoneLevels = {
    -- Eastern Kingdoms
    [1416] = { minLevel = 30, maxLevel = 40, fishing = "130" },             -- Alterac Mountains
    [1417] = { minLevel = 30, maxLevel = 40, fishing = "130" },             -- Arathi Highlands
    [1418] = { minLevel = 35, maxLevel = 45 },                              -- Badlands
    [1419] = { minLevel = 45, maxLevel = 55 },                              -- Blasted Lands
    [1428] = { minLevel = 50, maxLevel = 58, fishing = "330" },             -- Burning Steppes
    [1430] = { minLevel = 55, maxLevel = 60, fishing = "330" },             -- Deadwind Pass
    [1426] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Dun Morogh
    [1431] = { minLevel = 18, maxLevel = 30, fishing = "55" },              -- Duskwood
    [1423] = { minLevel = 53, maxLevel = 60, fishing = "330" },             -- Eastern Plaguelands
    [1429] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Elwynn Forest
    [1424] = { minLevel = 20, maxLevel = 30, fishing = "55" },              -- Hillsbrad Foothills
    [1455] = { fishing = "1" },                                             -- Ironforge
    [1432] = { minLevel = 10, maxLevel = 20, fishing = "1" },               -- Loch Modan
    [1433] = { minLevel = 15, maxLevel = 25, fishing = "55" },              -- Redridge Mountains
    [1427] = { minLevel = 43, maxLevel = 50 },                              -- Searing Gorge
    [1421] = { minLevel = 10, maxLevel = 20, fishing = "1" },               -- Silverpine Forest
    [1453] = { fishing = "1" },                                             -- Stormwind City
    [1434] = { minLevel = 30, maxLevel = 45, fishing = "130 - 205" },        -- Stranglethorn Vale
    [1435] = { minLevel = 35, maxLevel = 45, fishing = "130" },             -- Swamp of Sorrows
    [1425] = { minLevel = 40, maxLevel = 50, fishing = "205" },             -- The Hinterlands
    [1420] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Tirisfal Glades
    [1458] = { fishing = "1" },                                             -- Undercity
    [1436] = { minLevel = 10, maxLevel = 20, fishing = "1" },               -- Westfall
    [1422] = { minLevel = 51, maxLevel = 58, fishing = "205" },             -- Western Plaguelands
    [1437] = { minLevel = 20, maxLevel = 30, fishing = "55" },              -- Wetlands

    -- Kalimdor
    [1440] = { minLevel = 18, maxLevel = 30, fishing = "55" },              -- Ashenvale
    [1447] = { minLevel = 45, maxLevel = 55, fishing = "205 - 330" },        -- Azshara
    [1439] = { minLevel = 10, maxLevel = 20, fishing = "1" },               -- Darkshore
    [1457] = { fishing = "1" },                                             -- Darnassus
    [1443] = { minLevel = 30, maxLevel = 40, fishing = "130" },             -- Desolace
    [1411] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Durotar
    [1445] = { minLevel = 35, maxLevel = 45, fishing = "130" },             -- Dustwallow Marsh
    [1448] = { minLevel = 48, maxLevel = 55, fishing = "205" },             -- Felwood
    [1444] = { minLevel = 40, maxLevel = 50, fishing = "205 - 330" },        -- Feralas
    [1450] = { fishing = "205" },                                           -- Moonglade
    [1412] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Mulgore
    [1454] = { fishing = "1" },                                             -- Orgrimmar
    [1451] = { minLevel = 55, maxLevel = 60, fishing = "330" },             -- Silithus
    [1442] = { minLevel = 15, maxLevel = 27, fishing = "55" },              -- Stonetalon Mountains
    [1446] = { minLevel = 40, maxLevel = 50, fishing = "205" },             -- Tanaris
    [1438] = { minLevel = 1,  maxLevel = 10, fishing = "1" },               -- Teldrassil
    [1413] = { minLevel = 10, maxLevel = 25, fishing = "1" },               -- The Barrens
    [1441] = { minLevel = 25, maxLevel = 35, fishing = "130" },             -- Thousand Needles
    [1456] = { fishing = "1" },                                             -- Thunder Bluff
    [1449] = { minLevel = 48, maxLevel = 55, fishing = "205" },             -- Un'Goro Crater
    [1452] = { minLevel = 55, maxLevel = 60, fishing = "330" },             -- Winterspring

    -- WoW Forever
    [2482] = { minLevel = 60, maxLevel = 60 },                              -- Hyjal
    [2521] = { minLevel = 1,  maxLevel = 12 },                              -- Zephras Isle
    [2548] = { minLevel = 35, maxLevel = 45 },                              -- Riverglades
    [2652] = { minLevel = 35, maxLevel = 45 },                              -- Shen'dralas
}

ns.ZoneLevels = ZoneLevels
