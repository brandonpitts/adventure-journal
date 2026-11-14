# Journal UI Style Rules & Architectural Standards

**Interface Target:** World of Warcraft: Forever (`Interface: 16001`)  
**Theme:** Signature Bronze / Dark Slate Stone & Ornate Filigree  
**Scope:** Applied across `Journal_Base` and all child modules (`Journal_Dungeons`, `Journal_Raids`, etc.)

---

## 1. Core Visual Pillars

1. **100% Native Assets**: All textures, borders, fonts, and sound effects must come from native Blizzard game files (`Interface\...`) or built-in Atlas records. Never require external texture files.
2. **Unified Base Shell**: All child modules render inside `JournalBaseMainFrame.ContentCanvas`. They inherit the window's dark slate stone background, navigation bar, and corner filigree without adding clashing layers.
3. **No Tinted Page Overlays**: Never place semi-transparent flat overlays (e.g. `WHITE_8X8` alpha washes) over panels or pages. The clean native stone background must show through evenly to prevent haze, discoloration of corner filigree, and visible rectangular seams.
4. **Filigree Margin Safety**: Always respect the outer corner filigree brackets of the main frame:
   * **Top content offset**: Keep elements at `Y <= -22px` from the content top (or give nested frames like `artBox` at least `Y <= -28px` to `-34px`).
   * **Right margin**: Inset outer panels by at least `16px` to `18px` from the right window boundary.
5. **Conditional Scroll Bars**: Scroll bars must be hidden whenever content fits within the viewable area without scrolling. Set `scrollFrame.scrollBarHideable = true` and call `SharedWidgets:UpdateScrollFrameVisibility(scrollFrame, contentHeight)` on refresh.

---

## 2. Signature Divider Bars

All dividers throughout the journal—both horizontal and vertical—share an identical embossed metallic groove style.

### Specification
* **Highlight Line (1px)**: Warm metallic bronze (`RGB: 0.65, 0.52, 0.28`, `Alpha: 0.80`).
* **Shadow Line (1px)**: Recessed dark stone groove (`RGB: 0.08, 0.06, 0.04`, `Alpha: 0.55`) placed directly adjacent (1px below for horizontal dividers, 1px to the right for vertical dividers).
* **Finial Fade-Outs (28px)**: Smooth alpha fade at both ends using `SetGradient("HORIZONTAL" | "VERTICAL")` from `Alpha: 0.0` to `Alpha: 0.80 / 0.55`. This prevents abrupt cutoffs and creates a soft, natural anchor into the background.
* **Thickness**: 4px total frame height/width container.

### Established Locations
* **Left Page Header Divider**: Directly below the dungeon/raid medallion header (`leftDivider`).
* **Center Spine Divider**: Vertical line running between the left scrollbar and the right panel (`verticalDivider`).
* **Instance Overview Divider**: Horizontal line between the framed instance artwork and the lore text (`overviewDivider`).
* **Boss Detail Divider**: Horizontal line between the boss lore snippet and the item drops container (`rightDivider`).

### 2.1 Breadcrumb Navigation Chevrons
* **Separator**: Native Blizzard Chat Expand Arrow (`Interface\ChatFrame\ChatFrameExpandArrow`).
  * **Dimensions**: Width `10px`, Height `11px`.
  * **Color Tint**: Signature warm bronze (`RGB: 0.85, 0.72, 0.45`, `Alpha: 0.85`).
  * **Spacing**: Sequential `8px` gap between previous crumb, chevron, and next crumb.

---

## 3. Open-Book Split View (Dungeons & Raids)

The split-book layout is the standard interface for browsing instances and encounters.

```text
+---------------------------------------------------------------------------------+
| [Medallion] Instance Title                    | [Art Box (UI-DialogBox-Border)] |
| Lvl xx-yy • Location                          | [Instance Banner Title]         |
| --------------------------------------------- | ------------------------------- |
| (Boss Scroll Area)                     | [S]  | Instance Overview Lore Text     |
|   [Medallion+Dragon] Boss Name   Lv xx | [P]  |                                 |
|   [Medallion+Dragon] Boss Name   Lv xx | [I]  | (OR Boss Mode:)                 |
|   [Medallion+Dragon] Boss Name   Lv xx | [N]  | [Boss Medallion] Boss Title     |
|   ...                                  | [E]  |                  Level Tag      |
|                                        |      | Boss Lore Snippet               |
|                                        |      | ------------------------------- |
|                                        |      | Item Drops Container            |
+---------------------------------------------------------------------------------+
```

