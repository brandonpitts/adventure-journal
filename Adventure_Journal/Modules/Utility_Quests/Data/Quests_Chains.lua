-- ============================================================================
-- Utility_Quests - Data/Quests_Chains.lua
-- Prerequisite unlock chains for dungeon and world quests.
-- ============================================================================
local addonName, parent = ...
parent.Utility_Quests = parent.Utility_Quests or {}
local ns = parent.Utility_Quests

ns.QuestsChains = {
    -- These lists are intentionally "required to unlock" lists, not merely
    -- Wowhead storyline/series lists. Optional breadcrumbs are excluded.

    -- Hall of Thanes.
    -- Underground Map is the actual prerequisite for Old Ironforge Incursion.
    [96393] = {
        { id = 96391, name = "Underground Map" },
    },

    -- Wailing Caverns.
    -- Smart Drinks is only offered after completing Raptor Horns.
    [1491] = {
        { id = 865, name = "Raptor Horns" },
    },

    -- Required path to unlock Leaders of the Fang:
    -- Forgotten Pools -> Stagnant Oasis -> Altered Beings ->
    -- Hamuul Runetotem -> Nara Wildmane -> Leaders of the Fang.
    -- "The Barrens Oases" is an optional breadcrumb/alternate entry into the
    -- oasis chain, so it is deliberately not shown as required.
    [914] = {
        { id = 870, name = "The Forgotten Pools" },
        { id = 877, name = "The Stagnant Oasis" },
        { id = 880, name = "Altered Beings" },
        { id = 1489, name = "Hamuul Runetotem" },
        { id = 1490, name = "Nara Wildmane" },
    },

    -- Deadmines.
    -- Red Silk Bandanas has two gates: Red Leather Bandanas and progression
    -- through the Defias Brotherhood chain far enough to unlock the final
    -- VanCleef stage.
    [214] = {
        { id = 65, name = "The Defias Brotherhood" },
        { id = 132, name = "The Defias Brotherhood" },
        { id = 135, name = "The Defias Brotherhood" },
        { id = 141, name = "The Defias Brotherhood" },
        { id = 142, name = "The Defias Brotherhood" },
        { id = 155, name = "The Defias Brotherhood" },
    },

    -- Speak with Shoni is a breadcrumb into Underground Assault, not a hard
    -- prerequisite; Shoni offers Underground Assault directly.

    -- Final VanCleef quest: all earlier Defias Brotherhood steps are required.
    [166] = {
        { id = 65, name = "The Defias Brotherhood" },
        { id = 132, name = "The Defias Brotherhood" },
        { id = 135, name = "The Defias Brotherhood" },
        { id = 141, name = "The Defias Brotherhood" },
        { id = 142, name = "The Defias Brotherhood" },
        { id = 155, name = "The Defias Brotherhood" },
    },

    -- Forever's Toxic Soil storyline is sequential; every prior step below is
    -- required before the dungeon step Destruction in Deadmines (92753).
    [92753] = {
        { id = 92742, name = "Testing the Wells" },
        { id = 92744, name = "Murloc Gills" },
        { id = 92745, name = "The State of the Mines" },
        { id = 92747, name = "Moonbrook Espionage" },
        { id = 92748, name = "Explosive Consultation" },
        { id = 92749, name = "A Dynamite Plan" },
        { id = 92750, name = "Detonation at a Distance" },
        { id = 92751, name = "Detonation at a Distance" },
        { id = 92752, name = "Explosive Consultation" },
        { id = 92753, name = "Destruction in Deadmines" },
        { id = 92819, name = "Destruction in Deadmines" },
    },

    -- The Stockade.
    -- The Fury Runs Deep is only offered after completing The Dark Iron War.
    [378] = {
        { id = 303, name = "The Dark Iron War" },
    },

    -- The Stockade Riots is the dungeon step of the chain that begins with
    -- The Unsent Letter from Edwin VanCleef, followed by Bazil Thredd.
    [391] = {
        { id = 373, name = "The Unsent Letter" },
        { id = 389, name = "Bazil Thredd" },
    },

    -- Ragefire Chasm.
    [5728] = {
        { id = 5726, name = "Hidden Enemies" },
        { id = 5727, name = "Hidden Enemies" },
    },

    -- Gnomeregan ring chain. The faction-specific upgrade quest is the
    -- journal entry; Grime-Encrusted Ring and Return of the Ring are the
    -- required steps that unlock it.
    [2948] = {
        { id = 2945, name = "Grime-Encrusted Ring" },
        { id = 2947, name = "Return of the Ring" },
    },
    [2950] = {
        { id = 2945, name = "Grime-Encrusted Ring" },
        { id = 2949, name = "Return of the Ring" },
    },

    -- Gnomeregan. Optional breadcrumb quests are intentionally excluded.
    -- Tinkmaster Overspark -> Save Techbot's Brain!, The Day After -> Gnogaine,
    -- and Castpipe's Task -> Data Rescue are storyline/breadcrumb links, not
    -- hard requirements in Forever. Gnogaine itself IS required before
    -- The Only Cure is More Green Glow.
    [2962] = {
        { id = 2926, name = "Gnogaine" },
    },
    -- Rig Wars only needs to be accepted/in progress to make Chief Engineer
    -- Scooty available; it does not need to be completed first.
    [2843] = {
        { id = 2841, name = "Rig Wars", standalone = true, acceptOnly = true }, -- also listed on its own (players looked for it); "(accept only)" in the chain list
        { id = 2842, name = "Chief Engineer Scooty" },
    },

    -- Razorfen Kraul / Scarlet Monastery: Graveyard.
    [1101] = {
        { id = 1100, name = "Lonebrow's Journal" },
    },
    [1113] = {
        { id = 1109, name = "Going, Going, Guano!" },
    },

    -- Blackfathom Deeps.
    -- Researching the Corruption intentionally has NO prerequisite entry here.
    -- The Corruption Abroad is an optional breadcrumb; Gershala offers it directly.
    -- The Essence of Aku'Mai intentionally has NO prerequisite entry here.
    -- Trouble in the Deeps is a breadcrumb and is not required to accept it.

    -- Gnomeregan: Data Rescue needs the Prismatic Punch Card, built up card
    -- by card through four Matrix Punchograph terminals. These are item
    -- steps (placeholder IDs), shown so players know the whole route.
    -- NOT a prerequisite: Data Rescue is picked up straight away. These
    -- are shown as a How to complete guide (QUEST_GUIDE_CHAINS below).
    [2930] = {
        { id = 2930001, name = "White Punch Card", itemStep = true },
        { id = 2930002, name = "Yellow Punch Card (Punchograph 3005-A)", itemStep = true },
        { id = 2930003, name = "Blue Punch Card (Punchograph 3005-B)", itemStep = true },
        { id = 2930004, name = "Red Punch Card (Punchograph 3005-C)", itemStep = true },
        { id = 2930005, name = "Prismatic Punch Card (Punchograph 3005-D)", itemStep = true },
    },

    [6565] = {
        { id = 6564, name = "Allegiance to the Old Gods" },
    },

    -- Excavation Site: Wetlands (Alliance): Horrors in the Highland only
    -- becomes available after completing Rethiel the Greenwarden's Wetlands
    -- chain. 2.0.38: The Greenwarden (463, First Mate Fitzsimmons in Menethil
    -- Harbor) is only a breadcrumb to Rethiel and no longer a required step:
    -- the chain starts with Tramping Paws at Rethiel himself.
    [95646] = {
        { id = 276, name = "Tramping Paws" },
        { id = 277, name = "Fire Taboo" },
        { id = 275, name = "Blisters on The Land" },
    },

    -- Excavation Site: Wetlands (Alliance): Highland Hides requires
    -- Young Crocolisk Skins. Daily Delivery is only a breadcrumb in Forever
    -- and is not required for Highland Hides.
    [98815] = {
        { id = 484, name = "Young Crocolisk Skins" },
    },

    -- Excavation Site: Wetlands (Horde): Dragonmaw Rumors is the
    -- required lead-in to Open the Maw.
    [95682] = {
        { id = 95663, name = "Dragonmaw Rumors" },
    },

    -- Excavation Site: Wetlands (Alliance): Heartwoven follows
    -- Lost in the Thicket Things.
    [95809] = {
        { id = 95647, name = "Lost in the Thicket Things" },
    },

    -- Dungeons added in 1.6.5.

    [1053] = {
        { id = 261, name = "Down the Scarlet Path" },
        { id = 1052, name = "Down the Scarlet Path" },
    },
    [3525] = {
        { id = 3523, name = "Scourge of the Downs" },
    },
    [6521] = {
        { id = 6522, name = "An Unholy Alliance" },
    },
    [722] = {
        { id = 720, name = "A Sign of Hope" },
        { id = 721, name = "A Sign of Hope" },
    },
    [704] = {
        { id = 738, name = "Find Agmond" },
        { id = 739, name = "Murdaloc" },
    },
    [1139] = {
        { id = 720, name = "A Sign of Hope" },
        { id = 721, name = "A Sign of Hope" },
        { id = 722, name = "Amulet of Secrets" },
        { id = 723, name = "Prospect of Faith" },
        { id = 724, name = "Prospect of Faith" },
        { id = 725, name = "Passing Word of a Threat" },
        { id = 726, name = "Passing Word of a Threat" },
        { id = 762, name = "An Ambassador of Evil" },
    },
    [2201] = {
        { id = 2198, name = "The Shattered Necklace" },
        { id = 2199, name = "Lore for a Price" },
        { id = 2200, name = "Back to Uldaman" },
    },
    [2204] = {
        { id = 2198, name = "The Shattered Necklace" },
        { id = 2199, name = "Lore for a Price" },
        { id = 2200, name = "Back to Uldaman" },
        { id = 2201, name = "Find the Gems" },
    },
    [2339] = {
        { id = 2283, name = "Necklace Recovery" },
        { id = 2284, name = "Necklace Recovery, Take 2" },
        { id = 2318, name = "Translating the Journal" },
        { id = 2338, name = "Translating the Journal" },
    },
    [17] = {
        { id = 2500, name = "Badlands Reagent Run" },
    },
    [2202] = {
        { id = 2258, name = "Badlands Reagent Run" },
    },
    [2279] = {
        { id = 2278, name = "The Platinum Discs" },
    },
    [2280] = {
        { id = 2278, name = "The Platinum Discs" },
    },
    [1956] = {
        { id = 1954, name = "The Infernal Orb" },
        { id = 1955, name = "The Exorcism" },
    },
    [2991] = {
        { id = 2988, name = "Witherbark Cages" },
        { id = 2989, name = "The Altar of Zul" },
        { id = 2990, name = "Thadius Grimshade" },
    },
    [2936] = {
        { id = 2933, name = "Venom Bottles" },
        { id = 2934, name = "Undamaged Venom Sac" },
        { id = 2935, name = "Consult Master Gadrin" },
    },
    [3527] = {
        { id = 3520, name = "Screecher Spirits" },
    },
    [1475] = {
        { id = 1448, name = "In Search of The Temple" },
        { id = 1449, name = "To The Hinterlands" },
        { id = 1450, name = "Gryphon Master Talonaxe" },
        { id = 1451, name = "Rhapsody Shindigger" },
        { id = 1452, name = "Rhapsody's Kalimdor Kocktail" },
        { id = 1469, name = "Rhapsody's Tale" },
    },
    [1445] = {
        { id = 1424, name = "Pool of Tears" },
        { id = 1429, name = "The Atal'ai Exile" },
        { id = 1444, name = "Return to Fel'Zerul" },
    },
    [3446] = {
        { id = 3444, name = "The Stone Circle" },
    },
    [3447] = {
        { id = 3444, name = "The Stone Circle" },
    },
    [3528] = {
        { id = 3520, name = "Screecher Spirits" },
        { id = 3527, name = "The Prophecy of Mosh'aru" },
        { id = 4787, name = "The Ancient Egg" },
    },
    [4143] = {
        { id = 4141, name = "Muigin and Larion" },
        { id = 4142, name = "A Visit to Gregan" },
    },
    [4146] = {
        { id = 4145, name = "Larion and Muigin" },
        { id = 4147, name = "Marvon's Workshop" },
    },
    [9053] = {
        { id = 9052, name = "Bloodpetal Poison" },
        { id = 9051, name = "Toxic Test" },
    },
    [8232] = {
        { id = 8153, name = "Courser Antlers" },
        { id = 8231, name = "Wavethrashing" },
    },
    [8253] = {
        { id = 8251, name = "Magic Dust" },
        { id = 8252, name = "The Siren's Coral" },
    },
    [8418] = {
        { id = 8414, name = "Dispelling Evil" },
        { id = 8416, name = "Inert Scourgestones" },
    },
    [8257] = {
        { id = 8255, name = "Of Coursers We Know" },
        { id = 8256, name = "The Ichor of Undeath" },
    },
    [8236] = {
        { id = 8234, name = "Sealed Azure Bag" },
        { id = 8235, name = "Encoded Fragments" },
    },
    [8413] = {
        { id = 8410, name = "Elemental Mastery" },
        { id = 8412, name = "Spirit Totem" },
    },
    [8422] = {
        { id = 8419, name = "An Imp's Request" },
        { id = 8420, name = "Hot and Itchy" },
        { id = 8421, name = "The Wrong Stuff" },
    },
    [8425] = {
        { id = 8423, name = "Warrior Kinship" },
        { id = 8424, name = "War on the Shadowsworn" },
    },
    [3802] = {
        { id = 3801, name = "Dark Iron Legacy" },
    },
    [7046] = {
        { id = 7044, name = "Legends of Maraudon" },
    },
    -- Forever Maraudon: Word of the Woods (93594) is the direct prerequisite
    -- for Rot and Regret (93404), as listed in the Forever quest series.
    -- Hub-unlock prerequisites are not yet independently verified; use the
    -- temporary map placeholder on the Word of the Woods chain step.
    [93404] = {
        { id = 93594, name = "Word of the Woods", level = 43, requires = 35 },
    },
    [4263] = {
        { id = 4262, name = "Overmaster Pyron" },
    },
    [4362] = {
        { id = 3702, name = "The Smoldering Ruins of Thaurissan" },
        { id = 3701, name = "The Smoldering Ruins of Thaurissan" },
        { id = 4341, name = "Kharan Mighthammer" },
        { id = 4342, name = "Kharan's Tale" },
        { id = 4361, name = "The Bearer of Bad News" },
    },
    [4322] = {
        { id = 4182, name = "Dragonkin Menace" },
        { id = 4183, name = "The True Masters" },
        { id = 4184, name = "The True Masters" },
        { id = 4185, name = "The True Masters" },
        { id = 4186, name = "The True Masters" },
        { id = 4223, name = "The True Masters" },
        { id = 4224, name = "The True Masters" },
        { id = 4241, name = "Marshal Windsor" },
        { id = 4242, name = "Abandoned Hope" },
        { id = 4264, name = "A Crumpled Up Note" },
        { id = 4282, name = "A Shred of Hope" },
    },
    [3907] = {
        { id = 3906, name = "Disharmony of Flame" },
    },
    [7201] = {
        { id = 3906, name = "Disharmony of Flame" },
    },
    [4003] = {
        { id = 3906, name = "Disharmony of Flame" },
        { id = 3981, name = "Commander Gor'shak" },
        { id = 3982, name = "What Is Going On?" },
        { id = 4001, name = "What Is Going On?" },
        { id = 4002, name = "The Eastern Kingdoms" },
    },
    [3982] = {
        { id = 3906, name = "Disharmony of Flame" },
        { id = 3981, name = "Commander Gor'shak" },
    },
    [4082] = {
        { id = 4081, name = "KILL ON SIGHT: Dark Iron Dwarves" },
    },
    [4132] = {
        { id = 4081, name = "KILL ON SIGHT: Dark Iron Dwarves" },
        { id = 4082, name = "KILL ON SIGHT: High Ranking Dark Iron Officials" },
        { id = 4122, name = "Grark Lorkrub" },
        { id = 4121, name = "Precarious Predicament" },
    },
    [4063] = {
        { id = 4061, name = "The Rise of the Machines" },
        { id = 4062, name = "The Rise of the Machines" },
    },
    [5081] = {
        { id = 5001, name = "Bijou's Belongings" },
        { id = 5002, name = "Message to Maxwell" },
    },
    [4982] = {
        { id = 4981, name = "Operative Bijou" },
    },
    [4788] = {
        { id = 3520, name = "Screecher Spirits" },
        { id = 3527, name = "The Prophecy of Mosh'aru" },
        { id = 4787, name = "The Ancient Egg" },
        { id = 3528, name = "The God Hakkar" },
        { id = 5065, name = "The Lost Tablets of Mosh'aru" },
    },
    [4743] = {
        { id = 4742, name = "Seal of Ascension" },
    },
    [4735] = {
        { id = 4726, name = "Broodling Essence" },
        { id = 4808, name = "Felnok Steelspring" },
        { id = 4809, name = "Chillwind Horns" },
        { id = 4810, name = "Return to Tinkee" },
        { id = 4907, name = "Tinkee Steamboil" },
        { id = 4734, name = "Egg Freezing" },
    },
    [4974] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
    },
    [6569] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
        { id = 4974, name = "For The Horde!" },
        { id = 6566, name = "What the Wind Carries" },
        { id = 6567, name = "The Champion of the Horde" },
        { id = 6568, name = "The Testament of Rexxar" },
    },
    [6502] = {
        { id = 4182, name = "Dragonkin Menace" },
        { id = 4183, name = "The True Masters" },
        { id = 4184, name = "The True Masters" },
        { id = 4185, name = "The True Masters" },
        { id = 4186, name = "The True Masters" },
        { id = 4223, name = "The True Masters" },
        { id = 4224, name = "The True Masters" },
        { id = 4241, name = "Marshal Windsor" },
        { id = 4242, name = "Abandoned Hope" },
        { id = 4264, name = "A Crumpled Up Note" },
        { id = 4282, name = "A Shred of Hope" },
        { id = 4322, name = "Jail Break!" },
        { id = 6402, name = "Stormwind Rendezvous" },
        { id = 6403, name = "The Great Masquerade" },
        { id = 6501, name = "The Dragon's Eye" },
    },
    [6602] = {
        { id = 4903, name = "Warlord's Command" },
        { id = 4941, name = "Eitrigg's Wisdom" },
        { id = 4974, name = "For The Horde!" },
        { id = 6566, name = "What the Wind Carries" },
        { id = 6567, name = "The Champion of the Horde" },
        { id = 6568, name = "The Testament of Rexxar" },
        { id = 6569, name = "Oculus Illusions" },
        { id = 6570, name = "Emberstrife" },
        { id = 6582, name = "The Test of Skulls, Scryer" },
        { id = 6583, name = "The Test of Skulls, Somnus" },
        { id = 6584, name = "The Test of Skulls, Chronalis" },
        { id = 6585, name = "The Test of Skulls, Axtroz" },
        { id = 6601, name = "Ascension..." },
    },
    [5102] = {
        { id = 5089, name = "General Drakkisath's Command" },
    },
    [5526] = {
        { id = 5527, name = "A Reliquary of Purity" },
    },
    [5247] = {
        { id = 5244, name = "The Ruins of Kel'Theril" },
        { id = 5245, name = "Troubled Spirits of Kel'Theril" },
        { id = 5246, name = "Fragments of the Past" },
    },
    [7643] = {
        { id = 7637, name = "Emphasis on Sacrifice" },
        { id = 7639, name = "To Show Due Judgment" },
        { id = 7640, name = "Exorcising Terrordale" },
        { id = 7641, name = "The Work of Grimand Elmore" },
        { id = 7642, name = "Collection of Goods" },
        { id = 7648, name = "Grimand's Finest Work" },
        { id = 7645, name = "Manna-Enriched Horse Feed" },
    },
    [7631] = {
        { id = 7563, name = "Rage of Blood" },
        { id = 7564, name = "Wildeyes" },
        { id = 7623, name = "Lord Banehollow" },
        { id = 7624, name = "Ulathek the Traitor" },
        { id = 7625, name = "Xorothian Stardust" },
        { id = 7626, name = "Bell of Dethmoora" },
        { id = 7627, name = "Wheel of the Black March" },
        { id = 7628, name = "Doomsday Candle" },
        { id = 7629, name = "Imp Delivery" },
        { id = 7630, name = "Arcanite" },
    },
    [5515] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
    },
    [5384] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
    },
    [5466] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
        { id = 5384, name = "Kirtonos the Herald" },
        { id = 5461, name = "The Human, Ras Frostwhisper" },
        { id = 5462, name = "The Dying, Ras Frostwhisper" },
        { id = 5463, name = "Menethil's Gift" },
        { id = 5464, name = "Menethil's Gift" },
        { id = 5465, name = "Soulbound Keepsake" },
    },
    [4771] = {
        { id = 4726, name = "Broodling Essence" },
        { id = 4808, name = "Felnok Steelspring" },
        { id = 4809, name = "Chillwind Horns" },
        { id = 4810, name = "Return to Tinkee" },
        { id = 4907, name = "Tinkee Steamboil" },
        { id = 4734, name = "Egg Freezing" },
        { id = 4735, name = "Egg Collection" },
        { id = 5522, name = "Leonid Barthalomew" },
        { id = 5531, name = "Betina Bigglezink" },
    },
    [7629] = {
        { id = 7563, name = "Rage of Blood" },
        { id = 7564, name = "Wildeyes" },
        { id = 7623, name = "Lord Banehollow" },
        { id = 7624, name = "Ulathek the Traitor" },
        { id = 7625, name = "Xorothian Stardust" },
    },
    [7647] = {
        { id = 7637, name = "Emphasis on Sacrifice" },
        { id = 7639, name = "To Show Due Judgment" },
        { id = 7640, name = "Exorcising Terrordale" },
        { id = 7641, name = "The Work of Grimand Elmore" },
        { id = 7642, name = "Collection of Goods" },
        { id = 7648, name = "Grimand's Finest Work" },
        { id = 7645, name = "Manna-Enriched Horse Feed" },
        { id = 7643, name = "Ancient Equine Spirit" },
        { id = 7644, name = "Blessed Arcanite Barding" },
        { id = 7646, name = "The Divination Scryer" },
    },
    [7668] = {
        { id = 7667, name = "Material Assistance" },
    },
    [5262] = {
        { id = 5251, name = "The Archivist" },
    },
    [5848] = {
        { id = 5542, name = "Demon Dogs" },
        { id = 5543, name = "Blood Tinged Skies" },
        { id = 5544, name = "Carrion Grubbage" },
        { id = 5742, name = "Redemption" },
        { id = 5781, name = "Of Forgotten Memories" },
        { id = 5845, name = "Of Lost Honor" },
        { id = 5846, name = "Of Love and Family" },
    },
    [5213] = {
        { id = 5212, name = "The Flesh Does Not Lie" },
    },
    [5263] = {
        { id = 5251, name = "The Archivist" },
        { id = 5262, name = "The Truth Comes Crashing Down" },
    },
    [6163] = {
        { id = 6133, name = "The Ranger Lord's Behest" },
        { id = 6042, name = "Un-Life's Little Annoyances" },
        { id = 6022, name = "To Kill With Purpose" },
        { id = 6135, name = "Duskwing, Oh How I Hate Thee..." },
        { id = 6136, name = "The Corpulent One" },
    },
    [5463] = {
        { id = 5382, name = "Doctor Theolen Krastinov, the Butcher" },
        { id = 5515, name = "Krastinov's Bag of Horrors" },
        { id = 5384, name = "Kirtonos the Herald" },
        { id = 5461, name = "The Human, Ras Frostwhisper" },
        { id = 5462, name = "The Dying, Ras Frostwhisper" },
    },
    [5125] = {
        { id = 5122, name = "The Medallion of Faith" },
    },

    -- City of Dalaran - Alliance: Heart of Disruption
    [92458] = {
        { id = 92432, name = "An Alarming Request" },
    },

    -- City of Dalaran - Horde: Heart of Disruption
    [96984] = {
        { id = 544, name = "Prison Break In" },
        { id = 92433, name = "Key to the City" },
        { id = 545, name = "Dalaran Patrols" },
        { id = 92434, name = "Blood in the Streets" },
    },
}
