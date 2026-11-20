-- ============================================================================
-- Utility_DataStore - Stores/AbilityStore/Schema.lua
--
-- An ability is anything a creature or player can cast or use: a boss's
-- Trample or Shell Shocker, a monster's poison, and later the spells players
-- learn from trainers, class quests and skill books. In the game's data every
-- ability is a spell with a spell ID; keyed by that ID. Name, icon and
-- description come from the client. Built empty in this branch; filled later.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local C_Spell = C_Spell
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Store Definition
-- ----------------------------------------------------------------------------
DataStore.StoreBase:New({
    name = "AbilityStore",
    kind = "Ability",
    liveName = "spell",
    fields = {
        npcIDs       = { type = "table",  list = true, links = "NpcStore", comment = "NPCs that use it, when not tied to one encounter." },
        icon         = { type = "number", live = true, comment = "Icon file ID." },
        description  = { type = "string", live = true, comment = "The spell's tooltip text." },
        -- Reserved for player abilities
        classes      = { type = "table",  list = true, comment = "Reserved: classes that learn it." },
        trainerLevel = { type = "number", comment = "Reserved: level it's learned at." },
    },
    live = {
        icon = function(spellID)
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.iconID
        end,
        description = function(spellID)
            return C_Spell.GetSpellDescription(spellID)
        end,
    },
})
