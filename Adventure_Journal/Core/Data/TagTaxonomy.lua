-- ============================================================================
-- Journal_Base - Core/Data/TagTaxonomy.lua
-- Canonical 8-dimension item tag taxonomy, synonym dictionary, DBC instant
-- classifiers, and tooltip stat/effect tag extractors.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local strfind = string.find
local strlower = string.lower
local strmatch = string.match
local gsub = string.gsub

-- ----------------------------------------------------------------------------
-- 2. Canonical 8-Dimension Tag Registry
-- ----------------------------------------------------------------------------
local DIMENSIONS = {
    -- Dimension 1: Item Category & Acquisition Source
    CATEGORY = {
        "loot", "quest", "recipe", "reagent", "consumable", "container",
        "key", "mount", "pet", "miscellaneous",
        "dungeon", "raid", "zone-drop", "quest-reward", "event", "boss-drop",
    },

    -- Dimension 2: Equipment Slot & Handedness
    SLOT = {
        "one-hand", "two-hand", "main-hand", "off-hand", "held-in-off-hand",
        "ranged", "relic", "thrown",
        "head", "neck", "shoulder", "back", "chest", "shirt", "tabard",
        "wrist", "hands", "waist", "legs", "feet", "finger", "trinket",
    },

    -- Dimension 3: Weapon & Armor Subtype
    SUBTYPE = {
        "weapon", "armor",
        "cloth", "leather", "mail", "plate", "shield",
        "libram", "idol", "totem",
        "sword", "axe", "mace", "dagger", "fist-weapon", "polearm", "staff",
        "bow", "gun", "crossbow", "wand", "fishing-pole",
        "bag", "soul-bag", "herb-bag", "enchanting-bag", "quiver", "ammo-pouch",
        "blacksmithing", "leatherworking", "alchemy", "herbalism", "cooking",
        "mining", "tailoring", "engineering", "enchanting", "first-aid", "fishing",
    },

    -- Dimension 4: Primary Attributes
    PRIMARY_STATS = {
        "strength", "agility", "stamina", "intellect", "spirit",
    },

    -- Dimension 5: Physical & Defensive Ratings
    PHYSICAL_DEFENSE = {
        "attack-power", "ranged-attack-power", "feral-attack-power",
        "crit", "hit", "haste", "armor-penetration",
        "defense", "dodge", "parry", "block-value", "block-rating",
        "bonus-armor", "weapon-skill",
    },

    -- Dimension 6: Caster, Spell & Regeneration Stats
    CASTER_STATS = {
        "spell-power", "healing", "spell-crit", "spell-hit",
        "spell-penetration", "mp5", "hp5",
    },

    -- Dimension 7: Elemental Damage & Resistance Schools
    ELEMENTS = {
        "fire-damage", "frost-damage", "nature-damage",
        "shadow-damage", "arcane-damage", "holy-damage",
        "fire-resist", "frost-resist", "nature-resist",
        "shadow-resist", "arcane-resist", "all-resist",
    },

    -- Dimension 8: Mechanics, Procs & Special Context
    MECHANICS = {
        "on-use", "chance-on-hit", "equip-effect", "set-item",
        "starts-quest", "unique", "boe", "bop", "caster", "melee", "tank", "healer",
    },
}

-- Build fast O(1) lookup set of all canonical tags
local CANONICAL_TAGS = {}
local TAG_DIMENSION = {}
for dimName, tagList in pairs(DIMENSIONS) do
    for _, tag in ipairs(tagList) do
        CANONICAL_TAGS[tag] = true
        TAG_DIMENSION[tag] = dimName
    end
end

