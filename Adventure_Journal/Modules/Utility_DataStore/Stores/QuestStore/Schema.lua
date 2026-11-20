-- ============================================================================
-- Utility_DataStore - Stores/QuestStore/Schema.lua
--
-- A quest is a task from the quest log, picked up from an NPC, an item or a
-- fixture and turned in for rewards. Keyed by the game's quest ID. Holds
-- levels, who starts and ends it, what unlocks it, and its rewards; the title
-- comes from the client.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Store Definition
-- ----------------------------------------------------------------------------
DataStore.StoreBase:New({
    name = "QuestStore",
    kind = "Quest",
    liveName = "quest",
    fields = {
        questLevel      = { type = "number",  comment = "Quest level." },
        requiredLevel   = { type = "number",  comment = "Minimum player level." },
        xp              = { type = "number",  comment = "Base experience." },
        classes         = { type = "table",   list = true, comment = "Class restriction, for class quests." },
        startedBy       = { type = "table",   list = true, comment = "{ { npcID } }, { { itemID } } or { { fixtureID } }." },
        endedBy         = { type = "table",   list = true, comment = "Same shape as startedBy." },
        instanceIDs     = { type = "table",   list = true, links = "InstanceStore", comment = "Instances the quest belongs to." },
        wingKeys        = { type = "table",   list = true, links = "InstanceStore", comment = "Wings the quest belongs to." },
        startsInDungeon = { type = "boolean", comment = "Picked up inside the instance." },
        shareable       = { type = "boolean", comment = "Our audited answer: can it be shared with the group?" },
        requires        = { type = "table",   list = true, comment = "Direct requirements: { questID, state }, { itemID }, { locationKey }." },
        requiredItemIDs = { type = "table",   list = true, links = "ItemStore", comment = "Items needed that aren't objectives." },
        rewardItemIDs   = { type = "table",   list = true, links = "ItemStore", comment = "Reward items." },
        rewardChoice    = { type = "boolean", comment = "True when you pick one reward." },
        questLine       = { type = "string",  comment = "Name of the chain this quest completes (on the goal quest)." },
    },
})
