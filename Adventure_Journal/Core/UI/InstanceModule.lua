-- ============================================================================
-- Adventure Journal - Core/UI/InstanceModule.lua
-- Registers an instance journal module (Dungeons, Raids) with the Journal:
-- its tab, its navigator (list, wing page, book) built from its template, the
-- window focus when the player is inside one of its instances, search, and
-- unloading. A module calls Register with its namespace and constants.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local wipe = table.wipe

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local InstanceModule = {}

--- The navigator for `template` (a registered instance template): list, book and breadcrumbs.
function InstanceModule:Navigator(template)
    return ns.UI.BookNavigator:New({
        list = ns.UI.InstanceList:New(template),
        book = ns.UI.InstanceBook:New(template),
        instanceType = template.instanceType,
        text = { home = ns.Templates:Text(template, "crumbHome"), quests = ns.Templates:Text(template, "questsTab") },
    })
end

--- Registers the module whose namespace is `moduleNs` (held at `ns[nsKey]`, e.g. "Dungeons") with the Journal.
--- `constants`: `{ MODULE_ID, TITLE, ADDON_NAME, DESCRIPTION, TAB_ORDER, ICON }`; `navigator` is the module's
--- (moduleNs.UI.MainView). Returns the module table.
function InstanceModule:Register(moduleNs, nsKey, constants, navigator)
    local module = {
        id = constants.MODULE_ID,
        title = constants.TITLE,
        addonName = constants.ADDON_NAME,
        description = constants.DESCRIPTION,
        order = constants.TAB_ORDER,
        icon = constants.ICON,
    }
    local instanceType = navigator.instanceType

    --- Called once by the Journal when the tab is first opened.
    function module:OnInitialize(canvas, headerBar)
        navigator:Init(canvas, headerBar)
    end

    --- Called whenever the tab is selected: shows the page left open, or the list.
    function module:OnActivate(_canvas, headerBar)
        navigator:Show(headerBar)
    end

    --- Called when the Home breadcrumb is clicked: shows the list.
    function module:OnHome(_canvas, headerBar)
        navigator:ShowRoot(headerBar)
    end

    --- Takes focus when the Journal opens while the player is inside one of this module's instances.
    function module:WantsWindowFocus()
        return ns.Data.InstanceAccess:GetCurrentInstance(instanceType) ~= nil
    end

    --- Opens the page of the instance the player is inside.
    function module:OnWindowFocus()
        navigator:OpenCurrentInstance()
    end

    --- Opens an instance's (or wing's) page; a wing opens with its instance in the breadcrumbs.
    function module:OpenInstance(view)
        if view.wingKey then
            navigator:SelectWing(view)
        else
            navigator:SelectInstance(view)
        end
    end

    --- Called when the user switches away to another module tab.
    function module:OnDeactivate()
        navigator:Hide()
    end

    --- Called when the user types in the Journal header search box while this tab is active.
    function module:OnSearch(queryText)
        navigator:OnSearch(queryText)
    end

    --- Drops the module's frames, listeners and data when it is disabled; a `/reload` restores it.
    function module:OnUnload()
        local list, book = navigator.list, navigator.book
        if list and list.frame then
            list.frame:UnregisterAllEvents()
            list.frame:SetScript("OnEvent", nil)
            list.frame:SetScript("OnShow", nil)
            list.frame:Hide()
        end
        if book and book.frame then
            book.frame:Hide()
        end
        if navigator.rootFrame then
            navigator.rootFrame:Hide()
        end
        for _, view in ipairs({ list, book }) do
            if view and view.settingsListener then
                ns.Settings:RemoveChangeListener(view.settingsListener)
            end
        end
        wipe(moduleNs)
        ns[nsKey] = nil
    end

    if _G.JournalBase and _G.JournalBase.RegisterModule then
        _G.JournalBase:RegisterModule(module)
    end
    return module
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.InstanceModule = InstanceModule