-- ----------------------------------------------------------------------------
-- 3. Synonym & Natural-Language Alias Dictionary
-- ----------------------------------------------------------------------------
local SYNONYMS = {
    -- Handedness
    ["1h"] = "one-hand",
    ["1-h"] = "one-hand",
    ["1hand"] = "one-hand",
    ["one hand"] = "one-hand",
    ["one handed"] = "one-hand",
    ["one-handed"] = "one-hand",
    ["onehand"] = "one-hand",
    ["onehanded"] = "one-hand",

    ["2h"] = "two-hand",
    ["2-h"] = "two-hand",
    ["2hand"] = "two-hand",
    ["two hand"] = "two-hand",
    ["two handed"] = "two-hand",
    ["two-handed"] = "two-hand",
    ["twohand"] = "two-hand",
    ["twohanded"] = "two-hand",

    ["mh"] = "main-hand",
    ["main hand"] = "main-hand",
    ["mainhand"] = "main-hand",

    ["oh"] = "off-hand",
    ["off hand"] = "off-hand",
    ["offhand"] = "off-hand",
    ["held in off-hand"] = "held-in-off-hand",
    ["held in off hand"] = "held-in-off-hand",
    ["off-hand frill"] = "held-in-off-hand",
    ["tome"] = "held-in-off-hand",
    ["orb"] = "held-in-off-hand",

    -- Slots
    ["helm"] = "head",
    ["helmet"] = "head",
    ["hat"] = "head",
    ["crown"] = "head",
    ["necklace"] = "neck",
    ["amulet"] = "neck",
    ["choker"] = "neck",
    ["pendant"] = "neck",
    ["shoulders"] = "shoulder",
    ["spaulders"] = "shoulder",
    ["pauldrons"] = "shoulder",
    ["mantle"] = "shoulder",
    ["cloak"] = "back",
    ["cape"] = "back",
    ["drape"] = "back",
    ["robe"] = "chest",
    ["tunic"] = "chest",
    ["vest"] = "chest",
    ["breastplate"] = "chest",
    ["bracer"] = "wrist",
    ["bracers"] = "wrist",
    ["wristguards"] = "wrist",
    ["vambraces"] = "wrist",
    ["cuffs"] = "wrist",
    ["gloves"] = "hands",
    ["gauntlets"] = "hands",
    ["handguards"] = "hands",
    ["mitts"] = "hands",
    ["belt"] = "waist",
    ["girdle"] = "waist",
    ["cord"] = "waist",
    ["sash"] = "waist",
    ["waistguard"] = "waist",
    ["pants"] = "legs",
    ["leggings"] = "legs",
    ["legplates"] = "legs",
    ["legguards"] = "legs",
    ["trousers"] = "legs",
    ["kilt"] = "legs",
    ["boots"] = "feet",
    ["shoes"] = "feet",
    ["sabatons"] = "feet",
    ["greaves"] = "feet",
    ["treads"] = "feet",
    ["sandals"] = "feet",
    ["slippers"] = "feet",
    ["ring"] = "finger",
    ["rings"] = "finger",
    ["band"] = "finger",
    ["signet"] = "finger",
    ["seal"] = "finger",
    ["trinkets"] = "trinket",

    -- Weapon & Armor Subtypes
    ["swords"] = "sword",
    ["axes"] = "axe",
    ["maces"] = "mace",
    ["hammer"] = "mace",
    ["daggers"] = "dagger",
    ["fist"] = "fist-weapon",
    ["fist weapon"] = "fist-weapon",
    ["claw"] = "fist-weapon",
    ["knuckle"] = "fist-weapon",
    ["polearms"] = "polearm",
    ["spear"] = "polearm",
    ["halberd"] = "polearm",
    ["staves"] = "staff",
    ["bows"] = "bow",
    ["guns"] = "gun",
    ["rifle"] = "gun",
    ["xbow"] = "crossbow",
    ["crossbows"] = "crossbow",
    ["wands"] = "wand",
    ["shields"] = "shield",
    ["buckler"] = "shield",
    ["fishing pole"] = "fishing-pole",
    ["fishing rod"] = "fishing-pole",
    ["bags"] = "bag",
    ["pouch"] = "bag",
    ["pack"] = "bag",

    -- Primary Stats
    ["str"] = "strength",
    ["agi"] = "agility",
    ["sta"] = "stamina",
    ["stam"] = "stamina",
    ["hp"] = "stamina",
    ["int"] = "intellect",
    ["spi"] = "spirit",

    -- Physical & Defense Stats
    ["ap"] = "attack-power",
    ["attack power"] = "attack-power",
    ["attackpower"] = "attack-power",
    ["rap"] = "ranged-attack-power",
    ["ranged ap"] = "ranged-attack-power",
    ["ranged attack power"] = "ranged-attack-power",
    ["fap"] = "feral-attack-power",
    ["feral ap"] = "feral-attack-power",
    ["feral attack power"] = "feral-attack-power",
    ["critical"] = "crit",
    ["crit strike"] = "crit",
    ["critical strike"] = "crit",
    ["hit rating"] = "hit",
    ["chance to hit"] = "hit",
    ["attack speed"] = "haste",
    ["arp"] = "armor-penetration",
    ["armor pen"] = "armor-penetration",
    ["armor penetration"] = "armor-penetration",
    ["def"] = "defense",
    ["block"] = "block-rating",
    ["block value"] = "block-value",
    ["shield block"] = "block-value",
    ["weapon skill"] = "weapon-skill",

    -- Caster & Spell Stats
    ["sp"] = "spell-power",
    ["spd"] = "spell-power",
    ["spell power"] = "spell-power",
    ["spellpower"] = "spell-power",
    ["spell damage"] = "spell-power",
    ["spelldamage"] = "spell-power",
    ["damage and healing"] = "spell-power",
    ["heal"] = "healing",
    ["heals"] = "healing",
    ["healing power"] = "healing",
    ["+healing"] = "healing",
    ["spell crit"] = "spell-crit",
    ["spell critical"] = "spell-crit",
    ["spell hit"] = "spell-hit",
    ["spell pen"] = "spell-penetration",
    ["spell penetration"] = "spell-penetration",
    ["mana regen"] = "mp5",
    ["mana per 5"] = "mp5",
    ["health regen"] = "hp5",
    ["health per 5"] = "hp5",

    -- Elemental Damage & Resistances
    ["fire"] = "fire-damage",
    ["fire dmg"] = "fire-damage",
    ["fire damage"] = "fire-damage",
    ["fire spell"] = "fire-damage",
    ["frost"] = "frost-damage",
    ["frost dmg"] = "frost-damage",
    ["frost damage"] = "frost-damage",
    ["frost spell"] = "frost-damage",
    ["nature"] = "nature-damage",
    ["nature dmg"] = "nature-damage",
    ["nature damage"] = "nature-damage",
    ["shadow"] = "shadow-damage",
    ["shadow dmg"] = "shadow-damage",
    ["shadow damage"] = "shadow-damage",
    ["arcane"] = "arcane-damage",
    ["arcane dmg"] = "arcane-damage",
    ["arcane damage"] = "arcane-damage",
    ["holy"] = "holy-damage",
    ["holy dmg"] = "holy-damage",
    ["holy damage"] = "holy-damage",

    ["fr"] = "fire-resist",
    ["fire res"] = "fire-resist",
    ["fire resist"] = "fire-resist",
    ["fire resistance"] = "fire-resist",
    ["frr"] = "frost-resist",
    ["frost res"] = "frost-resist",
    ["frost resist"] = "frost-resist",
    ["frost resistance"] = "frost-resist",
    ["nr"] = "nature-resist",
    ["nature res"] = "nature-resist",
    ["nature resist"] = "nature-resist",
    ["nature resistance"] = "nature-resist",
    ["sr"] = "shadow-resist",
    ["shadow res"] = "shadow-resist",
    ["shadow resist"] = "shadow-resist",
    ["shadow resistance"] = "shadow-resist",
    ["ar"] = "arcane-resist",
    ["arcane res"] = "arcane-resist",
    ["arcane resist"] = "arcane-resist",
    ["arcane resistance"] = "arcane-resist",
    ["all res"] = "all-resist",
    ["all resist"] = "all-resist",
    ["all resistances"] = "all-resist",
    ["resist"] = "all-resist",
    ["resistance"] = "all-resist",

    -- Sources & Categories
    ["dungeons"] = "dungeon",
    ["5-man"] = "dungeon",
    ["5man"] = "dungeon",
    ["instance"] = "dungeon",
    ["raids"] = "raid",
    ["zone drop"] = "zone-drop",
    ["zone drops"] = "zone-drop",
    ["trash"] = "zone-drop",
    ["trash drop"] = "zone-drop",
    ["world drop"] = "zone-drop",
    ["quest item"] = "quest",
    ["quest reward"] = "quest-reward",
    ["holiday"] = "event",
    ["seasonal"] = "event",
    ["boss"] = "boss-drop",
    ["recipes"] = "recipe",
    ["pattern"] = "recipe",
    ["plans"] = "recipe",
    ["schematic"] = "recipe",
    ["formula"] = "recipe",
    ["manual"] = "recipe",
    ["keys"] = "key",
    ["mounts"] = "mount",
    ["pets"] = "pet",
    ["companion"] = "pet",

    -- Mechanics
    ["proc"] = "chance-on-hit",
    ["chance on hit"] = "chance-on-hit",
    ["use"] = "on-use",
    ["on use"] = "on-use",
    ["active"] = "on-use",
    ["set"] = "set-item",
    ["tier"] = "set-item",
    ["bind on equip"] = "boe",
    ["bind on pickup"] = "bop",
}

