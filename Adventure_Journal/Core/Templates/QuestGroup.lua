-- ============================================================================
-- Adventure Journal - Core/Templates/QuestGroup.lua
-- The quest group template: quests gathered under one subject (a dungeon's,
-- a raid's, or any other set), listed on the left page with the chosen quest
-- on the right. It holds the list's sections, the detail page's sections in
-- order, the slots with their placeholders, and all the quest text. "{noun}"
-- is the host's noun ("Dungeon"): the group is shown inside the host's book.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Template Definition
-- ----------------------------------------------------------------------------
ns.Templates:Extend("base", "questGroup", {
    -- The list's sections, in order. "attunement": the quests the group's attunement lists (a raid's way in);
    -- "faction": the group's other quests, `faction` "player" (the player's faction and both-faction quests) or
    -- "other". `label`: a header's text key; `setting`: the host's setting (by its name in the host's
    -- settingKeys) that shows the section.
    listSections = {
        { kind = "attunement", label = "attunement" },
        { kind = "faction", faction = "player" },
        { kind = "faction", faction = "other", setting = "showBothFactions", dividerBefore = true },
    },

    -- A quest's page, top to bottom (a questline's step too); each is a `quest.<name>` slot
    detailSections = { "objectives", "source", "turnin", "requirements", "rewards" },

    -- Fields the page shows and what shows when one is missing (false: nothing). Display overrides target these.
    slots = {
        ["quest.title"] = { field = "name", placeholder = "Unknown Quest" },
        ["quest.objectives"] = { field = "objective", placeholder = "No objective description available." },
        ["quest.source"] = { field = "pickup", placeholder = "Unknown" },
        ["quest.turnin"] = { field = "turnin", placeholder = false },
        ["quest.requirements"] = { placeholder = false },
        ["quest.rewards"] = { field = "rewardItems", placeholder = false },
    },

    text = {
        noQuests = "No quests available for this {noun_lower}.",
        attunement = "Attunement",
        itemDrop = "Item Drop",
        questline = "Questline",
        step = "Step %d: %s",
        objectives = "Objectives",
        questLogTitle = "Show on Map",
        questLogHint = "Click to open the map and quest log to this quest.",
        source = "Quest Source",
        turnin = "Turn-In",
        sourceInside = "Source item is located inside the {noun_lower}.",
        turninInside = "Turn-in is located inside the {noun_lower}.",
        noCoords = "Location coordinates unavailable.",
        pinTarget = "Quest Location",
        requirements = "Requirements",
        requiresLevel = "Requires Level %s",
        rewards = "Rewards",
        experience = "• Experience: %s XP",
        rewardChoice = "Choose one of the following rewards:",
        rewardAlso = "You will also receive:",
    },
})

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Registered with ns.Templates)