### 3.1 Left Page (Boss List Buttons)
* **Button Slab Dimensions**: Height `44px`, Width `268px`, Vertical Gap `30px`, Left Margin `26px`.
* **Horizontal Thermometer Structure**: The circular medallion (icon size `50px`, ring size `68px`) extends `-10px` outside the left of the button slab, creating a distinct "bulb and stem" profile.
* **Portrait Dragons & Classification**:
  * Scaled up by **25%** for bold visibility (`BOSS_RING_SIZE = 68`).
  * Elite / Boss: `UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold`.
  * Rare: `UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver`.
  * UV coordinates trimmed to eliminate target frame bar artifacts.
* **Boss Name Handling**:
  * **Word-Wrapping**: Multi-line wrapping enabled with `SetWordWrap(true)`, `SetSpacing(2)`, and vertical alignment `MIDDLE`.
  * **Color Palette**:
    * Normal: Soft Gold (`RGB: 1.0, 0.88, 0.55`) with full black shadow (`1, -1`).
    * Hover: Highlight Gold (`RGB: 1.0, 0.94, 0.68`).
    * Selected: Bright Ivory Gold (`RGB: 1.0, 0.98, 0.82`).
* **Level Tag**: Right-aligned, toggleable via settings. When disabled, name text expands fully across the slab without truncating.

### 3.2 Right Page (Overview & Boss Detail)
* **Container Insets**: `TOPLEFT: +16, -10`, `BOTTOMRIGHT: -18, +10`.
* **Artwork Box**: Dimensions `376 x 186px`.
  * Border: `Interface\DialogFrame\UI-DialogBox-Border` with `edgeSize = 24`, frame offset `-8px / +8px`, untinted white (`1, 1, 1, 1`).
  * Top Vignette: Subtle vertical gradient overlay with gold banner title (`artBannerTitle`).
* **Boss Header Alignment**:
  * Medallion anchored at `TOPLEFT: 8, -6`.
  * Title (`rightTitle`): Word-wrapped with `-12px` right margin.
  * Level Tag (`rightBossLevel`): Anchored directly under the title (`TOPLEFT, rightTitle, BOTTOMLEFT, 0, -3`), pulled left flush against the medallion.
  * Dynamic Vertical Anchoring: The lore text and divider dynamically measure the maximum bottom extent of the medallion vs. title+level to ensure zero collision on multi-line names.

---

## 4. Typography & Color Standards

| Element | Font Template | Color (`RGB`) | Notes |
| :--- | :--- | :--- | :--- |
| **Window Title** | `GameFontHighlightLarge` | `1.0, 0.82, 0.00` | Centered top header |
| **Instance Title** | `GameFontHighlightLarge` | `1.0, 0.82, 0.00` | Header banner |
| **Boss List Name** | `GameFontNormal` (+2pt) | `1.0, 0.88, 0.55` | Word-wrapped, gold shadow |
| **Boss Right Title** | `GameFontHighlightLarge` | `1.0, 0.82, 0.00` | Full name with subtitles |
| **Level Tag (Normal)**| `GameFontNormalSmall` | `0.80, 0.72, 0.55` | Khaki/tan |
| **Level Tag (Rare)** | `GameFontNormalSmall` | `0.75, 0.85, 0.95` | Ice blue |
| **Lore Text** | `GameFontNormal` | `0.92, 0.85, 0.72` | Warm parchment reading text |
| **Meta / Location** | `GameFontNormalSmall` | `0.82, 0.72, 0.52` | Subtitle info |

---

## 5. Settings Panel Standards

1. **Modular Sectioning**: Every plugin/module must be grouped under its own header with a divider bar in `SettingsPanel.lua` (e.g. `"Dungeon Module"`, `"Raid Module"`).
2. **Namespaced Database Storage**: Settings must be saved under the plugin's namespace in `JournalBaseDB` (e.g. `JournalBaseDB.dungeons = { showBossLevel = false }`).
3. **Reactive UI Updates**: Setting changes must dispatch immediately via callbacks (e.g. `_G.JournalBase.OnDungeonSettingChanged`) so the interface updates in real-time without requiring a `/reload`.
4. **Descriptive Labels**: Checkbox labels must clearly state what they do (e.g. `"Show Levels on Boss List Buttons"` rather than vague shorthand).

---

## 6. Architecture & Code Elevation

When a styling rule or widget pattern is proven in a specific module (such as `Journal_Dungeons`), it should be elevated to `Journal_Base/UI/SharedWidgets.lua` so that subsequent modules (`Journal_Raids`, etc.) consume the identical API:

* `SharedWidgets:CreateHorizontalDividerBar(parent, height)`
* `SharedWidgets:CreateVerticalDividerBar(parent, width)`
* `SharedWidgets:CreateCircularMedallion(parent, iconSize, ringSize)`
* `SharedWidgets:StyleBossSlabButton(button)`
* `SharedWidgets:SetBossMedallionPortrait(medallion, boss, instance)`
* `SharedWidgets:SetMedallionClassification(medallion, boss)`
* `SharedWidgets:UpdateScrollFrameVisibility(scrollFrame, contentHeight)`


