-- ============================================================================
-- Adventure Journal - Core/UI/InstanceList.lua
-- An instance list drawn from a template: one card per instance of the
-- template's type (a CardList), in the order InstanceListOrder gives
-- (filtered, sorted and grouped by the player's settings). Redraws on level
-- up, on setting changes, and when loaded item names change what a search
-- matches.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local concat = table.concat
local C_Timer = C_Timer
local GameTooltip = GameTooltip
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

--- The instance's tooltip: name, levels and location, description, its wings, and a click hint.
local function fillTooltip(template, d)
    local T = ns.Templates
    GameTooltip:AddLine(d.fullName, 1.0, 0.82, 0.0)
    -- "Level 60 • Dustwallow Marsh"; a list whose cards show the group size adds it after the level
    local parts = { T:Text(template, "listLevel", d.level or "?") }
    if template.listInfo == "size" and d.maxPlayers then
        parts[#parts + 1] = T:Text(template, "size", d.maxPlayers)
    end
    parts[#parts + 1] = d.location or ""
    GameTooltip:AddLine(concat(parts, " • "), 0.90, 0.82, 0.62)
    if d.description and d.description ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(d.description, 0.85, 0.85, 0.85, true)
    end
    -- A dungeon with wings lists them in order, each with its levels
    if d.wingCount and d.wingCount > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T:Text(template, "listWings"), 1.0, 0.82, 0.0)
        for _, wing in ipairs(ns.Data.InstanceAccess:GetWings(d)) do
            GameTooltip:AddDoubleLine(wing.name, wing.level and T:Text(template, "listLevel", wing.level) or "",
                0.95, 0.95, 0.95, 0.90, 0.82, 0.62)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T:Text(template, "listOpen"), 0.25, 0.92, 0.32)
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
    self.cards = Blocks.CardList:Create(parent, {
        geometry = self.template.layout.list,
        layouts = self.template.layout.list.LAYOUTS,
        onSelect = function(dungeon)
            if self.onSelectDungeon then
                self.onSelectDungeon(dungeon)
            end
        end,
        onTooltip = function(d)
            fillTooltip(self.template, d)
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
