<img src="https://raw.githubusercontent.com/mooreatv/Mama/master/Mama_icon.png" height=64 width=64 align=right>

## About M.A.M.A. Multiboxing

MAMA is now Mama-forever: Multiboxing helper for **WoW Forever** (the new beta client, interface 16xxx). One standalone addon, no libraries and
no other addon needed. It is the successor of MAMA + DynamicBoxer + MoLib, rewritten for Forever only.

It lets all your windows of the same team:

- find each other and form a group automatically (one-time setup per window),
- **follow and assist** whoever is the lead, with one key or one macro,
- **follow in a train** ordered by team slot, with one key,
- share, accept and abandon **quests** together,
- **sell** the same junk at every vendor (a team wide sell list, greys optional),
- be managed from a small **team status window** (invite, disband, party/raid, target, ...),
- mark a member **away** for a while (Alt+Left click its status window row, or `/mama away`): no invites, follow
  alerts or quest/dialog sync, still trades and forwards whispers.

Names in Forever are `First Last` (with a space) and there is no realm part: Mama-forever treats them as opaque names.

## Install

Copy the `Mama` folder to
`World of Warcraft\_classic_beta_\Interface\AddOns\` (or run `install.bat` from a clone, adjust the path in it if
needed), then **restart the game** (a `/reload` isn't enough the first time, key bindings are only read at startup).

## One-time setup

Each window gets a slot number (1 = the master window) and the team **token**, once per character. Two ways:

**A. First window alone, then the others (all accounts on one PC, recommended).** No copy/paste.

1. Start only the first window. A good time to also set what every window will share: max foreground and background
   frame rates, graphics settings, UI scale...
2. `/mama s 1` (Enter to close the token dialog), then `/reload` or exit the game: the token is saved for every
   account of this PC (and the settings are saved).
3. Start and log in the other windows: each picks up the token and asks for its slot number, prefilled with a guess;
   type it if needed and Enter. A guess that turns out to be another online member's slot moves to the next free one.
   Escape skips it until the next `/reload` (`/mama s 0` stops asking for that character).

**B. All windows at once (or windows on several PCs):** copy/paste the token.

1. In the first window: `/mama s 1`. A dialog shows the team token: press Ctrl-C, then Enter.
2. In the second window: `/mama s 2`, press Ctrl-V in the dialog and Enter ("token accepted").
3. Same for the third window with `/mama s 3`, and so on (up to 40).

Either way the windows then announce themselves to each other, the status window appears, and slot 1 invites
everybody (switching to a raid above 5 characters).

The token is saved, so you don't redo this at the next login. Team messages are signed with the token's secret, so
only messages signed with that secret are accepted as team commands. Characters that exchange the token
are added to the trusted team and their group invites are auto accepted. `/mama token` shows it again.
`/mama token new` (slot 1) makes a new secret: only for a leaked token or a separate team, as every other window then
needs the new one. `/mama team add [Full Name]` can separately trust a name for auto-accepting
that character's group invites; it does not pair that character, assign it a slot, or give it the token needed to
exchange team messages. Each participating window still needs its own `/mama s N` setup and the shared token.

Each character remembers its own team (slot, token, teammates): switching between teams played on the same
accounts picks up the right one at login.

**Log in slot 1 last** (when you can't log in all windows at once). Slot 1 invites its team as soon as it logs in, and
the others accept automatically. If slot 1 logs in first, those invites find nobody, and the group only forms once the
other windows' announces reach slot 1, which can take minutes when the server's chat lags. If that happens, left click
the status window on slot 1 (or `/mama invite`, or the *Invite team* key) once everyone is logged in.

**New team or new master** (other characters, or another character as slot 1): on the new slot 1, `/mama s 1` and copy
the token it shows (same secret, this character as master). On each other window, `/mama s N` (or
`/mama token`, or Ctrl+Right on the status window) and paste it in the dialog, which names the current master (Escape
keeps it); `/mama token <paste>` works too. Pasting a token makes that window forget the previous team and talk to the
new master right away.

**New characters may need one manual invite.** Windows find each other by whispering names they already know (slot 1
from the token, characters recorded in earlier sessions). Addon messages only work by whisper, party/raid or guild (not
say/yell), so a character never seen before, or the first team on another faction, can't be found: invite it once by
hand (or have both in the same guild). Once grouped they record each other and it's automatic from then on.


## Using it

### Follow and assist

The "lead" is the group leader by default. `/mama lead` on a window makes **that** window the lead for the whole team
(and the group leader promotes it), `/mama lead auto` goes back to following the group leader.

Follow and assist are protected actions that must come from a key press or your own macro, so there are two ways:

- **Key bindings** (Game Menu > Key Bindings > Mama-forever): *Follow + assist lead*, *Assist lead*,
  *Follow train + assist lead* (each slot follows the previous slot; the lead stops following),
  *Make me lead*, *Invite team*, *Disband team*, *Identify slot*.
- **The MAMA macro**: Mama-forever creates a per character macro called `MAMA` with a starter for your class
  (follow and assist the lead, attack, send the pet, cast a basic spell) and keeps its `/follow` and `/assist` lines
  pointed at the current lead. Open the macro window (`/macro`, character tab), drag `MAMA` to an action bar once
  and use it. Edit it freely (spell, icon, extra lines): only the `/follow` and `/assist` lines are updated.
  Until you edit it, the starter picks up a better spell when you learn it (Judgement for paladins, Serpent Sting
  for hunters, Charge out of combat and Rend for warriors).
  `/mama macro reset` puts the class starter back, `/mama macro off` stops managing it. The account wide `MAMA` macro
  of older versions is deleted.

### Quests

- Quests you accept are shared with the group, and shared quests are accepted automatically on the other windows.
- Hold Shift, Ctrl or Alt while opening a quest giver (or clicking a quest) to skip auto accept and read it first.
- Abandoning a quest on one window abandons it on the others (never a completed quest).
- Talking to an NPC whose dialog has only one option and no quest (most vendors and trainers) picks that option: you go
  straight to the vendor window. Same for an NPC with only one quest to pick up and nothing else: the quest opens (and
  gets auto accepted when grouped), or with only one completed quest to turn in: it opens for turn in. Hold Shift, Ctrl
  or Alt while opening the NPC to see the dialog; `/mama gossip off` turns it off.
- The lead's dialog choices (gossip options, quests, flight paths) are made on the other windows too, and so are the
  lead's clicks on popups (spirit healer, accept resurrect or summon, release spirit...) on the windows showing the
  same popup. Never for deleting items, logging out or quitting. `/mama dialog off` turns it off.

### Professions and trading mats

Each window tells the team its professions (`/mama profs` lists them, `/mama profs sync` asks everyone again; also in
the status window row tooltips). Opening a trade with a team member puts the mats they use in the trade window (6
stacks per trade, trade again for more); you still click Trade. Mats you could use yourself stay with you (a tailor
keeps their cloth, unless the other tailor is better); the "Mama: give mats" button above the trade window gives them
anyway (e.g. a blacksmith's spare bars to an engineer):

| Mats | Go to |
|---|---|
| cloth | tailor |
| leather and hides | leatherworker |
| ore | miner (to smelt) |
| bars and stones | blacksmith or engineer |
| herbs | alchemist |
| dusts, essences and shards, BoE greens (to disenchant) | enchanter |
| engineering parts | engineer |
| recipes and patterns | whoever has that profession |
| raw meat and fish | cook (off by default) |

Pick the kinds in Options > AddOns > Mama-forever > Trade (or `/mama trade list`, `/mama trade greens off`);
`/mama trade off` turns the auto fill off (the button still works). "Send settings to team" (on both options pages)
copies this window's options and trade kinds to the rest of the group.

### Selling at vendors

Opening a merchant sells the items on your **sell list**, and every grey item if you tick that box (hold Shift, Ctrl
or Alt while opening it to sell nothing). Edit the list with `/mama vendor` or the "Mama: sell list" button above the
merchant window: drop items from your bags on it, Ctrl+Right click them in your bags while it's open, or type an
item's name or ID in its box; the X on a row removes it. Every addition, removal and the greys box are sent to the team members online, so all windows sell the
same things; "Send list to team" replaces their whole list with yours (e.g. for a window that was offline).
`/mama vendor add|remove <item>`, `greys [on|off]`, `list`, `sync` and `sell` do the same from the chat line.

Bags full? Open a trade with the team member who has the most free bag slots (status window) and click the "Mama:
vendor items" button above the trade window: it puts 6 of the items you'd sell (sell list and greys, partial stacks
last) in the trade, for them to sell at the next merchant.

**Auto repair** (Options, off by default: early on, the money is better spent on training than on repairing gear
you'll soon replace): after selling, a merchant that can repair fixes all your gear, if you have the money.

### Alerts to the lead

- **Follow broken**: when a window stops following out of combat (not in a fight, where that's normal) and the lead
  then gets out of follow range (stuck behind a tree or a wall), the lead's window gets a raid warning and a sound.
  Same when a follow key or the MAMA macro doesn't start following out of combat (too far, out of sight...).
  Only for windows that were near the lead in the last 2 minutes, and never while the lead is dead, a ghost or on a
  flight, nor right after it came back to life, released, landed or went through a loading screen.
- **Whispers**: whispers from players outside the team to the other windows are shown in the lead's window (click the
  name to answer). GM whispers are tagged `<GM>` with a raid warning and the GM sound. If the whisper can't be read
  (chat lockdown), the lead is still told to look at that window.

Both are on by default (Options > Alerts to the lead).

### Status window

One row per slot. White is this window, green is in the group, yellow is online but not grouped, grey is not seen yet,
blue grey is away (left out of the title count), `*` marks the lead. The number right of each name is its free bag slots (orange under 5, red when full). The bottom
line is the team's gold; hover it for the gold and bag slots of every character of this faction you've played with
Mama, alts included (last known values). Hover the title for all the shortcuts:

| Click | Action |
|---|---|
| Left | invite the team |
| Middle | disband (leader uninvites the team, others leave) |
| Right | options |
| Shift+Left / Shift+Right | toggle party/raid / toggle compact view |
| Shift+Middle | show the big slot number, class and name |
| Ctrl+Left / Ctrl+Right | toggle auto invite / show or paste the token |
| Alt+Left | resend our info to the team |
| Ctrl+Middle | turn Mama off/on for this character (see below) |
| Alt+Right | mark the team complete (forget slots that aren't here) |
| Mouse wheel / drag title | resize / move |

On a row: left click targets the character (or invites it when not grouped), right click opens its unit menu,
Alt+Left marks it away or back (see below).

**Away team members** (one doing its own thing for a while, in the group or not): Alt+Left click its row,
`/mama away 3 4` (slots) or `/mama away Full Name`, and `/mama back 3|Full Name|all`. It's shown on every window and
remembered until it's back. An away member isn't invited (clicking its row still does), doesn't keep the team from
being complete (free for all loot, `/mama complete` keeps its slot), sends no follow alerts, and its window leaves
quests (accept, share, abandon) and the lead's dialogs and popups alone. Trade fill, gold and bag stats and whisper
forwarding keep working.

**Turning Mama off for one character** (e.g. one that is sometimes part of another team): `/mama disable`, the
*Turn Mama off/on* key binding or Ctrl+Middle click on the status window. That character then sends and reads no
team messages and does no team automation (auto accept invites/quests, quest sharing, loot, trade fill, vendor
selling, alerts); the status window title shows "disabled" in red. Its slot and token setup are kept, and it is
remembered for that character until `/mama enable` turns it back on.

## Commands and options

`/mama help` lists everything: `s`, `token`, `lead`, `team`, `away`, `back`, `invite`, `disband`, `raid`, `autoinvite`, `status`,
`macro`, `quest`, `dialog`, `gossip`, `profs`, `trade`, `vendor`, `ui`, `enable`, `disable`, `identify`, `options`, `complete`, `debug`, `bug` (copyable log), `clearlog`. The options panel is in Game Menu > Options > AddOns > Mama-forever
(`/mama options`): auto accept/share quests, abandon everywhere, auto accept team invites, auto invite, auto raid,
mirror the lead's dialog choices, skip single option dialogs, free-for-all loot, auto fill trades, auto repair, MAMA macro, follow broken warning, whisper
forwarding, status window, slot display at login, debug.

## Not included (compared to the old addons)

No ISBoxer team discovery (Even if it should still work, but use [WowOpenBox](https://github.com/WowOpenBox/WoWOpenBox#wowopenbox) instead - open source and designed to be safe and compliant), no EMA integration, no support for other WoW versions (yet).

## Development

- Releases are built by the GitHub action in `.github/workflows` using
  [BigWigsMods/packager](https://github.com/BigWigsMods/packager) and `pkgmeta.yaml` when a tag is pushed.


- Opensource license (so if the current author gets hit by a bus, anyone else can pick it up and/or make improvements)

- Formatting (for ref on my pc; lua-format.exe needs the msys64 ucrt64 DLLs on PATH)
```powershell
$env:PATH = "C:\msys64\ucrt64\bin;" + $env:PATH
Get-ChildItem -Filter *.lua -Recurse | ForEach-Object {  C:\Users\l\AppData\Roaming\luarocks\bin\lua-format.exe -c  .\luaformat.cfg -i $_.FullName }
```

## More info

- Get the binary release using curse/twitch/overwolf/wowup/wago... clients https://www.curseforge.com/wow/addons/mama-multiboxing

- Source code is https://github.com/mooreatv/MAMA-multiboxing

- The older version, pre WoW forever rewrite, that used MoLib and DynamicBoxer can be found at https://github.com/mooreatv/MAMA-multiboxing/tree/v1.24.0
