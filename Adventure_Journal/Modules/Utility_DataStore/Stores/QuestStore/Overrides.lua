-- ============================================================================
-- Utility_DataStore - Stores/QuestStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.QuestStore:SetOverrides({
    { key = 545, field = "requires", value = { { questID = 544 } }, type = "correction",
      note = "Dalaran Patrols completes without Now We're Cooking (92433), a side quest from the same giver. Prison Break In as its prerequisite is unconfirmed." },

    -- The Aeonas the Vindicated questline (19 Paladin quests, Scarlet Monastery then Maraudon): kept off the
    -- dungeon pages until its objectives and quest sources are known. Remove these four to show it again.
    { key = 79946, field = "instanceIDs", value = nil, type = "correction",
      note = "Aeonas questline: unlinked from Scarlet Monastery until its objectives and sources are known." },
    { key = 79963, field = "instanceIDs", value = nil, type = "correction",
      note = "Aeonas questline: unlinked from Scarlet Monastery until its objectives and sources are known." },
    { key = 79970, field = "instanceIDs", value = nil, type = "correction",
      note = "Aeonas questline: unlinked from Scarlet Monastery until its objectives and sources are known." },
    { key = 81790, field = "instanceIDs", value = nil, type = "correction",
      note = "Aeonas questline: unlinked from Maraudon until its objectives and sources are known." },

    -- A quest shows on a dungeon page only when every quest in its chain has a known start and turn-in.
    -- These questlines have a step with neither known (or only a clickable object we can't link yet), so they're
    -- kept off their pages. Remove an entry once the missing start or turn-in is in the data.
    { key = 80411, field = "instanceIDs", value = nil, type = "correction",
      note = "The Talisman of Kazdor: two earlier steps (78261, 78676) start and end at objects not in our data." },
    { key = 82062, field = "instanceIDs", value = nil, type = "correction",
      note = "Ever After: no known start." },
    { key = 92067, field = "instanceIDs", value = nil, type = "correction",
      note = "Feeding Time!: no known start or turn-in." },
    { key = 95263, field = "instanceIDs", value = nil, type = "correction",
      note = "Somber News: no known start; The Secret Prison (95262) has no known turn-in." },
    { key = 95483, field = "instanceIDs", value = nil, type = "correction",
      note = "Thrall Needs to Know: it and three earlier steps (95309, 95454, 96369) miss a start or turn-in." },
    { key = 95790, field = "instanceIDs", value = nil, type = "correction",
      note = "Digestible Research: no known start." },
    { key = 96337, field = "instanceIDs", value = nil, type = "correction",
      note = "More Valuable Than Gold: it and The Man in the Iron Chains (96335) miss a start and turn-in." },

    -- Quests that were complete on their own, whose newly found prerequisites miss a start or turn-in: shown alone
    -- until those steps are known. Remove an entry to show the full questline.
    { key = 4024, field = "requires", value = nil, type = "correction",
      note = "A Taste of Flame: its prerequisite chain leads to Trinkets... (3481), which starts and ends at an object not in our data." },
    { key = 78307, field = "requires", value = nil, type = "correction",
      note = "The Horn of Xelthos: its prerequisite 78261 starts and ends at an object not in our data." },
    { key = 78699, field = "requires", value = nil, type = "correction",
      note = "The Eye of Bhossca: its prerequisites 78676 and 78261 start and end at objects not in our data." },
    { key = 95140, field = "requires", value = nil, type = "correction",
      note = "Old Fire-Eye: two steps of its prerequisite chain (91860, 91861) start or end at objects not in our data." },
})