-- ----------------------------------------------------------------------------
-- 4. Blizzard DBC Instant Classification Maps
-- ----------------------------------------------------------------------------

-- Maps `itemEquipLoc` token from `C_Item.GetItemInfoInstant` to `{ slotLabel, tags = {...} }`
local EQUIP_LOC_MAP = {
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
    INVTYPE_WEAPON         = { label = "One-Hand",         tags = { "one-hand", "weapon" } },
    INVTYPE_SHIELD         = { label = "Off Hand",         tags = { "off-hand", "shield", "armor" } },
    INVTYPE_2HWEAPON       = { label = "Two-Hand",         tags = { "two-hand", "weapon" } },
    INVTYPE_WEAPONMAINHAND = { label = "Main Hand",        tags = { "main-hand", "one-hand", "weapon" } },
    INVTYPE_WEAPONOFFHAND  = { label = "Off Hand",         tags = { "off-hand", "one-hand", "weapon" } },
    INVTYPE_HOLDABLE       = { label = "Held In Off-hand", tags = { "held-in-off-hand", "off-hand" } },
    INVTYPE_RANGED         = { label = "Ranged",           tags = { "ranged", "weapon" } },
    INVTYPE_THROWN         = { label = "Thrown",           tags = { "thrown", "ranged", "weapon" } },
    INVTYPE_RANGEDRIGHT    = { label = "Ranged",           tags = { "ranged", "weapon" } },
    INVTYPE_RELIC          = { label = "Relic",            tags = { "relic" } },
    INVTYPE_TABARD         = { label = "Tabard",           tags = { "tabard" } },
    INVTYPE_BAG            = { label = "Bag",              tags = { "bag", "container" } },
    INVTYPE_QUIVER         = { label = "Quiver",           tags = { "quiver", "container" } },
}

