-- ============================================================================
-- Utility_DataStore - Stores/ItemStore/Rules.lua
-- How the client's instant item data (equip slot, class and subclass IDs) turns
-- into display names and search tags. Hand-kept: edit freely.
--   label: the client's name for the slot or type; short: for tight spaces
--   tags:  computed tags the item gets (keys from Tags/TagDefinitions.lua)
-- ============================================================================
local addonName, ns = ...

ns.DataStore.ItemStore.Rules = {
    -- Equip slot token from C_Item.GetItemInfoInstant
    equipLocs = {
        INVTYPE_HEAD           = { label = "Head",             tags = { "head", "armor" } },
        INVTYPE_NECK           = { label = "Neck",             tags = { "neck" } },
        INVTYPE_SHOULDER       = { label = "Shoulder",         tags = { "shoulder", "armor" } },
        INVTYPE_BODY           = { label = "Shirt",            tags = { "shirt" } },
        INVTYPE_CHEST          = { label = "Chest",            tags = { "chest", "armor" } },
        INVTYPE_ROBE           = { label = "Chest",            tags = { "chest", "armor" } },
        INVTYPE_WAIST          = { label = "Waist",            tags = { "waist", "armor" } },
        INVTYPE_LEGS           = { label = "Legs",             tags = { "legs", "armor" } },
        INVTYPE_FEET           = { label = "Feet",             tags = { "feet", "armor" } },
        INVTYPE_WRIST          = { label = "Wrist",            tags = { "wrist", "armor" } },
        INVTYPE_HAND           = { label = "Hands",            tags = { "hands", "armor" } },
        INVTYPE_FINGER         = { label = "Finger",           tags = { "finger" } },
        INVTYPE_TRINKET        = { label = "Trinket",          tags = { "trinket" } },
        INVTYPE_CLOAK          = { label = "Back",             tags = { "back", "armor" } },
        INVTYPE_WEAPON         = { label = "One-Hand",         short = "1H",      tags = { "one-hand", "weapon" } },
        INVTYPE_SHIELD         = { label = "Off Hand",         short = "OH",      tags = { "off-hand", "shield", "armor" } },
        INVTYPE_2HWEAPON       = { label = "Two-Hand",         short = "2H",      tags = { "two-hand", "weapon" } },
        INVTYPE_WEAPONMAINHAND = { label = "Main Hand",        short = "MH",      tags = { "main-hand", "one-hand", "weapon" } },
        INVTYPE_WEAPONOFFHAND  = { label = "Off Hand",         short = "OH",      tags = { "off-hand", "one-hand", "weapon" } },
        INVTYPE_HOLDABLE       = { label = "Held In Off-hand", short = "Held OH", tags = { "held-in-off-hand", "off-hand" } },
        INVTYPE_RANGED         = { label = "Ranged",           tags = { "ranged", "weapon" } },
        INVTYPE_THROWN         = { label = "Thrown",           tags = { "thrown", "ranged", "weapon" } },
        INVTYPE_RANGEDRIGHT    = { label = "Ranged",           tags = { "ranged", "weapon" } },
        INVTYPE_RELIC          = { label = "Relic",            tags = { "relic" } },
        INVTYPE_TABARD         = { label = "Tabard",           tags = { "tabard" } },
        INVTYPE_BAG            = { label = "Bag",              tags = { "bag", "container" } },
        INVTYPE_QUIVER         = { label = "Quiver",           tags = { "quiver", "container" } },
    },

    -- Subclass ID within item class 2 (weapons)
    weaponTypes = {
        [0]  = { label = "One-Handed Axe",   short = "1H Axe",   tags = { "axe", "one-hand", "weapon" } },
        [1]  = { label = "Two-Handed Axe",   short = "2H Axe",   tags = { "axe", "two-hand", "weapon" } },
        [2]  = { label = "Bow",              tags = { "bow", "ranged", "weapon" } },
        [3]  = { label = "Gun",              tags = { "gun", "ranged", "weapon" } },
        [4]  = { label = "One-Handed Mace",  short = "1H Mace",  tags = { "mace", "one-hand", "weapon" } },
        [5]  = { label = "Two-Handed Mace",  short = "2H Mace",  tags = { "mace", "two-hand", "weapon" } },
        [6]  = { label = "Polearm",          tags = { "polearm", "two-hand", "weapon" } },
        [7]  = { label = "One-Handed Sword", short = "1H Sword", tags = { "sword", "one-hand", "weapon" } },
        [8]  = { label = "Two-Handed Sword", short = "2H Sword", tags = { "sword", "two-hand", "weapon" } },
        [10] = { label = "Staff",            tags = { "staff", "two-hand", "weapon" } },
        [13] = { label = "Fist Weapon",      short = "Fist",     tags = { "fist-weapon", "one-hand", "weapon" } },
        [14] = { label = "Miscellaneous",    short = "Misc",     tags = { "weapon" } },
        [15] = { label = "Dagger",           tags = { "dagger", "one-hand", "weapon" } },
        [16] = { label = "Thrown",           tags = { "thrown", "ranged", "weapon" } },
        [17] = { label = "Spear",            tags = { "polearm", "two-hand", "weapon" } },
        [18] = { label = "Crossbow",         tags = { "crossbow", "ranged", "weapon" } },
        [19] = { label = "Wand",             tags = { "wand", "ranged", "weapon" } },
        [20] = { label = "Fishing Pole",     short = "Pole",     tags = { "fishing-pole", "two-hand", "weapon" } },
    },

    -- Subclass ID within item class 4 (armor)
    armorTypes = {
        [0] = { label = "Miscellaneous", short = "Misc", tags = {} },
        [1] = { label = "Cloth",         tags = { "cloth", "armor" } },
        [2] = { label = "Leather",       tags = { "leather", "armor" } },
        [3] = { label = "Mail",          tags = { "mail", "armor" } },
        [4] = { label = "Plate",         tags = { "plate", "armor" } },
        [5] = { label = "Buckler",       tags = { "shield", "off-hand", "armor" } },
        [6] = { label = "Shield",        tags = { "shield", "off-hand", "armor" } },
        [7] = { label = "Libram",        tags = { "libram", "relic" } },
        [8] = { label = "Idol",          tags = { "idol", "relic" } },
        [9] = { label = "Totem",         tags = { "totem", "relic" } },
    },

    -- Which armor (class 4) and weapon (class 2) subclasses each class can use, by class file name.
    -- Armor slots every class can wear (neck, finger, trinket, back, shirt, tabard) aren't listed here.
    classArmor = {
        WARRIOR = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true },
        PALADIN = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true },
        HUNTER  = { [1] = true, [2] = true, [3] = true },
        SHAMAN  = { [1] = true, [2] = true, [3] = true, [5] = true, [6] = true },
        ROGUE   = { [1] = true, [2] = true },
        DRUID   = { [1] = true, [2] = true },
        MAGE    = { [1] = true },
        PRIEST  = { [1] = true },
        WARLOCK = { [1] = true },
    },
    -- Weapon subclasses: 0/1 axe, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff, 13 fist, 15 dagger,
    -- 16 thrown, 18 crossbow, 19 wand
    classWeapons = {
        WARRIOR = { [15] = true, [0] = true, [1] = true, [7] = true, [8] = true, [4] = true, [5] = true, [6] = true,
                    [10] = true, [13] = true, [2] = true, [18] = true, [3] = true, [16] = true },
        PALADIN = { [4] = true, [5] = true, [7] = true, [8] = true, [0] = true, [1] = true, [6] = true },
        HUNTER  = { [2] = true, [18] = true, [3] = true, [15] = true, [7] = true, [8] = true, [0] = true, [1] = true,
                    [6] = true, [10] = true, [13] = true, [16] = true },
        ROGUE   = { [15] = true, [7] = true, [4] = true, [13] = true, [2] = true, [18] = true, [3] = true, [16] = true },
        PRIEST  = { [15] = true, [4] = true, [10] = true, [19] = true },
        SHAMAN  = { [4] = true, [5] = true, [0] = true, [1] = true, [15] = true, [10] = true, [13] = true },
        MAGE    = { [15] = true, [7] = true, [10] = true, [19] = true },
        WARLOCK = { [15] = true, [7] = true, [10] = true, [19] = true },
        DRUID   = { [4] = true, [5] = true, [10] = true, [15] = true, [6] = true, [13] = true },
    },

    -- Subclass ID within item class 9 (recipes)
    recipeTypes = {
        [0] = { label = "Book",           tags = { "recipe" } },
        [1] = { label = "Leatherworking", short = "LW",     tags = { "recipe", "leatherworking" } },
        [2] = { label = "Tailoring",      short = "Tailor", tags = { "recipe", "tailoring" } },
        [3] = { label = "Engineering",    short = "Eng",    tags = { "recipe", "engineering" } },
        [4] = { label = "Blacksmithing",  short = "BS",     tags = { "recipe", "blacksmithing" } },
        [5] = { label = "Cooking",        tags = { "recipe", "cooking" } },
        [6] = { label = "Alchemy",        short = "Alch",   tags = { "recipe", "alchemy" } },
        [7] = { label = "First Aid",      tags = { "recipe", "first-aid" } },
        [8] = { label = "Enchanting",     short = "Ench",   tags = { "recipe", "enchanting" } },
        [9] = { label = "Fishing",        tags = { "recipe", "fishing" } },
    },
}
