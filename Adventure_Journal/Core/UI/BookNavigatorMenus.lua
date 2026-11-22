-- ============================================================================
-- Adventure Journal - Core/UI/BookNavigatorMenus.lua
-- The breadcrumb dropdowns of an instance module's navigator: the other
-- instances, the instance's wings, the bosses on the page, and the quests.
-- Each returns `{ { title, entries = { { text, isCurrent, onSelect } } } }`.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local BookNavigator = ns.UI.BookNavigator

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local function access()
    return ns.Data.InstanceAccess
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
--- The instance crumb's dropdown: every instance in the list's order and sections.
function BookNavigator:InstanceMenu(currentKey)
    local sections = {}
    for _, group in ipairs(self.list:AllGrouped()) do
        local entries = {}
        for _, instance in ipairs(group.entries) do
            entries[#entries + 1] = { text = instance.name, isCurrent = instance.key == currentKey, onSelect = function()
                self:SelectInstance(instance)
            end }
        end
        sections[#sections + 1] = { title = group.title, entries = entries }
    end
    return sections
end

--- The wing crumb's dropdown: the wings of `parent`, in their order.
function BookNavigator:WingMenu(parent)
    local entries = {}
    for _, wing in ipairs(access():GetWings(parent)) do
        entries[#entries + 1] = { text = wing.name, isCurrent = self.current ~= nil and self.current.key == wing.key,
            onSelect = function()
                self:SelectWing(wing)
            end }
    end
    return { { entries = entries } }
end

--- The boss crumb's dropdown: the encounters on the left page, in its sections.
function BookNavigator:BossMenu()
    local sections = {}
    for _, section in ipairs(self.book:ShownEncounterSections()) do
        local entries = {}
        for _, boss in ipairs(section.encounters) do
            entries[#entries + 1] = { text = boss.name, isCurrent = boss == self.selectedBoss, onSelect = function()
                self:SelectBoss(boss)
            end }
        end
        sections[#sections + 1] = { title = section.label, entries = entries }
    end
    return sections
end

--- The Quests crumb's dropdown: the instance's quests, in the Quests tab's sections.
function BookNavigator:QuestMenu()
    local sections = {}
    for _, section in ipairs(self.book:QuestRows()) do
        local entries = {}
        for _, row in ipairs(section.rows) do
            entries[#entries + 1] = { text = row.name, isCurrent = row.isSelected, onSelect = function()
                self.book:SelectQuest(row.quest)
            end }
        end
        sections[#sections + 1] = { title = section.header, entries = entries }
    end
    return sections
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.BookNavigator)
