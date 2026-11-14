<img src="https://raw.githubusercontent.com/mooreatv/Mama/master/Mama_icon.png" height=64 width=64 align=right>

## About M.A.M.A. Multiboxing

MAMA is now Mama-forever: Multiboxing helper for **WoW Forever** (interface 16xxx), also supported on **retail**. One
standalone addon, no libraries and no other addon needed. It is the successor of MAMA + DynamicBoxer + MoLib,
rewritten for Forever.

It lets all your windows of the same team:

- find each other and form a group automatically (one-time setup: on one PC, just type a slot number per window),
- play as **one raid or several groups** (teams of more than 5: merge and split with one click or key),
- **follow and assist** whoever is the lead: one key (or macro) pressed in each window, follow + assist + opening
  spell,
- **follow in a train** ordered by team slot, with one key,
- share, accept and abandon **quests** together,
- **sell** the same junk at every vendor (a team wide sell list, greys optional),
- with **master loot**, give each item to the team member who uses it (quest items to whoever still needs them),
- be managed from a small **team status window** (invite, disband, party/raid, target, ...),
- mark a member **away** for a while (Alt+Left click its status window row, or `/mama away`): no invites, follow
  alerts or quest/dialog sync, still trades and forwards whispers.

Names in Forever are `First Last` (with a space) and there is no realm part: Mama-forever treats them as opaque names.
On retail, names are `Name-Realm`. What depends on the game edition (master loot, new character setup) is described
for Forever.

## Install

