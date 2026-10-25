# RC-SpellFlash - NAG Integration

Visual spell flash indicators with full NAG (Next Action Guide) integration support.

## ✨ Features

- **Multi-color spell flashing** - Different colors for different spell positions
- **Full NAG integration** - Automatically flashes spells recommended by NAG
- **Zero configuration** - Works out of the box when both addons are installed
- **Multi-version support** - Works on all WoW Classic versions

## 🎨 Color Coding

- **Yellow** - Primary spell (main rotation)
- **Cyan** - Left position spells (cooldowns)
- **Orange** - AOE/Defensive/Interrupt spells

## 🔧 Installation

1. Extract the RC-SpellFlash folder to your `World of Warcraft\_classic_\Interface\AddOns\` directory
2. Install NAG addon (optional but recommended)
3. Enable both addons in your character selection screen
4. Log in and play!

## ✅ Compatibility

### Supported WoW Classic Versions:
- ✅ **Vanilla Classic** (Season of Discovery, Anniversary, etc.)
- ✅ **TBC Classic** (Anniversary)
- ✅ **Wrath Classic** 
- ✅ **Cataclysm Classic**
- ✅ **Mists of Pandaria Classic** (Titanforged)

### NAG Integration:
RC-SpellFlash automatically detects and integrates with NAG version 6+ on all supported Classic versions. The integration uses NAG's core display APIs which are consistent across all versions.

## 🐛 Debug Mode

If you need to troubleshoot or see what spells are being flashed:

1. Open `RC-NAGBridge.lua`
2. Change line 7: `local DEBUG_MODE = false` to `local DEBUG_MODE = true`
3. Reload your UI (`/reload`)
4. Watch chat for detailed debug messages

## 📝 Slash Commands

- `/rcspellflash` - Toggle addon on/off
- `/rcspellflash config` - Open configuration (if available)

## 🔌 API for Other Addons

Other addons can use RC-SpellFlash's API:

```lua
local SF = LibStub("RCSpellFlash")
if SF then
    -- Register your addon
    SF:RegisterAddon("YourAddonName")
    
    -- Flash a spell with custom color (R, G, B, A)
    SF:FlashSpell("YourAddonName", spellID, 1, 0, 0, 1)  -- Red flash
    
    -- Clear all flashes from your addon
    SF:ClearFlashes("YourAddonName")
end
```

## 🤝 Credits

- NAG integration by RC-SpellFlash Team
- Based on SpellFlash concept
- Compatible with NAG by Thumbs (wowinterface.com/downloads/info26546)

## 📄 License

Free to use and modify. Give credit where it's due.

## 🆘 Support

For issues or questions:
1. Check debug mode output
2. Verify NAG is installed and working
3. Make sure you're using compatible versions

---

**Version:** 1.1.0  
**Last Updated:** March 2026
