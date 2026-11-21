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
local MapIconsModule = {
    id = "map_icons",
    title = "Map Icons",
    addonName = "Utility_MapIcons",
    description = "Provides world and zone map indicators for dungeon and raid entrances, with level-bracket filtering.",
    icon = "Interface\\Icons\\INV_Misc_Map02",
    order = 900,
    isUtility = true,
}

local eventFrame = CreateFrame("Frame")

--- Unloads all Map Icons coordinate tables, World Map pins, and event listeners from memory
--- when the module is disabled, requiring a UI `/reload` to restore.
function MapIconsModule:OnUnload()
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
    ns.MapAccess = nil
    ns.AreaLabelProvider = nil
    ns.MapIconsConstants = nil
    ns.OpenDungeon = nil
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(MapIconsModule)
end

ns.MapIconsModule = MapIconsModule

-- ----------------------------------------------------------------------------
-- 3. Module Lifecycle & Navigation
-- ----------------------------------------------------------------------------

--- Checks whether a given Journal module is active and enabled.
--- @param moduleID string
--- @return boolean
function ns.IsModuleEnabled(moduleID)
    if not moduleID then
        return true
    end
    if ns.Settings and ns.Settings.IsModuleDisabled then
        return not ns.Settings:IsModuleDisabled(moduleID)
    end
    if _G.JournalBaseDB and _G.JournalBaseDB.disabledModules then
        return not _G.JournalBaseDB.disabledModules[moduleID]
    end
    return true
end

--- Opens Adventure Journal directly to a dungeon (or wing) page.
--- @param dungeonKey number|string instance map ID or wing slug
function ns.OpenDungeon(dungeonKey)
    local dungeons = ns.Dungeons
    local target = dungeons and ns.Data.InstanceAccess:GetInstance(dungeonKey)
    if not target then
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
    if ns.ModuleRegistry and ns.ModuleRegistry.ActivateModule then
        ns.ModuleRegistry:ActivateModule("dungeons")
    elseif _G.JournalBase and _G.JournalBase.ActivateModule then
        _G.JournalBase:ActivateModule("dungeons")
    end

    -- 3. Navigate through the Dungeons module (a wing opens with its dungeon in the breadcrumbs)
    local module = ns.ModuleRegistry:GetModule("dungeons")
    if module and module.definition.OpenInstance then
        module.definition:OpenInstance(target)
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
        ns.Settings:AddChangeListener(function(_, key)
            if (key == "worldMapDungeonIcons" or key == "showFlightPaths" or key == "useFactionColorsForFlightPaths"
                or key == "showEnemyFactionFlightPaths") and ns.MapPinProvider then
                ns.MapPinProvider:Refresh()
            end
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        if ns.MapPinProvider and _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then
            ns.MapPinProvider:Refresh()
        end
    end
end)