-- Maps Blizzard `(classID, subclassID)` to `{ subTypeLabel, tags = {...} }`
local WEAPON_SUBCLASS_MAP = {
    [0]  = { label = "Axe",          tags = { "axe", "one-hand", "weapon" } },
    [1]  = { label = "Axe",          tags = { "axe", "two-hand", "weapon" } },
    [2]  = { label = "Bow",          tags = { "bow", "ranged", "weapon" } },
    [3]  = { label = "Gun",          tags = { "gun", "ranged", "weapon" } },
    [4]  = { label = "Mace",         tags = { "mace", "one-hand", "weapon" } },
    [5]  = { label = "Mace",         tags = { "mace", "two-hand", "weapon" } },
    [6]  = { label = "Polearm",      tags = { "polearm", "two-hand", "weapon" } },
    [7]  = { label = "Sword",        tags = { "sword", "one-hand", "weapon" } },
    [8]  = { label = "Sword",        tags = { "sword", "two-hand", "weapon" } },
    [10] = { label = "Staff",        tags = { "staff", "two-hand", "weapon" } },
    [13] = { label = "Fist Weapon",  tags = { "fist-weapon", "one-hand", "weapon" } },
    [14] = { label = "Miscellaneous", tags = { "weapon" } },
    [15] = { label = "Dagger",       tags = { "dagger", "one-hand", "weapon" } },
    [16] = { label = "Thrown",       tags = { "thrown", "ranged", "weapon" } },
    [17] = { label = "Spear",        tags = { "polearm", "two-hand", "weapon" } },
    [18] = { label = "Crossbow",     tags = { "crossbow", "ranged", "weapon" } },
    [19] = { label = "Wand",         tags = { "wand", "ranged", "weapon" } },
    [20] = { label = "Fishing Pole", tags = { "fishing-pole", "two-hand", "weapon" } },
}