Install it with an addon manager: the [CurseForge](https://www.curseforge.com/wow/addons/mama-multiboxing) app,
[WowUp](https://wowup.io/) or [Wago](https://addons.wago.io/). Or download the zip from the
[GitHub releases](https://github.com/mooreatv/MAMA-multiboxing/releases) and extract it in
`World of Warcraft\_forever_\Interface\AddOns\` (`_retail_` for retail; it contains the `Mama` folder).

## One-time setup

Each character needs two things, once:

- a **slot** number: its place in the team. Slot 1 is the master window (it invites the others); 2, 3... set the
  follow train order.
- the team **token**: a shared secret made by slot 1, so your windows trust each other's messages (and nobody else's).

There are two ways to set them up.

**A. Recommended when all your accounts play on this PC: start with one window.** Nothing to copy or paste.

1. Start the game in **one window only** and log in the character that will be slot 1. (Also a good moment to set
   what every window shares on this PC: graphics settings, max foreground/background frame rates, UI scale...)
2. Type `/mama s 1`. A dialog shows the token: click its **Reload** button. That saves the token on this PC for all its
   WoW accounts (and saves your settings). Exiting the game works too.
3. Start the other windows and log in. Each one says "using the team token saved on this PC" and asks for its slot,
   with a suggested number: change it if needed, then Enter. If that slot already belongs to another team member who
   is online, the window picks the next free slot by itself and tells you (`/mama s N` changes it later).

Escape in that slot dialog skips it until the next `/reload` or login; `/mama s 0` on a character stops asking for it
(for a character that isn't part of the team).

**B. All windows already running, or windows on several PCs:** copy/paste the token.

1. In the first window: `/mama s 1`. A dialog shows the team token: press Ctrl-C, then Enter.
2. In the second window: `/mama s 2`, press Ctrl-V in the dialog and Enter ("token accepted").
3. Same for the third window with `/mama s 3`, and so on (up to 40).

Either way the windows then find each other, the status window appears, and slot 1 invites everybody (switching to
a raid above 5 characters, or in several groups: see Raid or groups below). New characters later: on a PC with a saved token, just log them in and answer the slot
dialog; otherwise `/mama s N` and paste the token (`/mama token` on slot 1 shows it again).

The token is saved, so you don't redo this at the next login. Team messages are signed with the token's secret, so
only messages signed with that secret are accepted as team commands. Characters that exchange the token
are added to the trusted team and their group invites are auto accepted. `/mama token` shows it again.
`/mama token new` (slot 1) makes a new secret: only for a leaked token or a separate team, as every other window then
needs the new one. `/mama team add [Full Name]` can separately trust a name for auto-accepting
that character's group invites; it does not pair that character, assign it a slot, or give it the token needed to
exchange team messages. Each participating window still needs its own `/mama s N` setup and the shared token.

Each character remembers its own team (slot, token, teammates): switching between teams played on the same
accounts picks up the right one at login. Forever's rulesets (Normal, PvP, RP, RP-PvP, Hardcore) are separate worlds:
each has its own team, token saved on the PC, gold and professions.

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

Macros and key bindings can't change in combat: in a party, they name `party1` (the group leader on every other
window), so a new group leader is followed and assisted right away, even mid-fight (on the new leader's own window,
they only clear when combat ends). The follow key stops following a dead lead but keeps assisting it.

Nothing follows by itself: press the key (or the MAMA macro) in each window that should follow (one press per window:
key broadcasting is not allowed). Older MAMA versions could make the other windows follow from the lead's window. The game no longer
allows that: follow and assist only work from a key press in that window.

Follow and assist are protected actions that must come from a key press or your own macro, so there are two ways:

- **Key bindings** (Game Menu > Key Bindings > Mama-forever): *Follow + assist lead*, *Assist lead*,
  *Follow train + assist lead* (each slot follows the previous slot; the lead stops following),
  *Make me lead*, *Invite team*, *Team is complete*, *Merge groups into a raid / split again*, *Disband team*,
  *Identify slot*, *Turn Mama off/on for this character*. New characters get Alt-F (follow + assist),
  Alt-T (train) and Alt-L (make me lead) when these keys are free (see New characters below).
- **The MAMA macro**: Mama-forever creates a per character macro called `MAMA` with a starter for your class
  (follow and assist the lead, attack, send the pet, cast a basic spell) and keeps its `/follow` and `/assist` lines
  pointed at the current lead. Open the macro window (`/macro`, character tab), drag `MAMA` to an action bar once
  and use it. Edit it freely (spell, icon, extra lines): only the `/follow` and `/assist` lines are updated.
  Until you edit it, the starter picks up a better spell when you learn it (Judgement for paladins, Serpent Sting
  for hunters, Shadow Word: Pain for priests, Charge out of combat and Rend for warriors).
  `/mama macro reset` puts the class starter back, `/mama macro off` stops managing it. The account wide `MAMA` macro
  of older versions is deleted.

### Raid or groups

A team of more than 5 is one raid by default ("Auto convert to raid" in the options). With that option off, the team
is split in groups by slot, of the "Group size" next to it (2 to 5, `/mama groups N`; with 3: slots 1-3, 4-6...), each
invited by its first slot, which also leads it until you pick another lead.

Either way you can merge the groups into one raid and split them again for the session: Shift+Left click on the
status window, its raid/split button, `/mama merge` and `/mama split` (`/mama raid` toggles), or the *Merge groups
into a raid / split again* key binding. Each window leaves and joins by itself, so the key binding pressed on all
windows at once is instant; done on slot 1 only, the other groups are told by whisper, which can take a minute or two.

### New characters

A level 1 character's first login with Mama sets up, once: action bars 2-5 shown, A/D turn and Q/E strafe,
Alt-F/Alt-T/Alt-L for the follow, train and make me lead keys, `.` for interact with target, autoloot,
the `MAMA` macro on button 1 (what was there moves to the button above it) and the Classic Edit Mode layout (the rest
of the Modern choice, like high resolution characters, is kept). Each one only if it is still at the new character
default: bars you turned off, your own key bindings or a custom layout are left alone. `/mama setup off` turns it off,
`/mama setup now` does it on the current character.

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
copies this window's options, trade kinds and status window position and size to the other windows (those in the
group or heard from).

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

### Master loot

With "Master loot auto distribution" and "Set team loot" on (the default, see Options), the full team gets master loot
by the lead (or pick master looter in the group menu yourself). `/mama loot off` makes it free for all from the next
time the team gets grouped (the current group keeps its loot method: change it in the group menu). The threshold goes
down to greys (once: raise it again if you want), and the master looter's window gives each item to the team member
who uses it:

- quest items to whoever still needs them: the one furthest behind in level and xp, or among those about level
  with it the one closest to finishing the quest (so a quest gets done instead of half done on two characters), the
  looter on a tie; quest items that drop once per player (heads...): the looter keeps its copy and the lead's window gets one raid
  warning listing who must loot theirs,
- mats and recipes to the best profession holder (same kinds as trades),
- armor to the classes that wear that type (leather to the rogue or druid...), weapons to the classes that can use
  them, taking turns; greens nobody uses to the enchanter,
- greys, the sell list and everything else to the most free bag slots.

Soulbound items open a picker next to the loot window instead, the suggestion first (another candidate, or the
enchanter to disenchant it); clicking an item in the loot window opens it too. Hold Shift, Ctrl or Alt while opening
the loot to give it all by hand. Turn it off with "Master loot auto distribution" (Options) or `/mama loot off`.

### Alerts to the lead

- **Follow broken**: when a window stops following out of combat (not in a fight, where that's normal) and the lead
  then gets out of follow range (stuck behind a tree or a wall), the lead's window gets a raid warning and a sound.
  Same when a follow key or the MAMA macro doesn't start following out of combat (too far, out of sight...): not
  while the lead is fighting, while casting, or in the few seconds after a fight.
  Only for windows that were near the lead in the last 2 minutes, and never while the lead is dead, a ghost or on a
  flight, nor right after it came back to life, released, landed or went through a loading screen.
- **Missed quest**: when most of the team accepts a quest within a few seconds but a window doesn't get it (the
  quest can't be shared and has to be accepted at the NPC, or the share didn't reach it: too far, quest log full...),
  the lead's window gets a raid warning and a sound naming the window and the quest. Not when only one window took
  the quest (class quests...), for a window that already completed it or skipped it by holding a modifier at the NPC,
  nor for away windows. Turn it off with "Warn when a quest is missed" (Options).
- **Whispers**: whispers from players outside the team to the other windows are shown in the lead's window (click the
  name to answer). GM whispers are tagged `<GM>` with a raid warning and the GM sound. If the whisper can't be read
  (chat lockdown), the lead is still told to look at that window.

Both are on by default (Options > Alerts to the lead).

### Status window

One row per slot. White is this window, green is in the group, yellow is online but not grouped, grey is not seen yet,
blue grey is away (left out of the title count), `*` marks the lead. The number right of each name is its free bag slots (orange under 5, red when full). The bottom
line is the team's gold; hover it for the gold and bag slots of every character of this faction you've played with
Mama, alts included (last known values), then the gold of all the team's accounts per faction and in total (in compact
view, hover the title for it). Click the `?` on the title (or Alt+Middle, or `/mama`) for the help window with all the shortcuts:

| Click | Action |
|---|---|
| Left | invite the team |
| Middle | disband (leader uninvites the team, others leave) |
| Right | options |
| Shift+Left / Shift+Right | merge the groups into a raid or split again (party/raid for a team of one group) / toggle compact view (also in the options, sent with the settings) |
| Shift+Middle | show the big slot number, class and name |
| Ctrl+Left / Ctrl+Right | toggle auto invite / show or paste the token |
| Alt+Left | resend our info to the team |
| Ctrl+Middle | turn Mama off/on for this character (see below) |
| Alt+Right | mark the team complete (forget slots that aren't here) |
| Alt+Middle | show the mouse shortcuts |
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

`/mama` (or `/mama help`, or the Help button of the options page) opens the help window: the status window's mouse
shortcuts, the key bindings with their current keys, and every command by topic: `s`, `token`, `team`, `complete`,
`away`, `back`, `status`, `invite`, `autoinvite`, `disband`, `raid`, `merge`, `split`, `groups`, `lead`, `macro`,
`quest`, `dialog`, `gossip`, `setup`, `loot`, `trade`, `vendor`, `profs`, `ui`, `identify`, `options`, `enable`,
`disable`, `bug` (copyable log), `clearlog`, `debug`. Its buttons open the options, the key bindings and the log.
The options panel is in Game Menu > Options > AddOns > Mama-forever (`/mama options`; hover an option
for what it does): auto accept team invites, auto invite, auto raid and group size, team loot (free for all or
master), master loot auto distribution, auto accept/share quests, abandon everywhere, mirror the lead's dialog
choices, skip single option dialogs, MAMA macro, auto fill trades, auto repair, follow broken warning, missed quest
warning, whisper forwarding, status window, slot display at login, compact status window.

## Reporting a problem

`/mama bug` shows Mama's recent messages, debug details included, in a window: select the end of it (click where to
start, Shift-click at the end; or Ctrl+A for all), Ctrl+C, and paste it in a
[GitHub issue](https://github.com/mooreatv/MAMA-multiboxing/issues) with what you expected. The log only keeps the
last 100 lines: copy it right after the problem (ideally from the window it happened on and from slot 1), or
`/mama clearlog` and reproduce it first.

## Not included (compared to the old addons)

No ISBoxer team discovery (Even if it should still work, but use [WowOpenBox](https://github.com/WowOpenBox/WoWOpenBox#wowopenbox) instead - open source and designed to be safe and compliant), no EMA integration, no support for the WoW versions other than Forever and retail (yet).

## Development

- From a clone, `install.bat` copies the `Mama` folder to the game's AddOns folder (adjust the path in it if needed).

- Releases are built by the GitHub action in `.github/workflows` using
  [BigWigsMods/packager](https://github.com/BigWigsMods/packager) and `pkgmeta.yaml` when a tag is pushed.


- Opensource license (so if the current author gets hit by a bus, anyone else can pick it up and/or make improvements)

- Formatting and lint: [lua-format](https://github.com/Koihik/LuaFormatter) with `luaformat.cfg` and
  [luacheck](https://github.com/lunarmodules/luacheck) with `Mama/.luacheckrc`, from the repository root:
```sh
lua-format -c luaformat.cfg -i Mama/*.lua
luacheck Mama --config Mama/.luacheckrc
```

## More info

- CurseForge page: https://www.curseforge.com/wow/addons/mama-multiboxing

- Source code is https://github.com/mooreatv/MAMA-multiboxing

- The older version, pre WoW forever rewrite, that used MoLib and DynamicBoxer can be found at https://github.com/mooreatv/MAMA-multiboxing/tree/v1.24.0
