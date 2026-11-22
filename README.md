# Adventure Journal (WoW Forever Client)

**Adventure Journal** is a modular in-game journal framework for the *World of Warcraft Forever* client. It currently provides comprehensive dungeon encounter and item drop catalogs and a raid journal, with planned modules for primary and secondary professions, class questlines, and more.

> [!NOTE]
> **Project Scope & Notice:** Adventure Journal is an independent project created for personal, close friend, and friend-of-friend use. Anyone is welcome to use it with that understanding! Please report any issues directly to **Brandon (Endoria)**.

---

## Feature Highlights

* **Modular Architecture & Cross-Module Synergy**: Engineered for deep cross-module integration—connecting map markers, encounter catalogs, global search, and future questlines into a unified reference tool—while maintaining a lightweight, intentional footprint that allows players to enable only the exact modules they need.
* **Planned Ecosystem Modules**: Active development roadmap includes dedicated modules for Primary & Secondary Professions (recipes, reagents, and trainer sources), and Questlines (dungeon attunements and class quest chains).
* **Dungeon Item Lists & Encounters**: Comprehensive directories across Classic Dungeons and WoW Forever Dungeons, with an extensible catalog built to seamlessly incorporate any future added instances, boss rosters, lore backgrounds, and encounter item drops.
* **Game Enhancements**: Adventure-focused game enhancements with cross-module integration: native Blizzard map pin system integration for dungeon entrance portals, planned travel lane markers for zeppelins and boats, and more.
* **Real-Time Live Search**: Fast, responsive search filtering across dungeons, boss encounters, aliases, and specific item drops, with automatic cross-module encounter discovery.
* **Raid Journal & Attunements**: WoW Forever's raids grouped by raid tier, with group sizes, bosses and attunement questlines: Onyxia's Lair today, with Hyjal Summit and The Barrow Deeps ready for when they open. Built on the same page design as the dungeons, so new raids arrive as data.

---

## Built with Agentic Coding

Adventure Journal was developed through agentic AI workflows to assist, explore, test, and refine agent-driven software engineering skills, architectural patterns, and development practices using models from **Google (Gemini)** and **Anthropic (Claude)**.

---

## Quick Installation

1. Download **[`Adventure_Journal-v0.13.0.zip`](Adventure_Journal-v0.13.0.zip)**.
2. Extract the archive into your WoW Forever AddOns directory:
   ```text
   World of Warcraft\_forever_\Interface\AddOns\
   ```
   > **Tip:** You can easily locate your game folder by clicking the gear icon next to the Play button in the Battle.net launcher for your WoW Forever client and selecting **"Show in Explorer"**.
3. Confirm that the folder is named `Adventure_Journal` (not `Adventure_Journal-v0.13.0` or a nested folder).
4. Launch or `/reload` in World of Warcraft.
5. Open your journal with `/aj`, `/journal`, or by clicking the gold Minimap button!

---

## Changelog & Release History

* **`v0.13.0`**: Favorite dungeons and wings (right-click a card) with an optional Favorites section, richer tooltips on instance cards, nearly 200 more dungeon quests, quests now shown only to the faction and class that can take them, class crests on class quests, and a new Show All Class Quests setting; Show Both Factions' Instance Quests now applies to raids too.
* **`v0.12.1`**: Fixed an error when opening the Journal inside a dungeon or raid; inside instances the Journal now uses its own boss and NPC names.
* **`v0.12.0`**: Rebuilt the breadcrumb bar at the top of the Journal in the style of the retail Adventure Guide: each step is a button fitted to its name, and dropdowns on the dungeon, wing, boss and quest steps jump straight to another one.
* **`v0.11.1`**: Fixed an error blamed on the Journal when opening the world map after using a Journal map button; the map buttons now open the map the game's own way, and only out of combat.
* **`v0.11.0`**: Rebuilt the Journal's pages on a new shared template system: dungeon pages are now drawn from reusable templates and blocks instead of hand-built screens, so new content arrives as data rather than new code; added the Raids module with shells for three upcoming raids.
* **`v0.10.0`**: New dungeon grid layouts (four, three, or two cards per row); level colors now match the game's own everywhere; the game's Settings window lists each settings section; the Journal reopens on the tab you used last; dungeon quest chains are listed once; added shells for the Raids and Quests modules.
* **`v0.9.0`**: Rebuilt all of the Journal's information into one DataStore checked against the game (corrected boss names, quest titles and loot); the Journal now opens to the dungeon and wing you're in; new dungeon cards, side tabs, and window background settings.
* **`v0.8.0`**: Added Dungeon Quests: quest lists, multi-step quest chains, quest givers and turn-ins with map pins, and an option to show both factions' quests.
* **`v0.7.2`**: Made the Journal fully standalone by removing all optional integrations with other addons, and streamlined the Settings panel.
* **`v0.7.1`**: Added global frame naming for third-party minimap button collector compatibility and decoupled the Blizzard Addon Compartment setting with an independent unchecked default.
* **`v0.7.0`**: Added World Map Zone Level Overlays with recommended level ranges and fishing skill requirements, flight path indicators, and native Character Frame close button styling.
* **`v0.6.0`**: Added Central Item Storage Engine with opt-in multi-tag and level-range search, true memory unloading for disabled modules (`/reload` lifecycle), default landing tab radio selection, and Architecture & Catalog Telemetry documentation pages.
* **`v0.5.1`**: Resolved custom keybinding reservation conflicts, added persistent agent automation rules, and verified clean fresh installs.
* **`v0.5.0`**: Consolidated unified addon versioning across all modules, shortened default landing tab selector, and added catalog notice.
* **`v0.4.0`**: Initial public release with Classic and WoW Forever dungeons, open-book split view, and world map entrance markers.

---

## Feedback & Support

Please send bug reports and feature requests to **Brandon (Endoria)**.

We apologize to players outside our direct circles who may not have a direct way to reach out—there are currently no plans to establish a public Discord or community channel at this time.

---

## Public Website & Technical Documentation
Visit the official GitHub Pages site:
* 👉 **Home & Download:** **[https://brandonpitts.github.io/adventure-journal/](https://brandonpitts.github.io/adventure-journal/)**
* ⚙️ **Architecture & Data Engine:** **[https://brandonpitts.github.io/adventure-journal/architecture.html](https://brandonpitts.github.io/adventure-journal/architecture.html)**
* 📊 **Catalog Telemetry:** **[https://brandonpitts.github.io/adventure-journal/catalog.html](https://brandonpitts.github.io/adventure-journal/catalog.html)**
