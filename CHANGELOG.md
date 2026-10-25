# RC-SpellFlash Changelog

## Version 2.1.2 (2026-10-25)

### Works on every client
- **Retail and WoW Forever supported** (new TOC files). The flash itself, the options window and the NAG bridge all load there now.
- **Fixed errors on Retail and WoW Forever:** the NAG bridge called GetSpellInfo (removed on Retail) on every update.
- Updated version numbers for TBC Anniversary 2.5.6, Wrath 3.4.5 and Classic Era 1.15.9.

### Bug fixes
- **"NAG Colors", "NAG Status", "Toggle NAG Debug" and "Test NAG Flash" buttons work.** They called the bridge's slash command by the wrong name, so the first errored and the others always said "NAG Bridge not loaded".
- **Color pickers work on clients with Blizzard's newer color picker.**
- **The flash texture:** the addon pointed at a custom texture in the wrong folder that was never shipped; it now uses the built-in star texture it was falling back to anyway.
- Check boxes and sliders in the options are created safely on clients that dropped the older options templates.
- RC-SpellFlash now lives on GitHub; releases are built and uploaded to CurseForge automatically.

## Version 1.2.0 (2026-04-01)

### ✨ New Features
- **Stance Bar Support** - Now flashes spells on stance bars (Druid forms, DK presences, Warrior stances, etc.)
- **Pet Action Bar Support** - Flashes pet abilities when recommended
- **Possess/Vehicle Bar Support** - Flashes vehicle and mind control abilities
- **ElvUI Stance Bar Support** - Full compatibility with ElvUI's custom stance bar frames
- **Enhanced Button Detection** - Detects spells using proper APIs for each button type

### 🔧 Technical Changes
- Added `GetShapeshiftFormInfo()` API for stance button spell detection
- Added `GetPetActionInfo()` API for pet action button spell detection
- Added `GetPossessInfo()` API for possess/vehicle button spell detection
- Stance buttons now use higher frame level (+10) to show above active stance glow
- Added ElvUI_StanceBarButton detection and support
- Flash texture uses OVERLAY draw layer 7 for better visibility

### 🐛 Bug Fixes
- Fixed function call order error in RC-NAGBridge initialization
- Fixed stance buttons not flashing when using ElvUI
- Fixed spell ID matching for stance abilities
- Added spell name fallback matching for all button types

### 📦 Compatibility
All WoW Classic versions (Vanilla, TBC, Wrath, Cata, MoP) with:
- ✅ Blizzard default UI
- ✅ ElvUI (action bars + stance bar)
- ✅ Bartender4
- ✅ Dominos

---

## Version 1.1.0 (2026-03-29)

### ✨ New Features
- **Full NAG Integration** - Automatically flashes spells recommended by NAG addon
- **Multi-version support** - Added TOC files for all WoW Classic versions
- **Smart API usage** - Uses NAG's display group system with fallback to direct spell data
- **Event-driven updates** - Hooks into NAG's frame update messages for better performance

### 🎨 Color System
- Primary spells: Yellow (1, 1, 0, 1)
- Left/Cooldown spells: Cyan (0, 1, 1, 1)
- AOE/Defensive/Interrupt spells: Orange (1, 0.5, 0, 1)

### 🔧 Technical Changes
- Added `RC-NAGBridge.lua` for NAG integration
- Implemented `NAG:GetDisplayGroupIconData()` API usage
- Added fallback to `NAG.secondarySpells` for compatibility
- Created version-specific TOC files for all Classic versions
- Added comprehensive debug mode for troubleshooting

### ✅ Compatibility
- Vanilla Classic (11503)
- TBC Classic Anniversary (20504)
- Wrath Classic (30403)
- Cataclysm Classic (40400)
- Mists of Pandaria Classic (50400)

### 🐛 Bug Fixes
- Fixed handling of NAG's new table-based spell format
- Fixed support for both group display mode and legacy mode
- Prevented duplicate spell flashing when same spell appears in multiple sources

---

## Version 1.0.0 (Earlier)

### Initial Release
- Basic spell flash functionality
- LibStub integration
- Multi-addon support
- Color customization API
