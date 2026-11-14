-- ============================================================================
-- Journal_Base - Core/Data/Sources/Sources_Overrides.lua
-- Manual and server-specific encounter drop overrides, encounter alias merges,
-- and explicit item category overrides.
-- This file is never overwritten by automated sync scripts.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Manual Encounter Drop Overrides
-- ----------------------------------------------------------------------------
-- Structure:
-- [instanceID] = {
--     [encounterName] = { itemID, itemID, ... },
--     ["Zone Drops"]  = { itemID, ... },
-- }
local SourcesOverrides = {}

-- ----------------------------------------------------------------------------
-- 2. Canonical Encounter & Container Remapping Rules
-- ----------------------------------------------------------------------------
-- Normalizes variant encounter names and folds generic chests, urns, caches,
-- and trash keys into canonical encounter keys at index build time.
local EncounterAliases = {
    -- Seasonal & Multi-Boss Canonical Names
    ["Apothecary Hummel <Crown Chemical Co.>"] = "Crown Chemical Co.",
    ["Apothecary Hummel"]                      = "Crown Chemical Co.",
    ["Guzzler"]                                = "The Grim Guzzler",
    ["Chest of The Seven"]                     = "The Seven",
    ["Sothos and Jarien's Heirlooms"]          = "Jarien and Sothos",
    ["Sothos and Jarien"]                      = "Jarien and Sothos",

    -- Generic Containers & Trash Keys -> "Zone Drops"
    ["trash"]                                  = "Zone Drops",
    ["Trash"]                                  = "Zone Drops",
    ["Dark Coffer"]                            = "Zone Drops",
    ["Plans"]                                  = "Zone Drops",
    ["Baelog's Chest"]                         = "Zone Drops",
    ["Conspicuous Urn"]                        = "Zone Drops",
    ["Shadowforge Cache"]                      = "Zone Drops",
    ["Tablet of Will"]                         = "Zone Drops",
    ["Darkstone Tablet"]                       = "Zone Drops",
    ["Knot Thimblejack's Cache"]               = "Zone Drops",
}

-- Multi-target boss encounters where querying the composite encounter name
-- should also union drops from the individual sub-boss keys.
local CompositeEncounters = {
    ["The Lost Dwarves"]          = { "Baelog", "Olaf", 'Eric "The Swift"' },
    ["Dreamscythe & Weaver"]      = { "Dreamscythe", "Weaver" },
    ["Morphaz & Hazzas"]          = { "Morphaz", "Hazzas" },
    ["Marduk Blackpool & Vectus"] = { "Marduk Blackpool", "Vectus" },
    ["Crown Chemical Co."]        = { "Crown Chemical Co.", "Apothecary Hummel <Crown Chemical Co.>", "Apothecary Hummel" },
    ["The Grim Guzzler"]          = { "The Grim Guzzler", "Guzzler" },
    ["The Seven"]                 = { "The Seven", "Chest of The Seven" },
    ["Jarien and Sothos"]         = { "Jarien and Sothos", "Sothos and Jarien's Heirlooms", "Sothos and Jarien" },
    ["Zone Drops"]                = {
        "Zone Drops", "trash", "Trash", "Dark Coffer", "Plans",
        "Baelog's Chest", "Conspicuous Urn", "Shadowforge Cache",
        "Tablet of Will", "Darkstone Tablet", "Knot Thimblejack's Cache",
    },
}

