# Mama v2.0.0 - WoW Forever edition

Rewritten for WoW Forever, standalone: no MoLib or other dependencies anymore. All changes since v1.24.0 (v1.25.0 to v1.30.x were test builds of this, now marked pre-release):

**Team setup**
- One account-wide team token, with slots and recent characters per faction (no cross-faction grouping in Forever); slot 1 of each faction is the master
- Auto invite announces to known teammates and retries until they answer; Alt+right-click completes the team
- Messages signed with HMAC-SHA256 with replay protection (all windows need the same version)
- `/mama disable` (or key binding, Ctrl+middle-click on the status window) turns Mama off for one character

**Follow**
- Train mode back, with key bindings; follow, assist and the MAMA macro (no longer floods on the lead)
- The lead is warned when a window loses follow out of combat (stuck)

**Dialogs mirrored from the lead**
- Gossip options, quests taken and returned, quest rewards and flight paths are picked on the other windows when their own dialog offers the same choice
- Hold Shift/Ctrl/Alt to skip quest auto accept and read the quest first

**Loot**
- Free-for-all loot once the whole team is grouped, group loot while strangers are in the group; manual changes stick

**Professions and trades**
- Team professions shared and shown in the status window
- Trading with a teammate fills in the mats they use (cloth, leather, ore, bars, herbs, enchanting mats...), per category options; "Mama: give mats" button on the trade window

**Status and chat**
- Status window shows free bag slots and the team's gold
- Whispers to the other windows are forwarded to the lead, GM whispers tagged with a raid warning

**Options and misc**
- Options with a Trade sub page, and "Send settings to team"
- `/mama bug` to copy the debug log for bug reports
- Options page shows the current settings on first open (was blank or unchecked until reopened)

[Full commit log since v1.24.0](https://github.com/mooreatv/MAMA-multiboxing/compare/v1.24.0...v2.0.0)