local ARMOR_SUBCLASS_MAP = {
    [0] = { label = "Miscellaneous", tags = {} },
    [1] = { label = "Cloth",         tags = { "cloth", "armor" } },
    [2] = { label = "Leather",       tags = { "leather", "armor" } },
    [3] = { label = "Mail",          tags = { "mail", "armor" } },
    [4] = { label = "Plate",         tags = { "plate", "armor" } },
    [5] = { label = "Buckler",       tags = { "shield", "off-hand", "armor" } },
    [6] = { label = "Shield",        tags = { "shield", "off-hand", "armor" } },
    [7] = { label = "Libram",        tags = { "libram", "relic" } },
    [8] = { label = "Idol",          tags = { "idol", "relic" } },
    [9] = { label = "Totem",         tags = { "totem", "relic" } },
}

local RECIPE_SUBCLASS_MAP = {
    [0]  = { label = "Book",           tags = { "recipe" } },
    [1]  = { label = "Leatherworking", tags = { "recipe", "leatherworking" } },
    [2]  = { label = "Tailoring",      tags = { "recipe", "tailoring" } },
    [3]  = { label = "Engineering",    tags = { "recipe", "engineering" } },
    [4]  = { label = "Blacksmithing",  tags = { "recipe", "blacksmithing" } },
    [5]  = { label = "Cooking",        tags = { "recipe", "cooking" } },
    [6]  = { label = "Alchemy",        tags = { "recipe", "alchemy" } },
    [7]  = { label = "First Aid",      tags = { "recipe", "first-aid" } },
    [8]  = { label = "Enchanting",     tags = { "recipe", "enchanting" } },
    [9]  = { label = "Fishing",        tags = { "recipe", "fishing" } },
}

-- ----------------------------------------------------------------------------
-- 5. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local TagTaxonomy = {
    DIMENSIONS = DIMENSIONS,
    CANONICAL_TAGS = CANONICAL_TAGS,
    TAG_DIMENSION = TAG_DIMENSION,
    SYNONYMS = SYNONYMS,
    EQUIP_LOC_MAP = EQUIP_LOC_MAP,
}

--- Normalizes an input token (from user search or raw metadata) into a canonical tag if known.
--- @param rawToken string|nil
--- @return string|nil canonicalTag
function TagTaxonomy:NormalizeToken(rawToken)
    if not rawToken or rawToken == "" then
        return nil
    end
    local cleaned = strlower(rawToken):match("^%s*(.-)%s*$")
    if cleaned == "" then
        return nil
    end
    if CANONICAL_TAGS[cleaned] then
        return cleaned
    end
    if SYNONYMS[cleaned] then
        return SYNONYMS[cleaned]
    end
    -- Try hyphenating spaces
    local hyphenated = gsub(cleaned, "%s+", "-")
    if CANONICAL_TAGS[hyphenated] then
        return hyphenated
    end
    if SYNONYMS[hyphenated] then
        return SYNONYMS[hyphenated]
    end
    return nil