-- ----------------------------------------------------------------------------
-- 3. Explicit Item Category Overrides
-- ----------------------------------------------------------------------------
-- Maps specific item IDs to explicit categories:
-- "QUEST"       = Quest Items & Keys
-- "EQUIPMENT"   = Equippable Weapons, Armor, Jewelry, Trinkets, Off-hands
-- "RECIPE"      = Tradeskill Crafting Recipes, Patterns, Plans, Schematics
-- "COLLECTIBLE" = Mounts, Companion Pets, Tabards
-- "MISC"        = Consumables, Reagents, Skill Books, Other
local ItemCategoryOverrides = {
    -- Zul'Farrak
    [10660] = "QUEST", -- First Mosh'aru Tablet (Theka the Martyr)
    [10661] = "QUEST", -- Second Mosh'aru Tablet (Hydromancer Velratha)
    [9471]  = "QUEST", -- Nekrum's Medallion (Nekrum Gutchewer)
    [8444]  = "QUEST", -- Executioner's Key (Sandfury Executioner)
    [8548]  = "QUEST", -- Divino-matic Rod (Sergeant Bly)
    [9523]  = "QUEST", -- Troll Temper (Sandarr Dunereaver / ZF Trolls)
    [9240]  = "QUEST", -- Mallet of Zul'Farrak
    [9241]  = "QUEST", -- Sacred Mallet

    -- Sunken Temple (Temple of Atal'Hakkar)
    [10454] = "QUEST", -- Essence of Eranikus (Shade of Eranikus)
    [20606] = "QUEST", -- Amber Voodoo Feather (Balcony Minibosses)
    [20607] = "QUEST", -- Blue Voodoo Feather (Balcony Minibosses)
    [20608] = "QUEST", -- Green Voodoo Feather (Balcony Minibosses)

    -- Maraudon
    [17757] = "QUEST", -- Amulet of Spirits (The Nameless Prophet)
    [17761] = "QUEST", -- Gem of the First Khan (Kolk)
    [17762] = "QUEST", -- Gem of the Second Khan (Gelk)
    [17763] = "QUEST", -- Gem of the Third Khan (Magra)
    [17764] = "QUEST", -- Gem of the Fourth Khan (Maraudos)
    [17765] = "QUEST", -- Gem of the Fifth Khan (Veng)

    -- Blackrock Depths
    [11000] = "QUEST", -- Shadowforge Key (Franclorn Forgewright)
    [11140] = "QUEST", -- Prison Cell Key (High Interrogator Gerstahn)
    [11197] = "QUEST", -- Dark Keeper Key (Dark Keepers)
    [11602] = "QUEST", -- Grim Guzzler Key (Plugger Spazzring)

    -- Stratholme
    [12382] = "QUEST", -- Key to the City (Magistrate Barthilas)
    [12845] = "QUEST", -- Medallion of Faith (Malor the Zealous)
    [13250] = "QUEST", -- Head of Balnazzar (Balnazzar)
    [13302] = "QUEST", -- Market Row Postbox Key
    [13303] = "QUEST", -- Crusaders' Square Postbox Key
    [13304] = "QUEST", -- Festival Lane Postbox Key
    [13305] = "QUEST", -- Elders' Square Postbox Key
    [13306] = "QUEST", -- King's Square Postbox Key
    [13307] = "QUEST", -- Fras Siabi's Postbox Key
    [22733] = "QUEST", -- Staff Head of Atiesh

    -- Scholomance
    [12358] = "QUEST", -- Darkstone Tablet
    [13873] = "QUEST", -- Viewing Room Key (Doctor Theolen Krastinov)

    -- Blackrock Spire
    [22321] = "QUEST", -- Heart of Wyrmthalak (Overlord Wyrmthalak)

    -- Classic Dungeons (Low-Mid Level)
    [2874]  = "QUEST", -- An Unsent Letter (The Deadmines - Edwin VanCleef)
    [5397]  = "QUEST", -- Defias Gunpowder (The Deadmines)
    [5824]  = "QUEST", -- Tablet of Will (Blackfathom Deeps)
    [6893]  = "QUEST", -- Workshop Key (Gnomeregan - Electrocutioner 6000)
    [7146]  = "QUEST", -- The Scarlet Key (Scarlet Monastery - Doan's Strongbox)
    [10441] = "QUEST", -- Glowing Shard (Wailing Caverns - Mutanus the Devourer)
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.SourcesOverrides = SourcesOverrides
ns.EncounterAliases = EncounterAliases
ns.CompositeEncounters = CompositeEncounters
ns.ItemCategoryOverrides = ItemCategoryOverrides
