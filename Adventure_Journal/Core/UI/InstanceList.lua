-- ============================================================================
-- Adventure Journal - Core/UI/InstanceList.lua
-- An instance list drawn from a template: one card per instance of the
-- template's type (a CardList), in the order InstanceListOrder gives
-- (filtered, sorted and grouped by the player's settings). Redraws on level
-- up, on setting changes, and when loaded item names change what a search
-- matches. Lists with favorites (InstanceFavorites): right-click a card to
-- add or remove it; favorites get a star, and favorite instances and wings
-- are copied into a Favorites section above the rest while the template's
-- `showFavorites` setting is on.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local concat = table.concat
local C_Timer = C_Timer
local setmetatable = setmetatable

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks

--- The zone part of a dungeon's location ("Moonbrook, Westfall" -> "Westfall").
local function zoneOf(location)
    if not location then
        return nil
    end
    return location:match(",%s*([^,]+)$") or location
end


-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local InstanceList = {}
InstanceList.__index = InstanceList

--- A list for instances drawn from `template` (a registered template). Call Init to build it.
function InstanceList:New(template)
    return setmetatable({ template = template, searchQuery = "" }, InstanceList)
end

--- One of the list's settings by the template's name for it (`template.settingKeys`).
function InstanceList:Setting(name)
    return ns.Settings:GetModuleSetting(self.template.settings, self.template.settingKeys[name])
end

--- Builds the list inside `parent`.
--- @param parent Frame
--- @param onSelectDungeon function `function(dungeon)`
function InstanceList:Init(parent, onSelectDungeon)
    if self.frame then
        return
    end
    self.onSelectDungeon = onSelectDungeon
    local template = self.template
    local Favorites = ns.UI.InstanceFavorites
    local hasFavorites = Favorites:IsOn(template)
    self.cards = Blocks.CardList:Create(parent, {
        geometry = template.layout.list,
        layouts = template.layout.list.LAYOUTS,
        onSelect = function(dungeon)
            if self.onSelectDungeon then
                self.onSelectDungeon(dungeon)
            end
        end,
        onTooltip = function(view)
            ns.UI.InstanceTooltip:Fill(template, view)
        end,
        onRightClick = hasFavorites and function(view)
            Favorites:Toggle(template, view)
        end or nil,
        isMarked = hasFavorites and function(view)
            return Favorites:IsFavorite(template, view)
        end or nil,
        -- A favorite wing in the Favorites section shows its instance's name too ("Stratholme: Main Gate")
        nameFor = function(view)
            return view.wingKey and view.fullName or view.name
        end,
    })
    local frame = self.cards.frame
    self.frame = frame
    frame:SetScript("OnShow", function()
        self:Refresh()
    end)

    -- Settings that change the list redraw it
    local keys = self.template.settingKeys
    local watched = { [keys.showLevel] = true, [keys.showColor] = true, [keys.listSort] = true, [keys.listLayout] = true }
    local groups = self.template.listGroups
    if groups then
        watched[keys[groups.setting]] = true
    end
    if hasFavorites then
        watched[keys.favorites] = true
        watched[keys.showFavorites] = true
    end
    self.settingsListener = ns.Settings:AddChangeListener(function(moduleKey, key)
        if moduleKey == self.template.settings and watched[key] and self.frame and self.frame:IsShown() then
            self:Refresh()
        end
    end)

    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LEVEL_UP" and self.frame:IsShown() then
            self:Refresh()
        end
    end)

    -- Loaded item names can change which dungeons a search matches; loads close together refresh once
    local liveData = ns.DataStore and ns.DataStore.Live
    local refreshTimer
    if liveData then
        liveData:AddListener(function()
            if refreshTimer or not (self.frame and self.frame:IsShown() and self.searchQuery ~= "") then
                return
            end
            refreshTimer = C_Timer.NewTimer(0.08, function()
                refreshTimer = nil
                if self.frame and self.frame:IsShown() then
                    self:Refresh()
                end
            end)
        end)
    end
end

