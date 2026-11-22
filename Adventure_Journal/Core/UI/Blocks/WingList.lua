-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/WingList.lua
-- An instance's wings on a book's left page: one picture card per wing (its
-- loading screen, name, and level range in its difficulty color). Hovering a
-- card shows a tooltip the caller fills; with favorites, right-clicking one
-- adds or removes it and favorites show a star.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local max = math.max
local setmetatable = setmetatable
local GameTooltip = GameTooltip
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
--- `width` x `height`, `gap` apart. `onSelect(wing)` runs on a click. `options` (optional):
--- - `onTooltip(wing)`: fills GameTooltip (owned and shown by the list)
--- - `onRightClick(wing)` and `isMarked(wing)`: favorites (a right-click toggles; marked wings show the star)
function WingList:Create(scroll, child, width, height, gap, onSelect, options)
    return setmetatable({ scroll = scroll, child = child, width = width, height = height, gap = gap,
        onSelect = onSelect, options = options or {}, cards = {} }, WingList)
end

--- Shows the card's star when its wing is marked.
function WingList:UpdateStar(card)
    if card.favoriteStar then
        Blocks.StoneCard:ShowFavoriteStar(card, card.wing ~= nil and self.options.isMarked(card.wing) == true)
    end
end

function WingList:CreateCard()
    local options = self.options
    local card = Blocks.StoneCard:Create(self.child, self.width, self.height, { picture = true })
    local function showTooltip(c)
        if c.wing and options.onTooltip then
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            options.onTooltip(c.wing)
            GameTooltip:Show()
        end
    end
    if options.onRightClick then
        card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    card:SetScript("OnClick", function(c, button)
        PlaySound(Styles.SOUNDS.CLICK)
        if not c.wing then
            return
        end
        if button == "RightButton" then
            options.onRightClick(c.wing)
            self:UpdateStar(c)
            if c:IsMouseOver() then
                showTooltip(c)
            end
        else
            self.onSelect(c.wing)
        end
    end)
    -- Hooked, not set: the card's own hover and press visuals are hooks too
    card:HookScript("OnEnter", showTooltip)
    card:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if options.isMarked then
        Blocks.StoneCard:AddFavoriteStar(card)
    end
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
        self:UpdateStar(card)
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
