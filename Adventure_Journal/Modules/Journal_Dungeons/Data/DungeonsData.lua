-- ============================================================================
-- Journal_Dungeons - Data/DungeonsData.lua
-- Complete 35-dungeon catalog for Classic and WoW Forever (Interface 16001),
-- including level brackets, locations, art candidates, search aliases, and
-- boss rosters with creature display IDs and encounter descriptions.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local type = type
local sort = table.sort
local strlower = string.lower
local strfind = string.find

local LOAD_SCREEN = "Interface\\Glues\\LoadingScreens\\"

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local DUNGEONS = {
    -- 1. Hall of Thanes (WoW Forever)
    {
        id = "hall_of_thanes",
        name = "Hall of Thanes",
        category = "FOREVER",
        level = "13-20",
        minLevel = 13,
        maxLevel = 20,
        location = "Beneath Ironforge, Dun Morogh",
        description = "Someone has broken into the royal dwarven burial chamber beneath Ironforge. Restless spirits of ancient thanes and Dark Iron intruders now stalk the Reliquary of Kings.",
        icon = "Interface\\Icons\\INV_Hammer_04",
        art = {
            7963781,
            LOAD_SCREEN .. "LoadScreenIronforge",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "hot", "thanes", "ironforge" },
        bosses = {
            {
                name = "Faldrim Anvilmar",
                level = "16",
                npcID = 261306,
                displayID = 142826,
                description = "The restless spirit of an ancient Anvilmar monarch disturbed by tomb robbers in the outer crypts.",
            },
            {
                name = "Magmatus",
                level = "16",
                icon = "Interface\\Icons\\Spell_Fire_Elemental_Totem",
                description = "A molten elemental summoned within the deep forge vents beneath the royal burial halls.",
            },
            {
                name = "Plunder",
                level = "16",
                npcID = 261311,
                displayID = 142840,
                description = "An ancient dwarven guardian construct awakened to defend the royal vaults from intruders.",
            },
            {
                name = "Durgen Dirgehammer",
                level = "16",
                npcID = 261319,
                displayID = 142837,
                description = "Leader of the Dark Iron incursion inside the Reliquary of Kings. Check the royal vaults in his chamber for the Treaty of Understanding.",
            },
        },
    },

    -- 2. Ragefire Chasm (Classic)
    {
        id = "ragefire_chasm",
        name = "Ragefire Chasm",
        category = "CLASSIC",
        level = "13-18",
        minLevel = 13,
        maxLevel = 18,
        location = "Cleft of Shadow, Orgrimmar",
        description = "Ragefire Chasm consists of a network of volcanic caverns that lie below Orgrimmar. Lately, followers of the demonic Shadow Council have nestled into the Chasm's fiery depths.",
        icon = "Interface\\Icons\\Spell_Fire_Fire",
        art = { LOAD_SCREEN .. "LoadScreenRagefireChasm" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "rfc", "ragefire" },
        bosses = {
            {
                name = "Taragaman the Hungerer",
                level = "16",
                npcID = 11520,
                displayID = 7970,
                description = "A powerful felguard summoned by the Searing Blade cultists to anchor their hold over the chasm.",
            },
            {
                name = "Jergosh the Invoker",
                level = "16",
                npcID = 11518,
                displayID = 11429,
                description = "A fanatical warlock of the Searing Blade who channels dark rituals in the deeper caverns.",
            },
            {
                name = "Oggleflint",
                level = "16",
                npcID = 11517,
                displayID = 11611,
                description = "Leader of the Ragefire Troggs guarding the upper volcanic tunnels.",
            },
            {
                name = "Bazzalan",
                level = "16",
                npcID = 11519,
                displayID = 2007,
                description = "A cunning satyr emissary directing the Searing Blade warlocks from an elevated ledge.",
            },
        },
    },

    -- 3. Ruins of Lordaeron (WoW Forever)
    {
        id = "ruins_of_lordaeron",
        name = "Ruins of Lordaeron",
        category = "FOREVER",
        level = "15-22",
        minLevel = 15,
        maxLevel = 22,
        location = "Capital City, Tirisfal Glades",
        description = "Scourge forces still haunt the ruined capital above the Undercity while the necromancer Rath'mael gathers dark power within the fallen courtyards.",
        icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
        art = {
            7963782,
            LOAD_SCREEN .. "LoadScreenUndercity",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "rol", "lordaeron", "ruins" },
        bosses = {
            {
                name = "The Baron",
                level = "17",
                npcID = 250660,
                displayID = 144188,
                description = "A hulking stitched abomination prowling the ruined courtyard slaughterhouse.",
            },
            {
                name = "Witherfang",
                level = "17",
                npcID = 250483,
                displayID = 144189,
                description = "A venomous giant arachnid nesting in the overgrown gardens of the ruined palace.",
            },
            {
                name = "The Abandoned",
                level = "18",
                npcID = 250631,
                displayID = 138667,
                description = "A tormented amalgam of fallen citizens trapped within the capital's catacombs.",
            },
            {
                name = "Bjork",
                level = "19",
                npcID = 256097,
                displayID = 144170,
                description = "A ferocious undead brute guarding the inner garrison quarters.",
            },
            {
                name = "Viktor the Vile",
                level = "19",
                npcID = 256035,
                displayID = 139455,
                description = "A sadistic plague-alchemist experimenting on the remnants of Lordaeron's defenders.",
            },
            {
                name = "Lordaeron Captain",
                level = "19",
                rare = true,
                icon = "Interface\\Icons\\INV_Helmet_03",
                description = "Rare spawn. A spectral captain of the old royal guard still patrolling the battlements.",
            },
            {
                name = "Rath'mael",
                level = "20",
                npcID = 250657,
                displayID = 144175,
                description = "Final boss. A powerful Scourge necromancer commanding the undead legions in the Ruins of Lordaeron.",
            },
        },
    },

    -- 4. Wailing Caverns (Classic)
    {
        id = "wailing_caverns",
        name = "Wailing Caverns",
        category = "CLASSIC",
        level = "15-24",
        minLevel = 15,
        maxLevel = 24,
        location = "Northern Barrens",
        description = "Deep beneath the Barrens, corrupted Druids of the Fang guard the sleeping archdruid Naralex while nightmare beasts prowl the subterranean springs.",
        icon = "Interface\\Icons\\Spell_Nature_Purge",
        art = { LOAD_SCREEN .. "LoadScreenWailingCaverns" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "wc", "wailing" },
        bosses = {
            { name = "Lord Cobrahn", level = "20", npcID = 3669, displayID = 4213, description = "One of the four Fanglords whose Nightmare energy imprisons Naralex." },
            { name = "Lady Anacondra", level = "20", npcID = 3671, displayID = 4313, description = "High priestess among the Druids of the Fang patrolling the central cavern." },
            { name = "Kresh", level = "20", npcID = 3653, displayID = 5126, description = "A giant ancient river turtle wandering the subterranean streams." },
            { name = "Lord Pythas", level = "21", npcID = 3670, displayID = 4214, description = "Warrior-druid of the Fang who guards the upper eastern ledges." },
            { name = "Skum", level = "21", npcID = 3674, displayID = 4203, description = "A massive thunder lizard mutated by the Emerald Nightmare." },
            { name = "Lord Serpentis", level = "21", npcID = 3673, displayID = 4215, description = "Self-proclaimed leader of the Druids of the Fang atop the high cavern ridge." },
            { name = "Verdan the Everliving", level = "21", npcID = 5775, displayID = 4256, description = "A towering marsh elemental guarding Serpentis's perch." },
            { name = "Mutanus the Devourer", level = "22", npcID = 3654, displayID = 4088, description = "Summoned during the final awakening ritual to devour Naralex's mind." },
            { name = "Deviate Faerie Dragon", level = "20", npcID = 5912, displayID = 1267, rare = true, description = "Rare spawn found along the winding cavern paths." },
        },
    },

    -- 5. The Deadmines (Classic)
    {
        id = "the_deadmines",
        name = "The Deadmines",
        category = "CLASSIC",
        level = "17-26",
        minLevel = 17,
        maxLevel = 26,
        location = "Moonbrook, Westfall",
        description = "Beneath the abandoned town of Moonbrook, Edwin VanCleef and the Defias Brotherhood have constructed a massive subterranean drydock and juggernaut warship.",
        icon = "Interface\\Icons\\INV_Pick_02",
        art = { LOAD_SCREEN .. "LoadScreenDeadmines" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "dm", "vc", "deadmines", "vancleef" },
        bosses = {
            { name = "Rhahk'Zor", level = "19", npcID = 644, displayID = 14403, description = "Ogre foreman guarding the first heavy iron door of the mines." },
            { name = "Miner Johnson", level = "19", npcID = 3586, displayID = 556, rare = true, description = "Rare spawn in the side passage beyond Rhahk'Zor." },
            { name = "Sneed", level = "20", npcID = 643, displayID = 7125, description = "Goblin lumbermaster who ejects when his Shredder is destroyed." },
            { name = "Sneed's Shredder", level = "20", npcID = 642, displayID = 1269, description = "Mechanical lumber harvester in the Mast Room." },
            { name = "Gilnid", level = "20", npcID = 1763, displayID = 7124, description = "Goblin foundry master overseeing the Goblin Foundry." },
            { name = "Mr. Smite", level = "20", npcID = 646, displayID = 2026, description = "First mate of the Defias Juggernaut who switches weapons from his chest at 66% and 33% health." },
            { name = "Captain Greenskin", level = "20", npcID = 647, displayID = 7113, description = "Goblin captain patrolling the upper deck of the juggernaut." },
            { name = "Edwin VanCleef", level = "21", npcID = 639, displayID = 2029, description = "Mastermind of the Defias Brotherhood atop the juggernaut's command cabin." },
            { name = "Cookie", level = "20", npcID = 645, displayID = 1305, description = "The ship's murloc cook found in the galley below deck." },
        },
    },

    -- 6. Shadowfang Keep (Classic)
    {
        id = "shadowfang_keep",
        name = "Shadowfang Keep",
        category = "CLASSIC",
        level = "20-30",
        minLevel = 20,
        maxLevel = 30,
        location = "Pyrewood Village, Silverpine Forest",
        description = "Once the fortress of Baron Silverlaine, Shadowfang Keep has fallen under the curse of Archmage Arugal and his ferocious worgen pack.",
        icon = "Interface\\Icons\\Spell_Shadow_ChillTouch",
        art = { LOAD_SCREEN .. "LoadScreenShadowFangKeep" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "sfk", "shadowfang", "arugal" },
        bosses = {
            { name = "Rethilgore", level = "20", npcID = 3914, displayID = 524, description = "Worgen jailer holding the keys to the courtyard prisoners." },
            { name = "Fel Steed / Shadow Charger", level = "19-21", npcID = 3864, displayID = 1951, description = "Demonic steeds stabled off the central courtyard." },
            { name = "Razorclaw the Butcher", level = "22", npcID = 3886, displayID = 524, description = "Ferocious worgen in the keep's kitchen." },
            { name = "Baron Silverlaine", level = "24", npcID = 3887, displayID = 3222, description = "Restless spirit of the keep's former lord in the dining hall." },
            { name = "Commander Springvale", level = "24", npcID = 4278, displayID = 3223, description = "Haunted paladin commander in the council chamber." },
            { name = "Odo the Blindwatcher", level = "24", npcID = 4279, displayID = 522, description = "Blind worgen overseer atop the keep's ramparts." },
            { name = "Deathsworn Captain", level = "25", npcID = 3872, displayID = 3224, rare = true, description = "Rare spectral captain on the battlements." },
            { name = "Arugal's Voidwalker", level = "24-25", npcID = 4627, displayID = 1131, description = "Voidwalkers unleashed after Fenrus is slain." },
            { name = "Fenrus the Devourer", level = "25", npcID = 4274, displayID = 2352, description = "Massive worgen hound in Arugal's laboratory." },
            { name = "Wolf Master Nandos", level = "25", npcID = 3927, displayID = 11179, description = "Keeper of Arugal's elite worgen pack before the final tower." },
            { name = "Archmage Arugal", level = "24", npcID = 4275, displayID = 2353, description = "Mad Dalaran archmage who teleports across the platforms and mind-controls party members." },
            { name = "Crown Chemical Co.", level = "??", npcID = 36296, displayID = 31167, isEvent = true, holiday = "Love is in the Air", description = "Love is in the Air seasonal event encounter in the courtyard." },
        },
    },

    -- 7. Blackfathom Deeps (Classic)
    {
        id = "blackfathom_deeps",
        name = "Blackfathom Deeps",
        category = "CLASSIC",
        level = "24-32",
        minLevel = 24,
        maxLevel = 32,
        location = "Zoram Strand, Ashenvale",
        description = "Once dedicated to the night elves' goddess Elune, Blackfathom Deeps was thought to have been destroyed during the Sundering. Millennia later, Twilight's Hammer cultists and naga have claimed the sunken temple to guard the ancient hydra Aku'mai.",
        icon = "Interface\\Icons\\Spell_Frost_Stun",
        art = { LOAD_SCREEN .. "LoadScreenBlackFathomDeeps" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "bfd", "blackfathom" },
        bosses = {
            {
                name = "Ghamoo-ra",
                level = "25",
                npcID = 4887,
                displayID = 5027,
                description = "When the Twilight's Hammer cult arrived, its followers roused and imprisoned one of the last peaceful creatures living in Elune's temple, tormenting the giant turtle until it succumbed to madness.",
                abilities = {
                    { name = "Shell Shocker", icon = "Interface\\Icons\\Ability_Warrior_Charge", description = "Ghamoo-ra charges and releases a burst of energy, knocking back and damaging nearby enemies." },
                    { name = "Trample", icon = "Interface\\Icons\\Ability_WarStomp", description = "Inflicts heavy physical damage to all enemies in melee range." },
                },
            },
            { name = "Lady Sarevess", level = "25", npcID = 4831, displayID = 4979, description = "Naga sea witch commanding the flooded outer sanctum." },
            { name = "Gelihast", level = "26", npcID = 6243, displayID = 1773, description = "Murloc champion guarding the shrine of the Moonpriestess." },
            { name = "Baron Aquanis", level = "28", npcID = 12876, displayID = 110, description = "Water elemental lord guarding the Fathom Core." },
            { name = "Twilight Lord Kelris", level = "27", npcID = 4832, displayID = 4939, description = "High priest of the Twilight's Hammer who puts party members to sleep at the sacrificial altar." },
            { name = "Old Serra'kis", level = "26", npcID = 4830, displayID = 1816, description = "Giant thresher shark patrolling the deep waters." },
            { name = "Aku'mai", level = "28", npcID = 4829, displayID = 2837, description = "Ancient three-headed hydra and favored pet of the Old Gods." },
            { name = "Lorgus Jett", level = "26", npcID = 12902, displayID = 12822, description = "Corrupted shaman along the submerged causeway." },
        },
    },

    -- 8. The Stockade (Classic)
    {
        id = "the_stockade",
        name = "The Stockade",
        category = "CLASSIC",
        level = "24-32",
        minLevel = 24,
        maxLevel = 32,
        location = "Canals, Stormwind City",
        description = "A high-security prison complex beneath Stormwind's canal district, overrun by a prisoner uprising led by the Defias agitator Bazil Thredd.",
        icon = "Interface\\Icons\\INV_Misc_Key_04",
        art = {
            131870,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "stocks", "stockade", "stormwind stockade" },
        bosses = {
            { name = "Kam Deepfury", level = "27", npcID = 1666, displayID = 825, description = "Dark Iron dwarf conspirator held in the northern hall." },
            { name = "Bruegal Ironknuckle", level = "26", npcID = 1720, displayID = 2142, rare = true, description = "Rare spawn convict found in the side cells." },
            { name = "Targorr the Dread", level = "24", npcID = 1696, displayID = 517, description = "Blackrock orc warlord imprisoned in the western cellblock." },
            { name = "Hamhock", level = "28", npcID = 1717, displayID = 3250, description = "Brutal ogre inmate guarding the central wing." },
            { name = "Bazil Thredd", level = "29", npcID = 1716, displayID = 1621, description = "Former lieutenant of Edwin VanCleef and mastermind of the Stockade riot." },
            { name = "Dextren Ward", level = "26", npcID = 1663, displayID = 2149, description = "Notorious bandit ringleader who fears enemies in melee." },
        },
    },

    -- 9. Excavation Site: Wetlands (WoW Forever)
    {
        id = "excavation_site_wetlands",
        name = "Excavation Site: Wetlands",
        category = "FOREVER",
        level = "26-33",
        minLevel = 26,
        maxLevel = 33,
        location = "Whelgar's Excavation Site, Wetlands",
        description = "Explorers' League diggers in the Wetlands have broken into a sealed subterranean complex teeming with prehistoric beasts and ancient titanic relics.",
        icon = "Interface\\Icons\\INV_Misc_Bone_DwarfSkull_01",
        art = { 7963777, LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "esw", "excavation", "wetlands", "whelgar" },
        bosses = {
            { name = "Saltspine", level = "28", npcID = 260322, displayID = 144209, description = "An armored subterranean beast prowling the flooded dig tunnels." },
            { name = "Shadetooth", level = "29", npcID = 260325, displayID = 144210, description = "An apex predator stalking the fossilized caverns." },
            { name = "Relic Guardian", level = "31", npcID = 260326, displayID = 144224, description = "An ancient stone construct awakened to defend the inner chamber." },
        },
    },

    -- 10. City of Dalaran (WoW Forever)
    {
        id = "city_of_dalaran",
        name = "City of Dalaran",
        category = "FOREVER",
        level = "28-35",
        minLevel = 28,
        maxLevel = 35,
        location = "Alterac Mountains",
        description = "Behind Dalaran's arcane wards, unstable ley-line rifts, rogue constructs, and remnants of the Scourge assault threaten the wizards' sanctum.",
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        art = { 7963775, LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "dal", "dalaran" },
        bosses = {
            { name = "Atrexis the Grave Knight", level = "29", npcID = 247126, displayID = 145787, description = "An undead death-knight commander haunting the outer streets." },
            { name = "Arcane Anomaly", level = "30", npcID = 245999, displayID = 129891, description = "Volatile manifestation of ruptured ley energy." },
            { name = "Arcanic Enigma", level = "30", npcID = 246016, displayID = 129900, description = "Sentient mana elemental surging through the mage quarters." },
            { name = "Unstable Sentinel", level = "31", npcID = 246017, displayID = 129954, description = "Malfunctioning Kirin Tor arcane golem." },
            { name = "Mana Devourer", level = "31", npcID = 246008, displayID = 129895, description = "Voracious creature feeding upon Dalaran's arcane conduits." },
            { name = "Fel Ancient", level = "32", npcID = 246003, displayID = 129894, description = "Corrupted ancient twisted by residual demonic magic." },
            { name = "Lyn the Ignored", level = "30", isMinor = true, description = "A forgotten apprentice wandering the subterranean tunnels." },
            { name = "Shade of the Archmage", level = "33", npcID = 246020, displayID = 130061, description = "Final boss. A powerful spectral archmage bound to the heart of the city." },
        },
    },

    -- 11. Gnomeregan (Classic)
    {
        id = "gnomeregan",
        name = "Gnomeregan",
        category = "CLASSIC",
        level = "29-38",
        minLevel = 29,
        maxLevel = 38,
        location = "Dun Morogh",
        description = "The irradiated techno-city of the gnomes, betrayed from within by Mekgineer Thermaplugg and overrun by troggs, leper gnomes, and haywire mechanostriders.",
        icon = "Interface\\Icons\\INV_Gizmo_02",
        art = { LOAD_SCREEN .. "LoadScreenGnomeregan" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "gnomer", "gnomeregan", "thermaplugg" },
        bosses = {
            { name = "Techbot", level = "26", npcID = 6231, displayID = 7288, isMinor = true, description = "Rogue security robot guarding the exterior entrance." },
            { name = "Grubbis", level = "32", npcID = 7361, displayID = 144378, description = "Trogg chieftain unleashed during Blastmaster Emi Shortfuse's demolition event." },
            { name = "Viscous Fallout", level = "30", npcID = 7079, displayID = 5497, description = "Radioactive slime patrolling the Hall of Gears." },
            { name = "Electrocutioner 6000", level = "32", npcID = 6235, displayID = 6915, description = "High-voltage security robot guarding the Workshop Key." },
            { name = "Crowd Pummeler 9-60", level = "32", npcID = 6229, displayID = 6774, description = "Heavy riot-control walker in the Engineering Labs." },
            { name = "Dark Iron Ambassador", level = "33", npcID = 6228, displayID = 6669, rare = true, description = "Rare Dark Iron emissary conspiring with Thermaplugg." },
            { name = "Mekgineer Thermaplugg", level = "34", npcID = 7800, displayID = 6980, description = "Self-proclaimed King of Gnomeregan piloting his bomb-dispensing battle suit." },
        },
    },

    -- 12. Razorfen Kraul (Classic)
    {
        id = "razorfen_kraul",
        name = "Razorfen Kraul",
        category = "CLASSIC",
        level = "29-38",
        minLevel = 29,
        maxLevel = 38,
        location = "Southern Barrens",
        description = "A sprawling tangle of giant thorns in the Southern Barrens serving as the stronghold of the Death's Head quilboar tribe under Charlga Razorflank.",
        icon = "Interface\\Icons\\INV_Misc_Head_Quillboar_01",
        art = {
            131865,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "rfk", "kraul" },
        bosses = {
            { name = "Aggem Thorncurse", level = "30", npcID = 4424, displayID = 6097, description = "Death's Head summoner channeling boar spirits." },
            { name = "Death Speaker Jargba", level = "30", npcID = 4428, displayID = 4644, description = "High priest of the Death's Head who mind-controls party members." },
            { name = "Overlord Ramtusk", level = "32", npcID = 4420, displayID = 4652, description = "Armored warleader commanding the Kraul's spearhead." },
            { name = "Razorfen Spearhide", level = "30", npcID = 4438, displayID = 6078, rare = true, description = "Rare quilboar spearman in the lower pens." },
            { name = "Agathelos the Raging", level = "33", npcID = 4422, displayID = 2450, description = "Colossal armored boar in the western cavern." },
            { name = "Blind Hunter", level = "32", npcID = 4425, displayID = 4735, rare = true, description = "Rare giant bat roosting in the upper caves." },
            { name = "Charlga Razorflank", level = "33", npcID = 4421, displayID = 4642, description = "Crone leader of the Death's Head tribe." },
            { name = "Earthcaller Halmgar", level = "32", npcID = 4842, displayID = 6102, rare = true, description = "Rare quilboar shaman on the central earthen platform." },
            { name = "Roogug", level = "28", npcID = 6168, displayID = 6110, description = "Quilboar geomancer guarding the lower thorn tunnels." },
        },
    },

    -- 13. Scarlet Monastery: Graveyard (Classic)
    {
        id = "sm_graveyard",
        name = "Scarlet Monastery: Graveyard",
        category = "CLASSIC",
        level = "30-38",
        minLevel = 30,
        maxLevel = 38,
        location = "Tirisfal Glades",
        description = "The torture chambers and haunted burial grounds of the Scarlet Monastery, where Interrogator Vishas extracts confessions and the undead Bloodmage Thalnos guards the crypts.",
        icon = "Interface\\Icons\\Spell_Shadow_Haunting",
        art = {
            LOAD_SCREEN .. "LoadScreenMonastery",
            LOAD_SCREEN .. "LoadScreenScarletMonastery",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "sm gy", "sm graveyard", "graveyard" },
        bosses = {
            { name = "Interrogator Vishas", level = "32", npcID = 3983, displayID = 2044, description = "Scarlet torturer in the entry prison chamber." },
            { name = "Azshir the Sleepless", level = "33", npcID = 6490, displayID = 5534, rare = true, description = "Rare restless wraith in the cemetery." },
            { name = "Fallen Champion", level = "33", npcID = 6488, displayID = 5230, rare = true, description = "Rare undead warrior among the tombs." },
            { name = "Ironspine", level = "33", npcID = 6489, displayID = 5231, rare = true, description = "Rare skeletal Construct patrolling the graveyard." },
            { name = "Bloodmage Thalnos", level = "34", npcID = 4543, displayID = 11396, description = "Skeletal bloodmage atop the mausoleum." },
            { name = "Headless Horseman", level = "??", npcID = 23682, displayID = 22351, isEvent = true, holiday = "Hallow's End", description = "Hallow's End seasonal boss summoned at the graveyard shrine." },
        },
    },

    -- 14. Scarlet Monastery: Library (Classic)
    {
        id = "sm_library",
        name = "Scarlet Monastery: Library",
        category = "CLASSIC",
        level = "33-41",
        minLevel = 33,
        maxLevel = 41,
        location = "Tirisfal Glades",
        description = "The Athenaeum and galleries of the Scarlet Crusade, housing ancient tomes, war hounds, and the Scarlet Key inside Arcanist Doan's strongbox.",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        art = {
            LOAD_SCREEN .. "LoadScreenMonastery",
            LOAD_SCREEN .. "LoadScreenScarletMonastery",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "sm lib", "sm library", "library", "doan" },
        bosses = {
            { name = "Houndmaster Loksey", level = "34", npcID = 3974, displayID = 2040, description = "Keeper of the Scarlet tracking hounds in the courtyard kennels." },
            { name = "Arcanist Doan", level = "37", npcID = 6487, displayID = 5266, description = "Keeper of the Athenaeum who casts Detonation and guards The Scarlet Key." },
        },
    },

    -- 15. Scarlet Monastery: Armory (Classic)
    {
        id = "sm_armory",
        name = "Scarlet Monastery: Armory",
        category = "CLASSIC",
        level = "36-44",
        minLevel = 36,
        maxLevel = 44,
        location = "Tirisfal Glades",
        description = "The training barracks and Hall of Champions of the Scarlet Crusade, presided over by the Scarlet champion Herod.",
        icon = "Interface\\Icons\\INV_Helmet_03",
        art = {
            LOAD_SCREEN .. "LoadScreenMonastery",
            LOAD_SCREEN .. "LoadScreenScarletMonastery",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "sm arm", "sm armory", "armory", "herod" },
        bosses = {
            { name = "Herod", level = "40", npcID = 3975, displayID = 2041, description = "The Scarlet Champion who unleashes devastating Blades of Light whirlwinds." },
        },
    },

    -- 16. The Drowned City (WoW Forever — Coming Soon)
    {
        id = "the_drowned_city",
        name = "The Drowned City",
        category = "COMING_SOON",
        level = "35-42",
        minLevel = 35,
        maxLevel = 42,
        location = "Stranglethorn Vale",
        description = "I'lalai, a lost Gurubashi troll city, has risen from the sea off the coast of Stranglethorn Vale west of Grom'gol. Trolls, naga, and Saltseer pirates roam its storm-swept streets.",
        icon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
        art = {
            7963741,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "tdc", "drowned city", "ilalai" },
        bosses = {
            { name = "Zul'Alai", level = "37", npcID = 258905, displayID = 144475, description = "First boss, an undead Gurubashi troll who enrages near death." },
            { name = "Var'Taka", level = "38", npcID = 258924, displayID = 144487, description = "Leader of the Brinescale naga occupying the sunken ruins." },
            { name = "Captain Dreadrise", level = "39", npcID = 260042, displayID = 142144, description = "Commander of the Saltseer pirates near the wrecked ship." },
            { name = "Deathless Marrow", level = "39", npcID = 270885, displayID = 142245, description = "Fought alongside a Primeval Elemental." },
            { name = "Gill", level = "38", npcID = 264177, displayID = 144023, rare = true, description = "Rare creature lurking in the flooded shallows." },
            { name = "Min'loth the Serpent", level = "40", npcID = 260274, displayID = 142322, description = "Final boss: the Gurubashi witch doctor whose seat of power was I'lalai." },
            { name = "Primeval Elemental", level = "39", rare = true, description = "Ancient water elemental emerging from the sunken reefs." },
        },
    },

    -- 17. Scarlet Monastery: Cathedral (Classic)
    {
        id = "sm_cathedral",
        name = "Scarlet Monastery: Cathedral",
        category = "CLASSIC",
        level = "38-46",
        minLevel = 38,
        maxLevel = 46,
        location = "Tirisfal Glades",
        description = "The grand Chapel Gardens and Cathedral of the Scarlet Monastery, defended by Scarlet Commander Mograine and High Inquisitor Whitemane.",
        icon = "Interface\\Icons\\Spell_Holy_Resurrection",
        art = {
            LOAD_SCREEN .. "LoadScreenMonastery",
            LOAD_SCREEN .. "LoadScreenScarletMonastery",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "sm cath", "sm cathedral", "cathedral", "mograine", "whitemane" },
        bosses = {
            { name = "High Inquisitor Fairbanks", level = "40", npcID = 4542, displayID = 2605, description = "Hidden behind a secret torch lever in the eastern transept." },
            { name = "Scarlet Commander Mograine", level = "42", npcID = 3976, displayID = 2042, description = "Commander of the Cathedral garrison who is resurrected by Whitemane." },
            { name = "High Inquisitor Whitemane", level = "42", npcID = 3977, displayID = 2043, description = "Emerges from the altar sanctuary to cast Deep Sleep and Power Word: Resurrection." },
        },
    },

    -- 18. Razorfen Downs (Classic)
    {
        id = "razorfen_downs",
        name = "Razorfen Downs",
        category = "CLASSIC",
        level = "37-46",
        minLevel = 37,
        maxLevel = 46,
        location = "Southern Barrens",
        description = "The ancient capital of the quilboar race, now corrupted by the Scourge lich Amnennar the Coldbringer and his undead Death's Head converts.",
        icon = "Interface\\Icons\\Spell_Frost_FrostArmor02",
        art = {
            LOAD_SCREEN .. "LoadScreenRazorfenDowns",
            LOAD_SCREEN .. "LoadScreenRazorfen",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "rfd", "downs" },
        bosses = {
            { name = "Tuten'kash", level = "40", npcID = 7355, displayID = 7845, description = "Summoned by striking the gong three times to defeat waves of undead spiders." },
            { name = "Mordresh Fire Eye", level = "39", npcID = 7357, displayID = 8055, description = "Skeletal pyromancer preaching atop the bone mound." },
            { name = "Glutton", level = "40", npcID = 8567, displayID = 7864, description = "Stitched abomination patrolling the lower bone trenches." },
            { name = "Ragglesnout", level = "37", npcID = 7354, displayID = 11382, rare = true, description = "Rare quilboar warlock." },
            { name = "Amnennar the Coldbringer", level = "41", npcID = 7358, displayID = 7971, description = "Scourge lich ruling atop Spiral Mound." },
            { name = "Plaguemaw the Rotting", level = "40", npcID = 7356, displayID = 6124, description = "Summoned during Belnistrasz's idol cleansing event." },
            { name = "Henry Stern", level = "38", npcID = 8696, displayID = 8029, isMinor = true, description = "Captive human who teaches herbalism and cooking recipes." },
        },
    },

    -- 19. Uldaman (Classic)
    {
        id = "uldaman",
        name = "Uldaman",
        category = "CLASSIC",
        level = "41-51",
        minLevel = 41,
        maxLevel = 51,
        location = "Badlands",
        description = "An ancient Titan vault buried deep beneath the Badlands where the earthen first awoke, guarded by the titanic watcher Archaedas.",
        icon = "Interface\\Icons\\INV_Misc_StoneTablet_11",
        art = { LOAD_SCREEN .. "LoadScreenUldaman", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "ulda", "uldaman" },
        bosses = {
            { name = "Baelog", level = "41", npcID = 6906, displayID = 5710, description = "Leader of the Lost Dwarves expedition." },
            { name = "Olaf", level = "40", npcID = 6908, displayID = 5709, description = "Stout dwarf warrior of the Lost Dwarves." },
            { name = "Eric \"The Swift\"", level = "40", npcID = 6907, displayID = 5708, description = "Swift-footed explorer of the Lost Dwarves." },
            { name = "Revelosh", level = "40", npcID = 6910, displayID = 5945, description = "Trogg keeper of the Shaft of Tsol." },
            { name = "Ironaya", level = "40", npcID = 7228, displayID = 6089, description = "Giant Titan watcher awakened by placing the Staff of Prehistoria in the Map Chamber." },
            { name = "Obsidian Sentinel", level = "42", icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", description = "Fragmenting obsidian construct in the northern hall." },
            { name = "Ancient Stone Keeper", level = "44", npcID = 7206, displayID = 10798, description = "Sandstorm-summoning stone sentinel guarding the inner halls." },
            { name = "Galgann Firehammer", level = "45", npcID = 7291, displayID = 6059, description = "Dark Iron excavation leader in Dig Three." },
            { name = "Grimlok", level = "45", npcID = 4854, displayID = 11165, description = "Stonevault trogg chieftain." },
            { name = "Archaedas", level = "47", npcID = 2748, displayID = 5988, description = "Final boss. Titanic stone watcher guarding the Discs of Norgannon." },
        },
    },

    -- 20. Krol'dok Stronghold (WoW Forever — Coming Soon)
    {
        id = "kroldok_stronghold",
        name = "Krol'dok Stronghold",
        category = "COMING_SOON",
        level = "40-47",
        minLevel = 40,
        maxLevel = 47,
        location = "Riverglades",
        description = "A fortified ogre stronghold of workshops, encampments, and Twilight's Hammer inner passages in the Riverglades, ruled by Overlord Mugg.",
        icon = "Interface\\Icons\\INV_Misc_Key_13",
        art = {
            7963780,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "krol", "kroldok", "riverglades" },
        bosses = {
            { name = "Slavecrusher Grox", level = "42", npcID = 258966, displayID = 141217, description = "Brutal ogre taskmaster overseeing the outer work pits." },
            { name = "Twilight Commander Zarmok", level = "43", npcID = 258972, displayID = 141219, description = "Commander of the Twilight's Hammer contingent inside Krol'dok." },
            { name = "War Handler Ashka", level = "43", npcID = 259281, displayID = 141443, description = "Ogre beastmaster accompanied by her war wolves." },
            { name = "Bossman Toof", level = "42", npcID = 264773, displayID = 14424, description = "Foreman of the stronghold workshops." },
            { name = "Nar'gurk", level = "44", npcID = 258964, displayID = 141215, description = "Ogre warlock guarding the Tome of Twilight." },
            { name = "Overlord Mugg", level = "45", npcID = 258968, displayID = 141218, description = "Final boss and supreme ruler of Krol'dok Stronghold." },
        },
    },
    -- 21. Zul'Farrak (Classic)
    {
        id = "zulfarrak",
        name = "Zul'Farrak",
        category = "CLASSIC",
        level = "44-54",
        minLevel = 44,
        maxLevel = 54,
        location = "Tanaris",
        description = "The sun-baked open-air troll city in the deserts of Tanaris, stronghold of the Sandfury tribe and the sacred hydra Gahz'rilla.",
        icon = "Interface\\Icons\\INV_Misc_Head_Troll_01",
        art = { LOAD_SCREEN .. "LoadScreenZulFarrak", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "zf", "zulfarrak", "zul'farrak" },
        bosses = {
            { name = "Antu'sul", level = "48", npcID = 8127, displayID = 7353, description = "Overseer of the Sul'lithuz basilisk pit." },
            { name = "Theka the Martyr", level = "46", npcID = 7272, displayID = 6696, description = "Scarabs transform and swarm when Theka is engaged." },
            { name = "Sandarr Dunereaver", level = "45", npcID = 10080, displayID = 9291, rare = true, description = "Rare desert stalker." },
            { name = "Witch Doctor Zum'rah", level = "46", npcID = 7271, displayID = 6434, description = "Raises Zul'Farrak zombies from the shallow graves." },
            { name = "Nekrum Gutchewer", level = "45", npcID = 7796, displayID = 6690, description = "Fought alongside Shadowpriest Sezz'ziz during the temple steps siege." },
            { name = "Shadowpriest Sezz'ziz", level = "47", npcID = 7275, displayID = 6441, description = "Dark priest atop the execution pyramid." },
            { name = "Dustwraith", level = "45", npcID = 10081, displayID = 9292, rare = true, description = "Rare witch doctor near the temple pyramid." },
            { name = "Sandfury Executioner", level = "46", npcID = 7274, displayID = 6440, isMinor = true, description = "Sandfury troll holding the executioner's key atop the pyramid." },
            { name = "Sergeant Bly", level = "45", npcID = 7604, displayID = 6433, description = "Mercenary leader fought after surviving the pyramid wave event." },
            { name = "Hydromancer Velratha", level = "46", npcID = 7795, displayID = 6685, description = "Patrols the sacred pool beside the Gong of Zul'Farrak." },
            { name = "Gahz'rilla", level = "46", npcID = 7273, displayID = 7271, description = "Summoned at the pool with the Mallet of Zul'Farrak." },
            { name = "Chief Ukorz Sandscalp", level = "48", npcID = 7267, displayID = 6439, description = "Chieftain of the Sandfury tribe, fought alongside his bodyguard Ruuzlu." },
            { name = "Zerillis", level = "45", npcID = 10082, displayID = 9293, rare = true, description = "Rare Sandfury executioner wandering the dunes." },
        },
    },

    -- 22. Maraudon (Classic)
    {
        id = "maraudon",
        name = "Maraudon",
        category = "CLASSIC",
        level = "46-55",
        minLevel = 46,
        maxLevel = 55,
        location = "Valley of Spears, Desolace",
        description = "Sacred burial site of Zaetar, divided between the corrupted Orange/Purple wings and the subterranean waterfall realm of Princess Theradras.",
        icon = "Interface\\Icons\\Spell_Nature_Acid_01",
        art = { LOAD_SCREEN .. "LoadScreenMaraudon", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "mara", "maraudon", "theradras" },
        bosses = {
            { name = "Veng", level = "47", npcID = 13738, displayID = 9418, isMinor = true, description = "Centaur khan spirit roaming the Wicked Grotto." },
            { name = "Noxxion", level = "48", npcID = 13282, displayID = 11172, description = "Toxic elemental in the Orange wing who splits into smaller spawns." },
            { name = "Razorlash", level = "48", npcID = 12258, displayID = 12389, description = "Carnivorous lasher guardian in the Orange caverns." },
            { name = "Maraudos", level = "47", npcID = 13739, displayID = 9441, isMinor = true, description = "Centaur khan spirit in the Foulspore Caverns." },
            { name = "Lord Vyletongue", level = "47", npcID = 12236, displayID = 12334, description = "Satyr lord in the Purple wing who holds the Celebrium Rod." },
            { name = "Meshlok the Harvester", level = "48", npcID = 12237, displayID = 9014, rare = true, description = "Rare fungal monster." },
            { name = "Celebras the Cursed", level = "49", npcID = 12225, displayID = 12350, description = "Corrupted keeper who helps forge the Scepter of Celebras once freed." },
            { name = "Landslide", level = "50", npcID = 12203, displayID = 12293, description = "Towering crystal giant in the inner earth caverns." },
            { name = "Tinkerer Gizlock", level = "50", npcID = 13601, displayID = 7125, description = "Deranged goblin engineer on the stone scaffolding." },
            { name = "Rotgrip", level = "50", npcID = 13596, displayID = 13589, description = "Massive albino snapjaw in the subterranean river." },
            { name = "Princess Theradras", level = "51", npcID = 12201, displayID = 12292, description = "Earth elemental princess guarding Zaetar's resting place." },
            { name = "The Nameless Prophet", level = "46", npcID = 13718, displayID = 9426, isMinor = true, description = "Ghostly prophet outside the inner sanctum." },
            { name = "Kolk", level = "46", npcID = 13742, displayID = 4860, isMinor = true, description = "First centaur khan spirit." },
            { name = "Gelk", level = "47", npcID = 13741, displayID = 9427, isMinor = true, description = "Centaur khan spirit of the outer tunnels." },
            { name = "Magra", level = "47", npcID = 13740, displayID = 9433, isMinor = true, description = "Centaur khan spirit." },
        },
    },

    -- 23. Alcaz Prison (WoW Forever — Coming Soon)
    {
        id = "alcaz_prison",
        name = "Alcaz Prison",
        category = "COMING_SOON",
        level = "48-55",
        minLevel = 48,
        maxLevel = 55,
        location = "Alcaz Island, Dustwallow Marsh",
        description = "Deep beneath the naga-infested jungles of Alcaz Island lies a subterranean prison complex holding high-value captives and dark secrets.",
        icon = "Interface\\Icons\\INV_Misc_Key_07",
        art = {
            7963734,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "alcaz", "alcaz island" },
        bosses = {
            { name = "Tidemistress Ca'zass", level = "50", npcID = 255997, displayID = 4973, description = "Naga sea-witch commanding the flooded lower vaults." },
            { name = "Overseer Wrex", level = "50", npcID = 255391, displayID = 7914, description = "Warden of the outer detention blocks." },
            { name = "Katerina the Cleaner", level = "52", npcID = 257016, displayID = 2317, description = "Deadly operative tasked with erasing evidence." },
            { name = "The Questioner", level = "51", npcID = 256236, displayID = 140092, description = "Chief interrogator of Alcaz Prison." },
        },
    },

    -- 24. Sunken Temple (Classic)
    {
        id = "sunken_temple",
        name = "Sunken Temple",
        category = "CLASSIC",
        level = "50-60",
        minLevel = 50,
        maxLevel = 60,
        location = "Swamp of Sorrows",
        description = "The Temple of Atal'Hakkar, where exiled Atal'ai priests seek to summon the blood god Hakkar while green dragonflight guardians battle the corruption.",
        icon = "Interface\\Icons\\Spell_Nature_Thorns",
        art = { LOAD_SCREEN .. "LoadScreenSunkenTemple", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "st", "sunken temple", "atal'hakkar", "atalhakkar" },
        bosses = {
            { name = "Balcony Minibosses", level = "50", displayID = 6701, isMinor = true, description = "The six Atal'ai troll priests channeling dark magic on the upper balcony." },
            { name = "Atal'alarion", level = "50", npcID = 8580, displayID = 7873, description = "Summoned in the basement after activating the six snake statues in sequence." },
            { name = "Spawn of Hakkar", level = "51", npcID = 5708, displayID = 4065, isMinor = true, description = "Summoned serpent avatar during the blood ritual of Hakkar." },
            { name = "Avatar of Hakkar", level = "55", npcID = 8443, displayID = 8053, description = "Summoned in the Hall of Masks using the Egg of Hakkar." },
            { name = "Jammal'an the Prophet", level = "54", npcID = 5710, displayID = 6708, description = "Leader of the Atal'ai trolls whose death lowers the barrier to Eranikus." },
            { name = "Ogom the Wretched", level = "53", npcID = 5711, displayID = 6709, description = "Undead lieutenant fought alongside Jammal'an." },
            { name = "Dreamscythe", level = "50", npcID = 5721, displayID = 7553, description = "Green dragon whelp patrolling the upper ring of the temple." },
            { name = "Weaver", level = "50", npcID = 5720, displayID = 6375, description = "Corrupted green dragon guarding the upper terrace." },
            { name = "Hazzas", level = "50", npcID = 5722, displayID = 9584, description = "Corrupted green drake of the Nightmare." },
            { name = "Morphaz", level = "50", npcID = 5719, displayID = 7975, description = "Green dragon miniboss guarding the temple balcony." },
            { name = "Shade of Eranikus", level = "55", npcID = 5709, displayID = 7806, description = "Nightmare-twisted consort of Ysera sleeping in the inner sanctum." },
        },
    },

    -- 25. Blackrock Depths (Classic)
    {
        id = "blackrock_depths",
        name = "Blackrock Depths",
        category = "CLASSIC",
        level = "52-60",
        minLevel = 52,
        maxLevel = 60,
        location = "Blackrock Mountain",
        description = "The sprawling subterranean city of Shadowforge, capital of the Dark Iron dwarves ruled by Emperor Dagran Thaurissan beneath Blackrock Mountain.",
        icon = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras",
        art = { LOAD_SCREEN .. "LoadScreenBlackrockDepths", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "brd", "depths", "shadowforge" },
        bosses = {
            { name = "Coren Direbrew", level = "??", npcID = 23872, displayID = 21824, isEvent = true, holiday = "Brewfest", description = "Dark Iron brewmaster fought during the Brewfest seasonal event." },
            { name = "Lord Roccor", level = "51", npcID = 9025, displayID = 5781, description = "Earth elemental patrolling the Detention Block ring." },
            { name = "High Interrogator Gerstahn", level = "52", npcID = 9018, displayID = 8761, description = "Warden of the Detention Block holding the Prison Cell Key." },
            { name = "Houndmaster Grebmar", level = "52", npcID = 9319, displayID = 9212, description = "Keeper of the Dark Iron darkhounds." },
            { name = "Gorosh the Dervish", level = "52", npcID = 9027, displayID = 8760, description = "Gladiator champion in the Ring of Law." },
            { name = "Grizzle", level = "52", npcID = 9028, displayID = 7873, description = "Dire brew ogre gladiator in the Ring of Law." },
            { name = "Eviscerator", level = "52", npcID = 9029, displayID = 523, description = "Orc rogue gladiator in the Ring of Law." },
            { name = "Ok'thor the Breaker", level = "52", npcID = 9030, displayID = 11538, description = "Ogre magi gladiator in the Ring of Law." },
            { name = "Anub'shiah", level = "52", npcID = 9031, displayID = 3004, description = "Crypt fiend gladiator in the Ring of Law." },
            { name = "Hedrum the Creeper", level = "52", npcID = 9032, displayID = 8271, description = "Giant spider gladiator in the Ring of Law." },
            { name = "Pyromancer Loregrain", level = "52", npcID = 9024, displayID = 8762, description = "Twilight's Hammer cultist at the Shrine of Thaurissan." },
            { name = "Warder Stilgiss", level = "56", npcID = 9041, displayID = 9089, description = "Guards the Dark Coffer vault with his hound Verek." },
            { name = "Verek", level = "52", npcID = 9042, displayID = 9019, rare = true, description = "Rare Dark Iron warder patrolling the detention cells." },
            { name = "Watchman Doomgrip", level = "54", npcID = 9476, displayID = 8655, isMinor = true, description = "Dark Iron officer holding the Relic Coffer Key." },
            { name = "Fineous Darkvire", level = "54", npcID = 9056, displayID = 8704, description = "Chief architect who drops the Ironfel hammer." },
            { name = "Lord Incendius", level = "55", npcID = 9017, displayID = 1204, description = "Firelord guarding the Black Anvil." },
            { name = "Bael'Gar", level = "54", npcID = 9016, displayID = 12162, description = "Molten giant at the end of the Dark Iron Highway." },
            { name = "General Angerforge", level = "57", npcID = 9033, displayID = 8756, description = "Commander of the West Garrison." },
            { name = "Golem Lord Argelmach", level = "57", npcID = 8983, displayID = 8759, description = "Master of the Manufactory golem foundry." },
            { name = "The Grim Guzzler", level = "53-55", npcID = 9537, displayID = 8658, description = "Tavern encounter featuring patrons and bouncers Hurley, Phalanx, Plugger, and Ribbly." },
            { name = "Phalanx", level = "55", npcID = 9502, displayID = 8177, description = "The mighty iron golem guarding the exit door of the Grim Guzzler." },
            { name = "Ambassador Flamelash", level = "57", npcID = 9156, displayID = 8329, description = "Firelord emissary in the Chamber of Enchantment." },
            { name = "Panzor the Invincible", level = "57", npcID = 8923, displayID = 8270, rare = true, description = "Rare stone golem in the Mold Foundry." },
            { name = "The Seven", level = "57", npcID = 9039, displayID = 8687, description = "Seven spectral Dark Iron thanes guarding the Chest of The Seven." },
            { name = "Magmus", level = "57", npcID = 9938, displayID = 12162, description = "Molten giant guarding the Iron Hall before the throne room." },
            { name = "Princess Moira Bronzebeard", level = "58", npcID = 8929, displayID = 8705, description = "Heir of Ironforge standing beside Emperor Thaurissan." },
            { name = "Emperor Dagran Thaurissan", level = "59", npcID = 9019, displayID = 8807, description = "Final boss. Ruler of the Dark Iron clan in the Imperial Seat." },
            { name = "Theldren", level = "60", npcID = 16059, displayID = 15981, isChallenge = true, description = "Dungeon Set 2 challenge arena champion summoned in the Ring of Law." },
        },
    },

    -- 26. Lower Blackrock Spire (Classic)
    {
        id = "lower_blackrock_spire",
        name = "Lower Blackrock Spire",
        category = "CLASSIC",
        level = "55-60",
        minLevel = 55,
        maxLevel = 60,
        location = "Blackrock Mountain",
        description = "The lower halls of Blackrock Spire, held by the Spirestone ogres, Smolderthorn trolls, and Bloodaxe orcs of the Dark Horde under Overlord Wyrmthalak.",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
        art = { LOAD_SCREEN .. "LoadScreenBlackrockSpire", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "lbrs", "lower spire" },
        bosses = {
            { name = "Burning Felguard", level = "57", npcID = 10263, displayID = 5047, isMinor = true, description = "Demonic summoned guard." },
            { name = "Spirestone Butcher", level = "57", npcID = 9219, displayID = 11574, rare = true, description = "Rare ogre butcher in the lower caves." },
            { name = "Highlord Omokk", level = "59", npcID = 9196, displayID = 11565, description = "Spirestone ogre chieftain in Hordemar City." },
            { name = "Spirestone Battle Lord", level = "58", npcID = 9218, displayID = 11576, rare = true, description = "Rare ogre war-leader." },
            { name = "Spirestone Lord Magus", level = "57", npcID = 9217, displayID = 11578, rare = true, description = "Rare ogre magi commander." },
            { name = "Shadow Hunter Vosh'gajin", level = "58", npcID = 9236, displayID = 9732, description = "Smolderthorn shadow hunter who hexes party members." },
            { name = "War Master Voone", level = "59", npcID = 9237, displayID = 9733, description = "Leader of the Smolderthorn troll contingent." },
            { name = "Bannok Grimaxe", level = "59", npcID = 9596, displayID = 9668, rare = true, description = "Rare orc champion wandering the upper ramps." },
            { name = "Mother Smolderweb", level = "59", npcID = 10596, displayID = 9929, description = "Giant spider queen in the Skitterweb Tunnels." },
            { name = "Crystal Fang", level = "60", npcID = 10376, displayID = 9755, rare = true, description = "Rare crystalline spider in the lower tunnels." },
            { name = "Urok Doomhowl", level = "60", npcID = 10584, displayID = 11583, description = "Summoned at his tribute pile with Omokk's head on a Roughshod Pike." },
            { name = "Quartermaster Zigris", level = "59", npcID = 9736, displayID = 9738, description = "Bloodaxe quartermaster in the Storehouse." },
            { name = "Halycon", level = "59", npcID = 10220, displayID = 9567, description = "Bloodaxe worg den mother." },
            { name = "Gizrul the Slavener", level = "60", npcID = 10268, displayID = 9564, description = "Pack alpha that emerges immediately after Halycon falls." },
            { name = "Ghok Bashguud", level = "59", npcID = 9718, displayID = 11809, rare = true, description = "Rare ogre sub-chieftain." },
            { name = "Overlord Wyrmthalak", level = "60", npcID = 9568, displayID = 8711, description = "Final boss of Lower Blackrock Spire in the Chamber of Battle." },
            { name = "Mor Grayhoof", level = "60", npcID = 16080, displayID = 15997, isChallenge = true, description = "Dungeon Set 2 summoned spirit." },
        },
    },

    -- 27. Upper Blackrock Spire (Classic)
    {
        id = "upper_blackrock_spire",
        name = "Upper Blackrock Spire",
        category = "CLASSIC",
        level = "59-60",
        minLevel = 59,
        maxLevel = 60,
        location = "Blackrock Mountain",
        description = "The upper citadel of Blackrock Spire, unlocked with the Seal of Ascension and ruled by Warchief Rend Blackhand and General Drakkisath.",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
        art = { LOAD_SCREEN .. "LoadScreenBlackrockSpire", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "ubrs", "upper spire", "rend", "drakkisath" },
        bosses = {
            { name = "Pyroguard Emberseer", level = "60", npcID = 9816, displayID = 2172, description = "Fire elemental bound inside the Hall of Binding." },
            { name = "Solakar Flamewreath", level = "60", npcID = 10264, displayID = 9581, description = "Summoned by clicking the Father Flame in the Rookery." },
            { name = "Jed Runewatcher", level = "59", npcID = 10509, displayID = 9686, rare = true, description = "Rare Dark Horde runemaster before the stadium." },
            { name = "Goraluk Anvilcrack", level = "61", npcID = 10899, displayID = 10222, description = "Master blacksmith of the Blackhand legion." },
            { name = "Gyth", level = "62", npcID = 10339, displayID = 9806, description = "Chromatic dragon mount of Rend Blackhand." },
            { name = "Warchief Rend Blackhand", level = "62", npcID = 10429, displayID = 9778, description = "False Warchief of the Dark Horde fought in Blackrock Stadium." },
            { name = "The Beast", level = "62", npcID = 10430, displayID = 10193, description = "Colossal core hound in the Furnace." },
            { name = "General Drakkisath", level = "62", npcID = 10363, displayID = 10115, description = "Final boss. Nefarian's general guarding the Brand of Drakkisath." },
            { name = "Lord Valthalak", level = "62", npcID = 16042, displayID = 14308, isChallenge = true, description = "Dungeon Set 2 summoned boss in the Stadium." },
        },
    },

    -- 28. Dire Maul: East (Classic)
    {
        id = "dire_maul_east",
        name = "Dire Maul: East",
        category = "CLASSIC",
        level = "54-60",
        minLevel = 54,
        maxLevel = 60,
        location = "Feralas",
        description = "Warpwood Quarter — the eastern wing of ancient Eldre'Thalas, overrun by satyrs and corrupted plant life under Alzzin the Wildshaper.",
        icon = "Interface\\Icons\\Spell_Nature_Preservation",
        art = { LOAD_SCREEN .. "LoadScreenDireMaul", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "dme", "dm east", "warpwood" },
        bosses = {
            { name = "Pusillin", level = "57", npcID = 14354, displayID = 7552, description = "Mischievous imp chased through the conservatory for the Crescent Key." },
            { name = "Zevrim Thornhoof", level = "57", npcID = 11490, displayID = 11335, description = "Satyr warlock who teleports players onto his sacrificial altar." },
            { name = "Hydrospawn", level = "57", npcID = 13280, displayID = 5489, description = "Water elemental lord in the sunken pool." },
            { name = "Lethtendris", level = "57", npcID = 14327, displayID = 14378, description = "Blood elf warlock accompanied by her imp Pimgib." },
            { name = "Alzzin the Wildshaper", level = "58", npcID = 11492, displayID = 14416, description = "Final boss. Shapeshifting satyr lord in the Shrine of Eldretharr." },
            { name = "Isalien", level = "60", npcID = 16097, displayID = 16000, isChallenge = true, description = "Dungeon Set 2 highborne priestess boss." },
        },
    },

    -- 29. Blackmaw Hold (WoW Forever — Coming Soon)
    {
        id = "blackmaw_hold",
        name = "Blackmaw Hold",
        category = "COMING_SOON",
        level = "55-60",
        minLevel = 55,
        maxLevel = 60,
        location = "Azshara / Felwood",
        description = "The subterranean timbermaw fortress of the corrupted Blackmaw furbolg tribe, ruled by Elder Shaman Bloodmane and Varrox Bleakhoof.",
        icon = "Interface\\Icons\\INV_Misc_MonsterClaw_04",
        art = {
            7963784,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "bmh", "blackmaw", "furbolg" },
        bosses = {
            { name = "Withermaw", level = "58", npcID = 247195, displayID = 140708, description = "Plague-blighted ursine monstrosity." },
            { name = "Bonesnout the Unbroken", level = "58", npcID = 247198, displayID = 130427, description = "Veteran Blackmaw war-champion." },
            { name = "Moontouched Wanderer", level = "55", npcID = 269104, displayID = 12235, description = "Corrupted ancient wandering the outer burrows." },
            { name = "Impaan the Imprisoner", level = "57", npcID = 247206, displayID = 130432, description = "Jailer of the Blackmaw stockades." },
            { name = "Unbound Spirit", level = "59", npcID = 247231, displayID = 131644, description = "Tormented ancestral spirit." },
            { name = "Blackmaw Behemoth", level = "59", npcID = 247207, displayID = 130436, description = "Colossal furbolg juggernaut." },
            { name = "Varrox Bleakhoof", level = "60", npcID = 247234, displayID = 130447, description = "Final boss of Blackmaw Hold." },
            { name = "Elder Shaman Bloodmane", level = "59", npcID = 247209, displayID = 130440, description = "Spiritual leader of the corrupted Blackmaw tribe." },
        },
    },

    -- 30. Dire Maul: West (Classic)
    {
        id = "dire_maul_west",
        name = "Dire Maul: West",
        category = "CLASSIC",
        level = "56-60",
        minLevel = 56,
        maxLevel = 60,
        location = "Feralas",
        description = "Capital Gardens — the western wing of Eldre'Thalas where the Shen'dralar Highborne siphon demonic energy from the bound demon Immol'thar.",
        icon = "Interface\\Icons\\Spell_Nature_Preservation",
        art = { LOAD_SCREEN .. "LoadScreenDireMaul", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "dmw", "dm west", "capital gardens" },
        bosses = {
            { name = "Tendris Warpwood", level = "60", npcID = 11489, displayID = 14383, description = "Ancient protector linked to all living protectors in the courtyard." },
            { name = "Illyanna Ravenoak", level = "60", npcID = 11488, displayID = 11270, description = "Highborne huntress fought alongside her undead bear Ferra." },
            { name = "Magister Kalendris", level = "60", npcID = 11487, displayID = 14384, description = "Highborne arcanist guarding the upper ramparts." },
            { name = "Tsu'zee", level = "59", npcID = 11467, displayID = 11250, rare = true, description = "Rare Highborne ghost." },
            { name = "Immol'thar", level = "61", npcID = 11496, displayID = 14173, description = "Void terror bound inside the Prison of Immol'thar." },
            { name = "Prince Tortheldrin", level = "61", npcID = 11486, displayID = 11256, description = "Final boss. Immortal ruler of the Shen'dralar in the Athenaeum." },
            { name = "Lord Hel'nurath", level = "62", npcID = 14506, displayID = 14556, rare = true, description = "Summoned during the Warlock dreadsteed quest ritual." },
        },
    },

    -- 31. Dire Maul: North (Classic)
    {
        id = "dire_maul_north",
        name = "Dire Maul: North",
        category = "CLASSIC",
        level = "56-60",
        minLevel = 56,
        maxLevel = 60,
        location = "Feralas",
        description = "Gordok Commons — the northern ogre wing of Eldre'Thalas where players can either slay the Gordok guards or complete a Tribute run to become King.",
        icon = "Interface\\Icons\\Spell_Nature_Preservation",
        art = { LOAD_SCREEN .. "LoadScreenDireMaul", LOAD_SCREEN .. "LoadScreenDungeon" },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "dmn", "dm north", "tribute", "gordok" },
        bosses = {
            { name = "Guard Mol'dar", level = "59", npcID = 14326, displayID = 11561, description = "First Gordok guard in the lower courtyard." },
            { name = "Stomper Kreeg", level = "59", npcID = 14322, displayID = 11545, description = "Drunken Gordok brewer." },
            { name = "Guard Fengus", level = "59", npcID = 14321, displayID = 11561, description = "Patrols the central courtyard and guards the Gordok Inner Door Key." },
            { name = "Guard Slip'kik", level = "59", npcID = 14323, displayID = 11561, description = "Can be frozen in a frost trap during a Tribute run." },
            { name = "Captain Kromcrush", level = "61", npcID = 14325, displayID = 11564, description = "Commander of the Gordok king's guard." },
            { name = "Cho'Rush the Observer", level = "60", npcID = 14324, displayID = 11537, description = "Ogre magi advisor fought alongside King Gordok." },
            { name = "King Gordok", level = "62", npcID = 11501, displayID = 11583, description = "Final boss. Slaying him while leaving the guards alive unlocks the Gordok Tribute chest." },
        },
    },

    -- 32. Stratholme: Living (Classic)
    {
        id = "stratholme_living",
        name = "Stratholme: Living",
        category = "CLASSIC",
        level = "58-60",
        minLevel = 58,
        maxLevel = 60,
        location = "Eastern Plaguelands",
        description = "King's Square & Scarlet Bastion — the western side of burning Stratholme held by the Crimson Legion under Grand Crusader Dathrohan (Balnazzar).",
        icon = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
        art = {
            131871,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "strat live", "strat living", "living", "balnazzar" },
        bosses = {
            { name = "Skul", level = "58", npcID = 10393, displayID = 2606, rare = true, description = "Rare skeletal mage near the entrance." },
            { name = "Stratholme Courier", level = "57", npcID = 11082, displayID = 10547, isMinor = true, description = "Carries the Stratholme mailbox keys and postmaster summons." },
            { name = "Hearthsinger Forresten", level = "57", npcID = 10558, displayID = 10482, rare = true, description = "Undead bard wandering Elders' Square." },
            { name = "The Unforgiven", level = "57", npcID = 10516, displayID = 10771, description = "Tormented banshee in the north archway." },
            { name = "Postmaster Malown", level = "60", npcID = 11143, displayID = 10669, description = "Summoned by opening three Stratholme mailboxes." },
            { name = "Timmy the Cruel", level = "58", npcID = 10808, displayID = 571, description = "Ghoul monstrosity that spawns outside the Scarlet Bastion." },
            { name = "Malor the Zealous", level = "60", npcID = 11032, displayID = 10458, isMinor = true, description = "Scarlet champion guarding the Medallion of Faith." },
            { name = "Crimson Hammersmith", level = "60", npcID = 11120, displayID = 10637, isMinor = true, description = "Blacksmithing plans keeper." },
            { name = "Cannon Master Willey", level = "60", npcID = 10997, displayID = 10674, description = "Commands the Scarlet artillery room." },
            { name = "Archivist Galford", level = "60", npcID = 10811, displayID = 10544, description = "Keeper of the Scarlet Bastion archives." },
            { name = "Balnazzar", level = "62", npcID = 10813, displayID = 10691, description = "Final boss. Dreadlord disguised as Grand Crusader Dathrohan." },
            { name = "Jarien and Sothos", level = "60", npcID = 16057, displayID = 15998, isChallenge = true, description = "Dungeon Set 2 summoned spectral champions in Elders' Square." },
        },
    },

    -- 33. Stratholme: Undead (Classic)
    {
        id = "stratholme_undead",
        name = "Stratholme: Undead",
        category = "CLASSIC",
        level = "58-60",
        minLevel = 58,
        maxLevel = 60,
        location = "Eastern Plaguelands",
        description = "The Gauntlet & Slaughter Square — the eastern Scourge-controlled district of Stratholme ruled by Baron Rivendare from the Slaughterhouse.",
        icon = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
        art = {
            131871,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "strat ud", "strat undead", "undead", "rivendare" },
        bosses = {
            { name = "Magistrate Barthilas", level = "58", npcID = 10435, displayID = 10433, description = "Former magistrate of Stratholme who flees toward the Service Entrance." },
            { name = "Stonespine", level = "60", npcID = 10809, displayID = 7856, rare = true, description = "Rare gargoyle patrolling the undead streets." },
            { name = "Baroness Anastari", level = "59", npcID = 10436, displayID = 10698, description = "Banshee guarding the first ziggurat." },
            { name = "Nerub'enkan", level = "60", npcID = 10437, displayID = 9793, description = "Crypt lord guarding the second ziggurat." },
            { name = "Maleki the Pallid", level = "61", npcID = 10438, displayID = 10546, description = "Scourge necromancer guarding the third ziggurat." },
            { name = "Black Guard Swordsmith", level = "60", npcID = 11121, displayID = 775, isMinor = true, description = "Blacksmithing plans keeper." },
            { name = "Ramstein the Gorger", level = "61", npcID = 10439, displayID = 12818, description = "Elite abomination unleashed in Slaughter Square." },
            { name = "Baron Rivendare", level = "62", npcID = 10440, displayID = 10729, description = "Final boss. Death Knight lord of Stratholme in the Slaughterhouse." },
        },
    },

    -- 34. Scholomance (Classic)
    {
        id = "scholomance",
        name = "Scholomance",
        category = "CLASSIC",
        level = "58-60",
        minLevel = 58,
        maxLevel = 60,
        location = "Caer Darrow, Western Plaguelands",
        description = "The haunted crypts beneath ruined Caer Darrow, transformed by the Barov family's pact with Kel'Thuzad into the premier academy of necromancy under Darkmaster Gandling.",
        icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",
        art = {
            LOAD_SCREEN .. "LoadScreenScholomance",
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "scholo", "scholomance", "gandling" },
        bosses = {
            { name = "Blood Steward of Kirtonos", level = "61", npcID = 14861, displayID = 10925, isMinor = true, description = "Summoner servant on the porch of Kirtonos." },
            { name = "Kirtonos the Herald", level = "60", npcID = 10506, displayID = 143673, description = "Gargoyle summoned on the porch using the Blood of Innocents." },
            { name = "Jandice Barov", level = "61", npcID = 10503, displayID = 11073, description = "Illusionist hiding in the cellar crypts." },
            { name = "Rattlegore", level = "61", npcID = 11622, displayID = 12073, description = "Bone construct in the Great Ossuary who drops the Viewing Room Key." },
            { name = "Death Knight Darkreaver", level = "61", npcID = 14516, displayID = 14591, description = "Fallen death knight summoned during the Paladin Epic Charger questline." },
            { name = "Marduk Blackpool", level = "58", npcID = 10433, displayID = 10248, description = "Necromancer professor instructing students in the Viewing Room." },
            { name = "Vectus", level = "60", npcID = 10432, displayID = 2606, description = "Undead instructor channeling plague experiments in the Viewing Room." },
            { name = "Ras Frostwhisper", level = "62", npcID = 10508, displayID = 7919, description = "Lich lord of the Frostwhisper Laboratory." },
            { name = "Instructor Malicia", level = "60", npcID = 10505, displayID = 11069, description = "Guards the southeastern study room of the Headmaster's Study." },
            { name = "Doctor Theolen Krastinov", level = "60", npcID = 11261, displayID = 10901, description = "\"The Butcher\" in the eastern study room." },
            { name = "Lorekeeper Polkelt", level = "60", npcID = 10901, displayID = 11492, description = "Plague-bloated scholar in the northern study room." },
            { name = "The Ravenian", level = "60", npcID = 10507, displayID = 10433, description = "Feral guardian of the lower western study room." },
            { name = "Lord Alexei Barov", level = "60", npcID = 10504, displayID = 11072, description = "Undead patriarch of House Barov." },
            { name = "Lady Illucia Barov", level = "60", npcID = 10502, displayID = 11835, description = "Undead matriarch of House Barov." },
            { name = "Darkmaster Gandling", level = "61", npcID = 1853, displayID = 11070, description = "Final boss. Headmaster who appears once all six study bosses are slain." },
            { name = "Kormok", level = "60", npcID = 16118, displayID = 16020, isChallenge = true, description = "Summoned necromancer boss for the Dungeon Set 2 quest chain." },
        },
    },

    -- 35. Shaper's Terrace (WoW Forever — Coming Soon)
    {
        id = "shapers_terrace",
        name = "Shaper's Terrace",
        category = "COMING_SOON",
        level = "58-60",
        minLevel = 58,
        maxLevel = 60,
        location = "Un'Goro Crater",
        description = "An ancient Titan experimentation terrace overlooking Un'Goro Crater, inhabited by colossal primal beasts and titanic watchers.",
        icon = "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
        art = {
            7963783,
            LOAD_SCREEN .. "LoadScreenDungeon",
        },
        texCoord = { 0.02, 0.98, 0.25, 0.81 },
        aliases = { "shapers", "terrace", "ungoro" },
        bosses = {
            { name = "Titanosaur", level = "61", npcID = 253201, displayID = 142989, description = "Apex devilsaur of the outer terrace." },
            { name = "Venomridge", level = "61", npcID = 261813, displayID = 144511, description = "Venomous primal saurian." },
            { name = "Thunderhoof", level = "61", npcID = 261812, displayID = 144514, description = "Charging stegodon alpha." },
            { name = "Direhorn Matriarch", level = "61", npcID = 262127, displayID = 144515, description = "Armored matriarch of the terrace herds." },
            { name = "Cinder", level = "61", icon = "Interface\\Icons\\Spell_Fire_Elemental_Totem", description = "Volcanic elemental manifestation." },
            { name = "Izha'Rel and Tor'Rel", level = "61", npcID = 253218, displayID = 143040, description = "Twin titanic keepers of the terrace." },
            { name = "Bolt", level = "62", npcID = 262081, displayID = 143063, description = "Storm-charged primal guardian." },
            { name = "Snowtalon", level = "62", icon = "Interface\\Icons\\Spell_Frost_ArcticWinds", description = "Frost-touched avian predator." },
            { name = "Vitrix", level = "62", npcID = 272561, displayID = 147098, description = "Crystalline construct of the Shapers." },
            { name = "Nanaya", level = "62", npcID = 261809, displayID = 143832, description = "Final boss of Shaper's Terrace." },
        },
    },
}

