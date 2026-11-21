-- ============================================================================
-- Utility_DataStore - Stores/QuestStore/DisplayOverrides.lua
-- Hand-kept display overrides: how a quest shows, never what it is (data
-- fixes go in Overrides.lua). Sync scripts never touch this file. Format
-- (Core/StoreDisplay.lua):
--   { key = <questID>, kind = "note" | "replace" | "hide" | "banner" | "place" | "layout",
--     target = "<slot or slot.field>", value = <what the kind needs>, note = "<why>" }
-- Targets are the quest template's slots (Core/Templates/QuestGroup.lua), e.g. "quest.rewards".
-- ============================================================================
local addonName, ns = ...

ns.DataStore.QuestStore:SetDisplayOverrides({
})
