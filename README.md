# RC-SpellFlash - NAG Integration

Visual spell flash indicators with full NAG (Next Action Guide) integration support.

## ✨ Features

- **Multi-color spell flashing** - Different colors for different spell positions
- **Full NAG integration** - Automatically flashes spells recommended by NAG
- **Zero configuration** - Works out of the box when both addons are installed
- **Multi-version support** - Works on Retail (Midnight), MoP Classic, Cata, Wrath, TBC Anniversary, Classic Era and WoW Forever

## 🎨 Color Coding

- **Yellow** - Primary spell (main rotation)
- **Cyan** - Left position spells (cooldowns)
- **Orange** - AOE/Defensive/Interrupt spells

## 🔧 Installation

1. Extract the RC-SpellFlash folder to your game's `Interface\AddOns\` folder (for example `World of Warcraft\_classic_\Interface\AddOns\`)
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


## Maintainer

Maintained by **Raw Card**.

### Tests

`pip install lupa && python3 tools/test_clients.py` loads the addon on a simulated copy of every client and class, feeds it a fake NAG and checks the recommended spell's button flashes (and no other), clicks every options control and runs every slash command. It runs on every push.

### Releasing

1. Update `## Version` in every `.toc` file and add the notes to the top of `CHANGELOG.md`.
2. On GitHub: **Releases** → **Draft a new release** → **Choose a tag** → type `v` plus the version (for example `v2.1.3`) → **Create new tag on publish** → **Publish release**.
3. The **Package and release** job builds the zip and uploads it to CurseForge (project `1422448`). It needs the `CF_API_KEY` secret.
