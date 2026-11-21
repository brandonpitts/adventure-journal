-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/WingList.lua
-- An instance's wings on a book's left page: one picture card per wing (its
-- loading screen, name, and level range in its difficulty color).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local max = math.max
local setmetatable = setmetatable
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local LEFT_MARGIN = 26
local START_Y = -16

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local WingList = {}
WingList.__index = WingList

--- A wing list drawn into `child` (the left page's scroll child; `scroll` its scroll frame). Cards are
--- `width` x `height`, `gap` apart. `onSelect(wing)` runs on a click.
function WingList:Create(scroll, child, width, height, gap, onSelect)
    return setmetatable({ scroll = scroll, child = child, width = width, height = height, gap = gap,
        onSelect = onSelect, cards = {} }, WingList)
end

function WingList:CreateCard()
    local card = Blocks.StoneCard:Create(self.child, self.width, self.height, { picture = true })
    card:SetScript("OnClick", function(c)
        PlaySound(Styles.SOUNDS.CLICK)
        if c.wing then
            self.onSelect(c.wing)
        end
    end)
    return card
end

--- Draws `wings` (instance views). `options`: `showLevel`, `useDifficultyColor`.
function WingList:Render(wings, options)
    self:Hide()
    local y = START_Y
    for i, wing in ipairs(wings) do
        local card = self.cards[i] or self:CreateCard()
        self.cards[i] = card
        card.wing = wing
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", self.child, "TOPLEFT", LEFT_MARGIN, y)
        card.nameText:SetText(wing.name)
        Blocks.StoneCard:SetInstancePicture(card, wing)
        card.subText:SetText(wing.level and ("Lvl " .. wing.level) or "")
        card.subText:SetShown(options.showLevel)
        if options.useDifficultyColor then
            card.subText:SetTextColor(Blocks.LevelTag:InstanceColor(wing))
        else
            card.subText:SetTextColor(1, 1, 1)
        end
        card:Show()
        y = y - (self.height + self.gap)
    end
    local height = -y + 10
    self.child:SetHeight(max(1, height))
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
end

function WingList:Hide()
    for _, card in ipairs(self.cards) do
        card:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.WingList = WingList
