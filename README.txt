RC-SpellFlash for Mists of Pandaria Classic
=========================================

Version: 8.0.5-MoP

Description:
RC-SpellFlash is a library addon that provides visual indicators (flashing effects) on action buttons.
This helps you identify which spells or abilities to use, particularly useful for rotation helper addons.

Installation:
1. Extract the RC-SpellFlash folder to your World of Warcraft/_classic_/Interface/AddOns/ directory
2. Restart WoW or reload UI (/reload)
3. RC-SpellFlash will load automatically

Usage:
RC-SpellFlash is a library - it's meant to be used by other addons (like rotation helpers).
However, you can configure it with these slash commands:

/rcf          - Open options menu
/rcf on       - Enable RC-SpellFlash
/rcf off      - Disable RC-SpellFlash  
/rcf clear    - Clear all current flashes
/rcf combat   - Toggle combat-only mode

You can also access the options menu through the game's Interface > AddOns menu.

For Addon Developers:
See API.txt for detailed information on how to integrate RC-SpellFlash into your addon.

Supported Action Bar Addons:
- Blizzard default UI
- Bartender4
- Dominos
- ElvUI

Features:
- Full graphical options menu (access via /rcf or Interface > AddOns)
- Lightweight and efficient
- Works with all major action bar addons
- Customizable colors and brightness
- Color presets (Yellow, Red, Green, Blue, Purple, Orange)
- Combat-only mode option
- Multiple addons can use it simultaneously

Compatibility:
Built specifically for Mists of Pandaria Classic (5.4.x)
Interface version: 50400

Notes:
- This is a library addon - other addons use RC-SpellFlash to show you which buttons to press
- Configure settings via /rcf or Interface > AddOns > RC-SpellFlash

Credits:
Original RC-SpellFlash by RC-SpellFlash Team
MoP Classic compatibility by community contribution

License:
All Rights Reserved
