-- ============================================================================
-- Journal_Dungeons - Data/Items/Items_Overrides.lua
-- Manual and server-specific item overrides and additions.
-- This file is never modified or overwritten by automated sync scripts.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

ns.ItemsOverrides = {
    -- Structure:
    -- [dungeonID] = {
    --     [bossIndexOrName] = { itemID, itemID, ... },
    --     ["trash"] = { itemID, ... },
    -- },
}

-- ----------------------------------------------------------------------------
-- Item Category Overrides
-- Maps specific item IDs to explicit categories:
-- "QUEST"       = Quest Items & Keys
-- "EQUIPMENT"   = Equippable Weapons, Armor, Jewelry, Trinkets, Off-hands
-- "RECIPE"      = Tradeskill Crafting Recipes, Patterns, Plans, Schematics
-- "COLLECTIBLE" = Mounts, Companion Pets, Tabards
-- "MISC"        = Consumables, Reagents, Skill Books, Other
-- ----------------------------------------------------------------------------
ns.ItemCategoryOverrides = {
    -- ------------------------------------------------------------------------
    -- Zul'Farrak
    -- ------------------------------------------------------------------------
    [10660] = "QUEST", -- First Mosh'aru Tablet (Theka the Martyr)
    [10661] = "QUEST", -- Second Mosh'aru Tablet (Hydromancer Velratha)
    [9471]  = "QUEST", -- Nekrum's Medallion (Nekrum Gutchewer)
    [8444]  = "QUEST", -- Executioner's Key (Sandfury Executioner)
    [8548]  = "QUEST", -- Divino-matic Rod (Sergeant Bly)
    [9523]  = "QUEST", -- Troll Temper (Sandarr Dunereaver / ZF Trolls)
    [9240]  = "QUEST", -- Mallet of Zul'Farrak
    [9241]  = "QUEST", -- Sacred Mallet

    -- ------------------------------------------------------------------------
    -- Sunken Temple (Temple of Atal'Hakkar)
    -- ------------------------------------------------------------------------
    [10454] = "QUEST", -- Essence of Eranikus (Shade of Eranikus)
    [20606] = "QUEST", -- Amber Voodoo Feather (Balcony Minibosses)
    [20607] = "QUEST", -- Blue Voodoo Feather (Balcony Minibosses)
    [20608] = "QUEST", -- Green Voodoo Feather (Balcony Minibosses)

    -- ------------------------------------------------------------------------
    -- Maraudon
    -- ------------------------------------------------------------------------
    [17757] = "QUEST", -- Amulet of Spirits (The Nameless Prophet)
    [17761] = "QUEST", -- Gem of the First Khan (Kolk)
    [17762] = "QUEST", -- Gem of the Second Khan (Gelk)
    [17763] = "QUEST", -- Gem of the Third Khan (Magra)
    [17764] = "QUEST", -- Gem of the Fourth Khan (Maraudos)
    [17765] = "QUEST", -- Gem of the Fifth Khan (Veng)

    -- ------------------------------------------------------------------------
    -- Blackrock Depths
    -- ------------------------------------------------------------------------
    [11000] = "QUEST", -- Shadowforge Key (Franclorn Forgewright)
    [11140] = "QUEST", -- Prison Cell Key (High Interrogator Gerstahn)
    [11197] = "QUEST", -- Dark Keeper Key (Dark Keepers)
    [11602] = "QUEST", -- Grim Guzzler Key (Plugger Spazzring)

    -- ------------------------------------------------------------------------
    -- Stratholme
    -- ------------------------------------------------------------------------
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

    -- ------------------------------------------------------------------------
    -- Scholomance
    -- ------------------------------------------------------------------------
    [12358] = "QUEST", -- Darkstone Tablet
    [13873] = "QUEST", -- Viewing Room Key (Doctor Theolen Krastinov)

    -- ------------------------------------------------------------------------
    -- Blackrock Spire
    -- ------------------------------------------------------------------------
    [22321] = "QUEST", -- Heart of Wyrmthalak (Overlord Wyrmthalak)

    -- ------------------------------------------------------------------------
    -- Classic Dungeons (Low-Mid Level)
    -- ------------------------------------------------------------------------
    [2874]  = "QUEST", -- An Unsent Letter (The Deadmines - Edwin VanCleef)
    [5397]  = "QUEST", -- Defias Gunpowder (The Deadmines)
    [5824]  = "QUEST", -- Tablet of Will (Blackfathom Deeps)
    [6893]  = "QUEST", -- Workshop Key (Gnomeregan - Electrocutioner 6000)
    [7146]  = "QUEST", -- The Scarlet Key (Scarlet Monastery - Doan's Strongbox)
    [10441] = "QUEST", -- Glowing Shard (Wailing Caverns - Mutanus the Devourer)
}