--- Updates the active search filter and re-renders the list.
--- @param queryText string
function InstanceList:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

--- Rebuilds the list in the player's sort order and layout.
function InstanceList:Refresh()
    if not self.frame then
        return
    end
    local listCfg = self.template.layout.list
    local showLevel = self:Setting("showLevel") == true
    local showColor = self:Setting("showColor") == true
    local layoutKey = self:Setting("listLayout")
    if not listCfg.LAYOUTS[layoutKey] then
        layoutKey = listCfg.DEFAULT_LAYOUT
    end
    local Order = ns.UI.InstanceListOrder
    local dungeons = Order:Filtered(self.template.instanceType, self.searchQuery, self:Setting("listSort"))
    local groups = self.template.listGroups
    local sections = Order:Grouped(self.template, dungeons, groups and self:Setting(groups.setting) == true)
    sections = self:WithFavoritesSection(sections, dungeons)

    self.cards:Render(sections, layoutKey, function(dungeon, layout)
        local info = {}
        if self.template.listInfo == "size" then
            info[#info + 1] = dungeon.maxPlayers and ns.Templates:Text(self.template, "size", dungeon.maxPlayers) or nil
        elseif showLevel then
            local level = ns.Templates:Text(self.template, "listLevelShort", dungeon.level or "")
            if showColor then
                level = Blocks.LevelTag:Colorize(level, Blocks.LevelTag:InstanceColor(dungeon))
            end
            info[#info + 1] = level
        end
        -- The small centered cards show only the first part; the others add the zone
        if not layout.centered then
            info[#info + 1] = zoneOf(dungeon.location)
        end
        return concat(info, " - ")
    end, listCfg.MISSING_ART_ICON, function(dungeon)
        local crop = ns.Templates.Resolver:Slot(self.template, "card.crop", dungeon, "InstanceStore", dungeon.key)
        return crop and crop.centerV
    end)
end

--- `sections` with the favorites among `instances` and their wings (in list order, each favorite wing after its
--- instance's place) copied into a Favorites section on top, and the rest under one titled section, when the list
--- has favorites, its Favorites section setting is on, and any favorite is listed (the search can hide them all).
--- Otherwise `sections` unchanged.
function InstanceList:WithFavoritesSection(sections, instances)
    local template = self.template
    local Favorites = ns.UI.InstanceFavorites
    if not (Favorites:IsOn(template) and self:Setting("showFavorites") == true) then
        return sections
    end
    local favorites = {}
    for _, instance in ipairs(instances) do
        if Favorites:IsFavorite(template, instance) then
            favorites[#favorites + 1] = instance
        end
        if instance.wingCount and instance.wingCount > 0 then
            for _, wing in ipairs(ns.Data.InstanceAccess:GetWings(instance)) do
                if Favorites:IsFavorite(template, wing) then
                    favorites[#favorites + 1] = wing
                end
            end
        end
    end
    if #favorites == 0 then
        return sections
    end
    local T = ns.Templates
    local result = { { title = T:Text(self.template, "favoritesHeader"), entries = favorites } }
    -- A list without its own groups gets one titled section for everything; grouped lists keep their headers
    if #sections == 1 and not sections[1].title then
        result[2] = { title = T:Text(self.template, "allHeader"), entries = sections[1].entries }
    else
        for _, section in ipairs(sections) do
            result[#result + 1] = section
        end
    end
    return result
end

--- Every instance of the list, ignoring the search box, in the player's sort order and the list's sections
--- (InstanceListOrder:Grouped): `{ { title, entries } }`.
function InstanceList:AllGrouped()
    local Order = ns.UI.InstanceListOrder
    local instances = Order:Filtered(self.template.instanceType, "", self:Setting("listSort"))
    local groups = self.template.listGroups
    return Order:Grouped(self.template, instances, groups and self:Setting(groups.setting) == true)
end

function InstanceList:Show()
    if self.frame then
        self.frame:Show()
        self:Refresh()
    end
end

function InstanceList:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.InstanceList = InstanceList