local DungeonsData = {
    hasMergedExternal = false,
}

--- Optional runtime enrichment: if `ForeverDungeonJournal` is installed & loaded,
--- merges any additional boss descriptions into our catalog so the user gets
--- complete lore descriptions automatically while staying fully standalone.
function DungeonsData:EnrichFromExternalIfAvailable()
    if self.hasMergedExternal then
        return
    end
    local fdj = _G.ForeverDungeonJournal_NS
    if type(fdj) ~= "table" or type(fdj.DB) ~= "table" then
        return
    end
    self.hasMergedExternal = true

    for _, dungeon in ipairs(DUNGEONS) do
        local extDungeon = fdj.DB[dungeon.name]
        if type(extDungeon) == "table" and type(extDungeon.bosses) == "table" then
            local extBossByName = {}
            for _, eb in ipairs(extDungeon.bosses) do
                if eb and eb.name then
                    extBossByName[eb.name] = eb
                end
            end
            for _, boss in ipairs(dungeon.bosses or {}) do
                local eb = extBossByName[boss.name]
                if eb and eb.description and eb.description ~= "" and (not boss.description or boss.description == "") then
                    boss.description = eb.description
                end
            end
        end
    end
end

--- Comparator that sorts dungeons strictly by the top end of their level range (maxLevel),
--- then minimum level, then name.
local function compareDungeonsByLevel(a, b)
    local maxA = a.maxLevel or 0
    local maxB = b.maxLevel or 0
    if maxA ~= maxB then
        return maxA < maxB
    end
    local minA = a.minLevel or 0
    local minB = b.minLevel or 0
    if minA ~= minB then
        return minA < minB
    end
    return (a.name or "") < (b.name or "")
