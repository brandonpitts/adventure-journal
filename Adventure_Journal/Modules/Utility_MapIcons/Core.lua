-- ============================================================================
-- Utility_MapIcons - Core.lua
-- Lifecycle management, event listeners, and Adventure Journal navigation.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local Constants = ns.MapIconsConstants

-- ----------------------------------------------------------------------------
-- 2. Module Registration with JournalBase
-- ----------------------------------------------------------------------------
local MapIconsPlugin = {
    id = "map_icons",
    title = "Map Icons",
    addonName = "Utility_MapIcons",
    version = Constants.VERSION,
    lastUpdated = "2026-11-13",
    description = "Provides world and zone map indicators for dungeon and raid entrances, with level-bracket filtering.",
    apiVersion = 1,
    icon = "Interface\\Icons\\INV_Misc_Map02",
    order = 900,
    isUtility = true,
}

local eventFrame = CreateFrame("Frame")

--- Unloads all Map Icons coordinate tables, World Map pins, and event listeners from memory
--- when the module is disabled, requiring a UI `/reload` to restore.
function MapIconsPlugin:OnUnload()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    if ns.MapPinProvider then
        if ns.MapPinProvider.ReleaseAllPins then
            ns.MapPinProvider:ReleaseAllPins()
        end
        table.wipe(ns.MapPinProvider)
        ns.MapPinProvider = nil
    end
    if ns.EntranceCoordinates and type(ns.EntranceCoordinates) == "table" then
        table.wipe(ns.EntranceCoordinates)
        ns.EntranceCoordinates = nil
    end
    if ns.ZoneLevels and type(ns.ZoneLevels) == "table" then
        table.wipe(ns.ZoneLevels)
        ns.ZoneLevels = nil
    end
    if ns.FlightPaths and type(ns.FlightPaths) == "table" then
        table.wipe(ns.FlightPaths)
        ns.FlightPaths = nil
    end
    ns.AreaLabelProvider = nil
    ns.MapIconsConstants = nil
    ns.OpenDungeon = nil
    ns.GetDungeonMapLocation = nil
    _G.AdventureJournal_GetDungeonMapLocation = nil
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(MapIconsPlugin)
end

ns.MapIconsPlugin = MapIconsPlugin

-- ----------------------------------------------------------------------------
-- 3. Module Lifecycle & Navigation
-- ----------------------------------------------------------------------------

--- Checks whether a given Journal plugin is active and enabled.
--- @param pluginID string
--- @return boolean
function ns.IsPluginEnabled(pluginID)
    if not pluginID then
        return true
    end
    if ns.Database and ns.Database.IsPluginDisabled then
        return not ns.Database:IsPluginDisabled(pluginID)
    end
    if _G.JournalBaseDB and _G.JournalBaseDB.disabledPlugins then
        return not _G.JournalBaseDB.disabledPlugins[pluginID]
    end
    return true
end

--- Opens Adventure Journal directly to the specified dungeon encounter book.
--- @param dungeonID string
function ns.OpenDungeon(dungeonID)
    if not dungeonID then
        return
    end

    -- 1. Open the Journal window
    if _G.JournalBase and _G.JournalBase.Show then
        _G.JournalBase:Show()
    elseif _G.JournalBase and _G.JournalBase.Toggle then
        _G.JournalBase:Toggle()
    elseif ns.UI and ns.UI.MainFrame and ns.UI.MainFrame.Show then
        ns.UI.MainFrame:Show()
    end

    -- 2. Activate the Dungeons module tab
    if ns.PluginRegistry and ns.PluginRegistry.ActivatePlugin then
        ns.PluginRegistry:ActivatePlugin("dungeons")
    elseif _G.JournalBase and _G.JournalBase.ActivatePlugin then
        _G.JournalBase:ActivatePlugin("dungeons")
    end

    -- 3. Resolve dungeon data
    local dData = (ns.Dungeons and ns.Dungeons.Data and ns.Dungeons.Data.DungeonsData)
        or (_G.JournalDungeons and _G.JournalDungeons.ns and _G.JournalDungeons.ns.Data and _G.JournalDungeons.ns.Data.DungeonsData)
        or ns.DungeonsData

    local targetDungeon = nil
    if dData and dData.GetByID then
        targetDungeon = dData:GetByID(dungeonID)
    end
    if not targetDungeon and dData and dData.GetAll then
        for _, d in ipairs(dData:GetAll()) do
            if d.id == dungeonID then
                targetDungeon = d
                break
            end
        end
    end
    if not targetDungeon and dData and dData.dungeons then
        for _, d in ipairs(dData.dungeons) do
            if d.id == dungeonID then
                targetDungeon = d
                break
            end
        end
    end

    -- 4. Navigate to the dungeon in MainView
    local mainView = (ns.Dungeons and ns.Dungeons.UI and ns.Dungeons.UI.MainView)
        or (_G.JournalDungeons and _G.JournalDungeons.ns and _G.JournalDungeons.ns.UI and _G.JournalDungeons.ns.UI.MainView)
        or (ns.UI and ns.UI.MainView)

    if mainView and targetDungeon and mainView.SelectDungeon then
        mainView:SelectDungeon(targetDungeon)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Event Listener Frame
-- ----------------------------------------------------------------------------
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if ns.MapPinProvider then
            ns.MapPinProvider:Init()
        end
        if ns.AreaLabelProvider then
            ns.AreaLabelProvider:Init()
        end
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            local prevHook = _G.JournalBase.OnDungeonSettingChanged
            _G.JournalBase.OnDungeonSettingChanged = function(jBase, key, val)
                if prevHook then
                    prevHook(jBase, key, val)
                end
                if (key == "worldMapDungeonIcons" or key == "showFlightPaths" or key == "useFactionColorsForFlightPaths" or key == "showEnemyFactionFlightPaths") and ns.MapPinProvider then
                    ns.MapPinProvider:Refresh()
                end
            end
        end
    elseif event == "PLAYER_LEVEL_UP" then
        if ns.MapPinProvider and _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then
            ns.MapPinProvider:Refresh()
        end
    end
end)