end

--- Checks whether a string is a registered canonical tag.
--- @param tag string
--- @return boolean
function TagTaxonomy:IsKnownTag(tag)
    return tag ~= nil and CANONICAL_TAGS[tag] == true
end

--- Derives instant classification tags and human-readable slot/subtype labels from DBC fields.
--- @param classID number|nil
--- @param subclassID number|nil
--- @param itemEquipLoc string|nil
--- @param categoryOverride string|nil
--- @return table tags, string|nil slotLabel, string|nil subTypeLabel, string resolvedCategory
function TagTaxonomy:ClassifyInstant(classID, subclassID, itemEquipLoc, categoryOverride)
    local tagSet = {}
    local tagList = {}
    local function addTag(t)
        if t and not tagSet[t] then
            tagSet[t] = true
            tagList[#tagList + 1] = t
        end
    end

    local slotLabel = nil
    local subTypeLabel = nil
    local resolvedCategory = categoryOverride or "LOOT"

    if itemEquipLoc and itemEquipLoc ~= "" and EQUIP_LOC_MAP[itemEquipLoc] then
        local eqInfo = EQUIP_LOC_MAP[itemEquipLoc]
        slotLabel = eqInfo.label
        for _, t in ipairs(eqInfo.tags) do
            addTag(t)
        end
    end

    if classID == 2 then -- Weapon
        local sub = WEAPON_SUBCLASS_MAP[subclassID]
        if sub then
            subTypeLabel = sub.label
            for _, t in ipairs(sub.tags) do
                addTag(t)
            end
        else
            addTag("weapon")
        end
    elseif classID == 4 then -- Armor
        local sub = ARMOR_SUBCLASS_MAP[subclassID]
        if sub then
            -- Avoid labeling Neck/Finger/Trinket/Cloak as "Miscellaneous"
            if subclassID ~= 0 then
                subTypeLabel = sub.label
            elseif itemEquipLoc == "INVTYPE_CLOAK" then
                subTypeLabel = "Cloth"
            end
            for _, t in ipairs(sub.tags) do
                addTag(t)
            end
        end
    elseif classID == 1 then -- Container / Bag
        subTypeLabel = "Bag"
        addTag("bag")
        addTag("container")
    elseif classID == 9 then -- Recipe
        resolvedCategory = categoryOverride or "RECIPE"
        local sub = RECIPE_SUBCLASS_MAP[subclassID]
        if sub then
            subTypeLabel = sub.label
            for _, t in ipairs(sub.tags) do
                addTag(t)
            end
        else
            addTag("recipe")
        end
    elseif classID == 11 then -- Quiver / Ammo Pouch
        subTypeLabel = (subclassID == 3) and "Ammo Pouch" or "Quiver"
        addTag("container")
        addTag((subclassID == 3) and "ammo-pouch" or "quiver")
    elseif classID == 12 then -- Quest
        resolvedCategory = categoryOverride or "QUEST"
        subTypeLabel = "Quest"
        addTag("quest")
    elseif classID == 13 then -- Key
        subTypeLabel = "Key"
        addTag("key")
    elseif classID == 0 then -- Consumable
        addTag("consumable")
    elseif classID == 5 or classID == 7 then -- Reagent / Tradeskill
        addTag("reagent")
    elseif classID == 15 then -- Miscellaneous
        if subclassID == 2 then
            subTypeLabel = "Companion Pet"
            addTag("pet")
        elseif subclassID == 5 then
            subTypeLabel = "Mount"
            addTag("mount")
        else
            addTag("miscellaneous")
        end
    end

    if resolvedCategory == "QUEST" then
        addTag("quest")
    elseif resolvedCategory == "RECIPE" then
        addTag("recipe")
    else
        addTag("loot")
    end

    return tagList, slotLabel, subTypeLabel, resolvedCategory
end

--- Inspects a single tooltip line and appends any discovered stat/effect tags or level metadata.
--- Used by `ItemDatabase` during live tooltip hydration and static catalog indexing.
--- @param lineText string
--- @param outTags table Set table (`outTags[tag] = true`)
--- @param outMeta table|nil Optional metadata table to populate (`reqLevel`, `iLevel`, `slot`, `subType`)
function TagTaxonomy:ParseTooltipLine(lineText, outTags, outMeta)
    if not lineText or lineText == "" then
        return
    end
    local lower = strlower(lineText)

    -- 1. Required Level & Item Level
    if outMeta then
        local reqLvl = strmatch(lower, "requires level (%d+)")
        if reqLvl then
            outMeta.reqLevel = tonumber(reqLvl)
        end
        local iLvl = strmatch(lower, "item level (%d+)")
        if iLvl then
            outMeta.iLevel = tonumber(iLvl)
        end
    end

    -- 2. Bindings & Quest Starter
    if strfind(lower, "binds when picked up", 1, true) then
        outTags["bop"] = true
    elseif strfind(lower, "binds when equipped", 1, true) then
        outTags["boe"] = true
    end
    if strfind(lower, "this item begins a quest", 1, true) then
        outTags["starts-quest"] = true
        outTags["quest"] = true
    end
    if strfind(lower, "unique", 1, true) then
        outTags["unique"] = true
    end

    -- 3. Primary Attributes (e.g. "+12 Strength", "+8 Stamina")
    if strmatch(lower, "[%+%-]%d+%s+strength") then outTags["strength"] = true end
    if strmatch(lower, "[%+%-]%d+%s+agility") then outTags["agility"] = true end
    if strmatch(lower, "[%+%-]%d+%s+stamina") then outTags["stamina"] = true end
    if strmatch(lower, "[%+%-]%d+%s+intellect") then outTags["intellect"] = true end
    if strmatch(lower, "[%+%-]%d+%s+spirit") then outTags["spirit"] = true end

    -- 4. Resistances (e.g. "+10 Fire Resistance", "+5 All Resistances")
    if strmatch(lower, "[%+%-]%d+%s+fire resistance") or strfind(lower, "fire resistance by", 1, true) then
        outTags["fire-resist"] = true
    end
    if strmatch(lower, "[%+%-]%d+%s+frost resistance") or strfind(lower, "frost resistance by", 1, true) then
        outTags["frost-resist"] = true
    end
    if strmatch(lower, "[%+%-]%d+%s+nature resistance") or strfind(lower, "nature resistance by", 1, true) then
        outTags["nature-resist"] = true
    end
    if strmatch(lower, "[%+%-]%d+%s+shadow resistance") or strfind(lower, "shadow resistance by", 1, true) then
        outTags["shadow-resist"] = true
    end
    if strmatch(lower, "[%+%-]%d+%s+arcane resistance") or strfind(lower, "arcane resistance by", 1, true) then
        outTags["arcane-resist"] = true
    end
    if strfind(lower, "all resistances", 1, true) then
        outTags["all-resist"] = true
    end

    -- 5. Trigger Prefixes ("Equip:", "Use:", "Chance on hit:")
    if strfind(lower, "^equip:") then
        outTags["equip-effect"] = true
    elseif strfind(lower, "^use:") then
        outTags["on-use"] = true
    elseif strfind(lower, "^chance on hit:") then
        outTags["chance-on-hit"] = true
    end

    -- 6. Physical & Defensive Stats
    if strfind(lower, "ranged attack power", 1, true) then
        outTags["ranged-attack-power"] = true
        outTags["attack-power"] = true
    elseif strfind(lower, "attack power in cat", 1, true) or strfind(lower, "feral attack power", 1, true) then
        outTags["feral-attack-power"] = true
        outTags["attack-power"] = true
    elseif strfind(lower, "attack power", 1, true) then
        outTags["attack-power"] = true
    end

    if strfind(lower, "critical strike with spells", 1, true) or strfind(lower, "spell critical", 1, true) then
        outTags["spell-crit"] = true
    elseif strfind(lower, "critical strike", 1, true) then
        outTags["crit"] = true
    end

    if strfind(lower, "chance to hit with spells", 1, true) or strfind(lower, "spell hit", 1, true) then
        outTags["spell-hit"] = true
    elseif strfind(lower, "chance to hit", 1, true) or strfind(lower, "hit rating", 1, true) then
        outTags["hit"] = true
    end

    if strfind(lower, "defense", 1, true) and (strfind(lower, "increased defense", 1, true) or strfind(lower, "defense rating", 1, true)) then
        outTags["defense"] = true
        outTags["tank"] = true
    end
    if strfind(lower, "chance to dodge", 1, true) or strfind(lower, "dodge rating", 1, true) then
        outTags["dodge"] = true
        outTags["tank"] = true
    end
    if strfind(lower, "chance to parry", 1, true) or strfind(lower, "parry rating", 1, true) then
        outTags["parry"] = true
        outTags["tank"] = true
    end
    if strfind(lower, "block value of your shield", 1, true) then
        outTags["block-value"] = true
        outTags["tank"] = true
    end
    if strfind(lower, "chance to block", 1, true) or strfind(lower, "block rating", 1, true) then
        outTags["block-rating"] = true
        outTags["tank"] = true
    end

    -- 7. Spell Power, Healing & Regeneration
    if strfind(lower, "damage and healing done by magical spells", 1, true)
        or strfind(lower, "spell power", 1, true)
        or strfind(lower, "spell damage", 1, true) then
        outTags["spell-power"] = true
        outTags["caster"] = true
    end
    if strfind(lower, "healing done by spells", 1, true)
        or strfind(lower, "healing done by up to", 1, true)
        or strfind(lower, "increases healing", 1, true) then
        outTags["healing"] = true
        outTags["healer"] = true
    end
    if strfind(lower, "mana per 5 sec", 1, true) or strmatch(lower, "restores %d+ mana per 5") then
        outTags["mp5"] = true
    end
    if strfind(lower, "health per 5 sec", 1, true) or strmatch(lower, "restores %d+ health per 5") then
        outTags["hp5"] = true
    end
    if strfind(lower, "magical resistances of your spell targets", 1, true) or strfind(lower, "spell penetration", 1, true) then
        outTags["spell-penetration"] = true
    end

    -- 8. Elemental School Spell Damage & Weapon Elemental Damage
    if strfind(lower, "fire spells and effects", 1, true) or strmatch(lower, "%+%d+.-fire damage") then
        outTags["fire-damage"] = true
        outTags["spell-power"] = true
    end
    if strfind(lower, "frost spells and effects", 1, true) or strmatch(lower, "%+%d+.-frost damage") then
        outTags["frost-damage"] = true
        outTags["spell-power"] = true
    end
    if strfind(lower, "nature spells and effects", 1, true) or strmatch(lower, "%+%d+.-nature damage") then
        outTags["nature-damage"] = true
        outTags["spell-power"] = true
    end
    if strfind(lower, "shadow spells and effects", 1, true) or strmatch(lower, "%+%d+.-shadow damage") then
        outTags["shadow-damage"] = true
        outTags["spell-power"] = true
    end
    if strfind(lower, "arcane spells and effects", 1, true) or strmatch(lower, "%+%d+.-arcane damage") then
        outTags["arcane-damage"] = true
        outTags["spell-power"] = true
    end
    if strfind(lower, "holy spells and effects", 1, true) or strmatch(lower, "%+%d+.-holy damage") then
        outTags["holy-damage"] = true
        outTags["spell-power"] = true
    end

    -- 9. Set Bonus indicator (e.g. "(2) Set:" or "Set:")
    if strmatch(lower, "%(%d+/%d+%)$") or strfind(lower, "^%(%d+%) set:") then
        outTags["set-item"] = true
    end
end

-- ----------------------------------------------------------------------------
-- 6. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.TagTaxonomy = TagTaxonomy