end

--- Comparator that sorts dungeons alphabetically by name.
local function compareDungeonsByName(a, b)
    return (a.name or "") < (b.name or "")
end

--- Returns the full ordered list of all 35 dungeons sorted by level range.
function DungeonsData:GetAll()
    self:EnrichFromExternalIfAvailable()
    sort(DUNGEONS, compareDungeonsByLevel)
    return DUNGEONS
end

--- Retrieves a single dungeon record by its unique `id` (e.g. "hall_of_thanes").
--- @param id string
--- @return table|nil
function DungeonsData:GetByID(id)
    if not id then
        return nil
    end
    local list = self:GetAll()
    for _, dungeon in ipairs(list) do
        if dungeon.id == id then
            return dungeon
        end
    end
    return nil
end

--- Filters dungeons by optional search query string (matching dungeon name, location, level, aliases, or boss names),
--- sorted by specified sortOrder ("level" [default] or "alphabetical").
--- @param searchQuery string|nil
--- @param sortOrder string|nil
--- @return table[]
function DungeonsData:GetFiltered(searchQuery, sortOrder)
    self:EnrichFromExternalIfAvailable()
    if sortOrder == "alphabetical" or sortOrder == "name" then
        sort(DUNGEONS, compareDungeonsByName)
    else
        sort(DUNGEONS, compareDungeonsByLevel)
    end
    local q = (type(searchQuery) == "string" and strlower(searchQuery:match("^%s*(.-)%s*$") or "")) or ""

    if q == "" then
        return DUNGEONS
    end

    local results = {}
    for _, dungeon in ipairs(DUNGEONS) do
        local matched = false
        if strfind(strlower(dungeon.name or ""), q, 1, true)
            or strfind(strlower(dungeon.location or ""), q, 1, true)
            or strfind(strlower(dungeon.level or ""), q, 1, true)
        then
            matched = true
        end
        if not matched and dungeon.aliases then
            for _, alias in ipairs(dungeon.aliases) do
                if strfind(strlower(alias), q, 1, true) then
                    matched = true
                    break
                end
            end
        end
        if not matched and dungeon.bosses then
            for _, boss in ipairs(dungeon.bosses) do
                if boss.name and strfind(strlower(boss.name), q, 1, true) then
                    matched = true
                    break
                end
                if not matched and ns.ItemsManager and ns.ItemsManager.BossMatchesQuery then
                    local isBossMatch = ns.ItemsManager:BossMatchesQuery(dungeon.id, boss, q)
                    if isBossMatch then
                        matched = true
                        break
                    end
                end
            end
        end
        if not matched and ns.ItemsManager and ns.ItemsManager.GetEncounterDrops then
            local zoneDrops = ns.ItemsManager:GetEncounterDrops(dungeon.id, "Zone Drops")
            if zoneDrops then
                for _, itemID in ipairs(zoneDrops) do
                    local itemName = ns.ItemsManager:GetItemName(itemID)
                    if itemName and strfind(strlower(itemName), q, 1, true) then
                        matched = true
                        break
                    end
                end
            end
        end
        if matched then
            results[#results + 1] = dungeon
        end
    end
    if sortOrder == "alphabetical" or sortOrder == "name" then
        sort(results, compareDungeonsByName)
    else
        sort(results, compareDungeonsByLevel)
    end
    return results
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data.DungeonsData = DungeonsData

