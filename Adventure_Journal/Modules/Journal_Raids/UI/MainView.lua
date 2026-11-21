-- ============================================================================
-- Journal_Raids - UI/MainView.lua
-- The Raids tab: Core's instance list and instance book drawn from the raid
-- template, under Core's BookNavigator.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Raids or {} ; parent.Raids = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local MainView = parent.UI.InstanceModule:Navigator(parent.Templates:Get("raid"))

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainView = MainView
