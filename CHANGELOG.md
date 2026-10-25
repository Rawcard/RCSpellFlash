# RC-SpellFlash Changelog

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
