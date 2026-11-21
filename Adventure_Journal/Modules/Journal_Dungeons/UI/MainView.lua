-- ============================================================================
-- Journal_Dungeons - UI/MainView.lua
-- The Dungeons tab: Core's instance list and instance book drawn from the
-- dungeon template, under Core's BookNavigator.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

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
local MainView = parent.UI.InstanceModule:Navigator(parent.Templates:Get("dungeon"))

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainView = MainView
