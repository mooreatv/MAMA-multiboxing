# Mama-forever status (the `forever` edition of M.A.M.A.) â€” last updated 2026-10-06

Goal was: merge MoLib + DynamicBoxer + MAMA-multiboxing (sibling dirs in `moorea\`) into one standalone addon
for WoW Forever (beta, believed mostly retail-API based). No library, no DBox dependency, no other WoW version support.
The probe notes below are a chronological record; later status sections supersede older "unverified" notes.

## Decisions
- Drop ISBoxer team discovery (only own slot/roster protocol, i.e. DBox's no-ISBoxer path), ISBoxerPatches.lua.
- Drop EMA/Jamba integration entirely (incl. "set EMA master").
- Drop DBoxClassic/DBoxLegacy, Classic/Mists tocs, WOW_PROJECT_* branches, old changelogs.
- Drop MoLibAH, MoLibConv, Realms.lua (34KB realm DB), lib loader/versioning.
- Forever has mega realms: hidden home realm, everyone on the same ruleset is on the same realm, but on
  different *layers* until grouped. So realm handling mostly goes away; layers matter (teammates may be
  unreachable/uninvitable by name until grouped).
- Character names may contain spaces ("first last"): treat names as opaque strings, never split on whitespace
  or assume single token; one `MF:FullName(unit)` helper; use delimiters in addon messages that can't be in names.
- Single namespace `MF`, SavedVariables `MamaForeverSaved` (merge DBox + Mama settings). `/mama` only (no `/dbox` alias).
- License: unchanged (LGPLv3).
- This IS the original MAMA-multiboxing repo (kept for stars, CurseForge/Wago/WoWI ids and secrets). The Forever
  rewrite replaced the old addon on `master` (PR #21); old classic/retail/MoP code is only in git history.

## Phase 0 - Probe (DONE)
`Probe/MamaForeverProbe/` (not packaged). `/mf probe` dumps to chat + SavedVariables:
1. Interface number (`select(4, GetBuildInfo())`), existing `C_*` namespaces.
2. `UnitName`, `UnitFullName`, `GetUnitName(unit,true)`, `GetRealmName`, `GetNormalizedRealmName`, `Ambiguate`
   for spaced and non-spaced names; hidden realm suffix format?
3. Addon messages: `C_ChatInfo.SendAddonMessage` WHISPER between chars on different layers; fallbacks
   (custom CHANNEL, GUILD, PARTY, `BNSendGameData`). Names in `CHAT_MSG_ADDON` sender.
4. `InviteUnit` / `C_PartyInfo.InviteUnit` by name across layers; layer merge after accept; `PARTY_INVITE_REQUEST` names.
5. Group APIs: `ConvertToRaid`, loot method, `LeaveParty`, `GetNumGroupMembers`.
6. Protected-ness of `FollowUnit`/`AssistUnit`/`TargetUnit`; secure buttons and `/click` still OK?
7. Mount (`C_MountJournal`), quest share/abandon (`C_QuestLog`), taxi (`TakeTaxiNode`/`C_TaxiMap`).
8. UI: `Settings` panel API, `BackdropTemplate`.

## Phase 1 - Scaffold (DONE)
`Mama/Mama.toc` (Interface 16001, no deps), `Mama.lua` (namespace `MF`, events, saved vars, commands, message handlers),
`Team.lua` (roster/lead), `Comm.lua` (pairing + signed addon-message protocol), `Actions.lua` (follow/assist macro + secure buttons),
`Status.lua` (team status window + identify overlay), `Options.lua` (Settings panel), `Dialogs.lua` (token dialog),
`Bug.lua` (copyable log window), `UI.lua` (keybinding labels), `Bindings.xml` (CLICK bindings).
`.luacheckrc`, `luaformat.cfg`, `pkgmeta.yaml`, `.github/workflows/packaging.yaml` all adapted.

## Phase 2 - Port (DONE)
- MoLib: only used bits (logging/debug, slash plumbing, saved vars, timers, small UI widgets/options builder).
- DynamicBoxer: team/slot sync over addon messages, auto invite, raid conversion, options UI, status window.
- MAMA: lead/assist/follow/train, quest share+abandon, auto-accept, loot FFA.
- Signed token-based pairing protocol: `I;slot;name;flag`, `A;questID`, `L;name`, `Z;count` messages.
- Per-faction slot maps and candidate history (account-wide token, per-faction slots).
- Guild broadcast channel (GUILD addon messages) for extra reach.
- Retry/announce loop for offline characters until someone responds.
- Cross-home-realm whisper support (different realm IDs confirmed working).

## Phase 3 - Test (DONE)
- luacheck config in `Mama/.luacheckrc` (globals, read_globals for modern C_* APIs).
- luaformat config in `Mama-forever/luaformat.cfg` (indent 2, column limit 120).
  Run (PowerShell, repo root): `$env:PATH = "C:\msys64\ucrt64\bin;" + $env:PATH; & "$env:APPDATA\luarocks\bin\lua-format.exe" -c luaformat.cfg -i Mama\X.lua`
  (lua-format.exe needs the msys64 ucrt64 runtime DLLs; Git's mingw64 ones are the wrong version).
- In-game testing done on 2-3 clients: team sync, invite, raid convert, lead/assist/follow, quest share,
  options UI, layer behavior, taxi. At that stage, mount sync and `C_PartyInfo.UninviteUnit` edge cases remained unverified.

## Phase 4 - Release (DONE)
- README.md (Forever-only scope + credits to MoLib/DynamicBoxer).
- Packaging: BigWigsMods/packager@v2 via `.github/workflows/packaging.yaml` on tag push.
- `pkgmeta.yaml` (`package-as: Mama`, `move-folders: Mama/Mama: Mama`, ignores Probe/PLAN/README/install.bat).
- `Mama.toc` carries Curse 334197, Wago 7nGvmDKx, WoWI 26337; secrets CF_API_KEY/WAGO_API_TOKEN/WOWI_API_TOKEN on repo.
- `install.bat` copies `Mama\` to the beta AddOns folder (`_classic_beta_`).
- Github action for tag -> release worked fine.
- Addon shows up on curseforge and wowup/github.
- Localization not yet done (English only).

## Phase 0 findings (client 1.60.1 build 70205, Interface 16001, WOW_PROJECT_ID=18; beta realm "Classic Beta PvE 2")
- TOC must use `## Interface: 16001` or the addon will not load at all (out-of-date checkbox doesn't help).
- Names: `UnitName(u)` returns TWO values: first name, LAST name (e.g. "Han", "Jaconelli") - NOT name, realm.
  `GetUnitName(u, true/false)` returns "Han Jaconelli". No realm suffix anywhere (party member, addon msg sender, system msgs).
  `Ambiguate` and `strsplit("-")` are no-ops. So the canonical identity is the full "First Last" string; no realm handling needed.
  GUID = Player-<realmID 4620>-<id>. GetRealmName has spaces ("Classic Beta PvE 2").
- Addon messages: PARTY works (sender "Pri Cuthbridge"); RAID while in a party arrives as channel PARTY. WHISPER send returned true,0
  (receipt on the other client not yet verified; only 1 savedvars file collected). CHAT_MSG_ADDON args: prefix,text,channel,sender,target,...
- Invite of "Pri Cuthbridge" by full name works; group loot set automatically on group creation.
- IMPORTANT: the Forever client is a MODERN retail-based client (modern C_* namespaced APIs, Settings API, C_GossipInfo, C_AddOns), not an older Classic one. Use modern APIs and do not add legacy Classic fallbacks (e.g. SelectGossipOption, GetGossipOptions).
- Protected (ADDON_ACTION_FORBIDDEN): FollowUnit, AssistUnit. TargetUnit allowed out of combat. C_PartyInfo.InviteUnit(self) silent no-op.
- Globals MISSING (use namespaced): InviteUnit, ConvertToRaid, ConvertToParty, SetLootMethod, LeaveParty, GetLootMethod, ShareQuest,
  C_QuestLog.ShareQuest, InterfaceOptions_AddCategory, GetAddOnMetadata, IsAddOnLoaded, UnitInPhase, C_Seasons, C_ChatInfo.GetAddonMessageThrottle.
- Present: C_PartyInfo.{InviteUnit,ConvertToRaid,ConvertToParty,SetLootMethod,LeaveParty,PromoteToLeader,UninviteUnit,GetLootMethod(returns 3,nil,nil)},
  C_AddOns, Settings.RegisterCanvasLayoutCategory, QuestLogPushQuest, C_QuestLog.*, TakeTaxiNode/NumTaxiNodes + C_TaxiMap, C_MountJournal, SecureCmdOptionParse,
  RegisterStateDriver, BackdropTemplateMixin, C_Timer, BNSendGameData.
- Still unverified: WHISPER addon-message delivery, layers (both chars probably on same layer), raid conversion, quest share, taxi, mount, /click on secure buttons.
- Second client confirms: WHISPER addon message delivered cross-client by full name ("Han Jaconelli" as sender and target, no realm). Same layer only.
  PARTY_INVITE_REQUEST arg1 = inviter full name "Han Jaconelli" (arg7 = inviter GUID); also fires CHAT_MSG_SYSTEM with a |Hplayer:Han Jaconelli|h link
  (player link names contain spaces: don't parse with %S+). Normal chat events carry the full name too, plus GUID at arg12.
- SendAddonMessage return codes seen: PARTY/RAID ok(0); GUILD=10, INSTANCE_CHAT=5, SAY/YELL=4 (not available/valid here).
- Still unverified: different-layer behavior (WHISPER/invite), raid conversion, quest share, taxi, mount, secure /click.
- Third client (account 676966#5): realm "Classic Beta PvE" (ID 4618, GUID Player-4618-...), i.e. a DIFFERENT home realm than clients 1-2 (4620).
  A non-grouped cross-home-realm WHISPER addon message by full name ("Han Jaconelli") was delivered, sender shown without realm.
  Still unknown: whether that character was on a different layer; invite across home realms.
- Secure buttons (SecureActionButtonTemplate, type=macro, macrotext "/follow party1" | "/follow Han Jaconelli" | "/assist ..."):
  * `/click Button` from a macro: PreClick fires but the action does NOT happen (even /target; type=target too). Reported to WoW UI devs; cause unknown.
  * Same buttons bound via Bindings.xml `CLICK <Button>:LeftButton` and pressed via KEYBIND: WORKS (follow lead confirmed). Matches old Mama CurseForge issue #4.
  * Typing /follow "First Last" and /assist by hand works.
  => Design: team follow/assist/train must be keybind-driven (CLICK bindings), not /click macros. ActionButtonUseKeyDown=1 on this client.
  * Bindings.xml is auto-loaded by the client (never list it in the toc; client needs a full restart to notice new/deleted files); entries need `<Binding ...></Binding>` with
    BINDING_NAME_CLICK <Button>:LeftButton globals; category needs a header global.
- Group APIs confirmed working: AcceptGroup (auto-accept), C_PartyInfo.ConvertToRaid, C_PartyInfo.SetLootMethod("freeforall"), cross-home-realm member joins (shows as Unknown for a moment).
- Layers: an invite moves the invitee onto the inviter's layer, so no layer-specific handling is needed (user-verified).
- Quest share: sender used QuestLogPushQuest; receiver needs QUEST_DETAIL/QUEST_ACCEPT_CONFIRM handling (probe extended; result pending).
- Quest share CONFIRMED: sender QuestLogPushQuest -> receiver QUEST_DETAIL (arg 0) -> AcceptQuest() -> QUEST_ACCEPTED(questID). Same as Mama old flow. Taxi/mount/abandon still untested.
- Account-wide macro "MFFollow" (CreateMacro(name, icon, body, false); EditMacro(idx, nil, nil, body)) WORKS: body "/assist Name\n/follow Name" (UNQUOTED; quoted gave "unknown unit"),
  press from an action bar follows+assists. `leader` mode rewrites it on roster/leader change (out of combat; defer to PLAYER_REGEN_ENABLED). Client appends a trailing newline - KEEP it so users can add lines after ours.
  Macro icon must be a numeric fileID; addon-folder paths are stored as nil (blank icon). Default icon: TBD (user to pick via /macro then /dump GetMacroInfo("MFFollow")). EditMacro with nil icon preserves a user-chosen icon.
  Account-wide macro means one lead shared by all characters of the account.
- Default macro icon: 132171 (set only in CreateMacro at first creation; text updates use EditMacro(idx, nil, nil, body) and never touch the icon).

## Status update (supersedes the layout/naming in the original plan above)
Decision: instead of a separate Mama-forever repo, this IS the original MAMA-multiboxing repo (kept for stars, CurseForge/Wago/WoWI
ids and secrets). The Forever rewrite replaced the old addon on `master` (PR #21); old classic/retail/MoP code is only in git history
(last classic-era commit: fe02004 or v1.24.0 tag as mentioned in README.md). The addon keeps its original identity:
- Folder/addon name `Mama` (`Mama\Mama.toc`, Interface 16001, title M.A.M.A., IconTexture `Interface\AddOns\Mama\mama`), SavedVariables `MamaForeverSaved`.
- Files: Mama.lua (namespace `MF`, events, saved vars, commands, `messageHandlers`), Team.lua, Comm.lua, Actions.lua, Status.lua,
  Options.lua, UI.lua, Bindings.xml, Dialogs.lua, Bug.lua. No libs, no DBox dependency, no ISBoxer discovery, no EMA, no other WoW versions.
- Packaging: original BigWigsMods/packager@v2 via `.github\workflows\packaging.yaml` on tag push; `pkgmeta.yaml`
  (`package-as: Mama`, `move-folders: Mama/Mama: Mama`, ignores Probe/PLAN/README/install.bat); toc carries Curse 334197, Wago 7nGvmDKx,
  WoWI 26337; secrets CF_API_KEY/WAGO_API_TOKEN/WOWI_API_TOKEN live on this repo.
- `install.bat` copies `Mama\` to the beta AddOns folder (`_classic_beta_`). The dev probe lives in `Probe\MamaForeverProbe\` (not installed, not packaged).
- Git: work was done on branch `forever` and is now on `master`; `origin/main` is a leftover near-empty branch from the deleted Mama-forever repo.

## Implemented and verified in-game (Forever beta, 2-3 windows)
- One-time pairing: `/mama s N` shows a copy/paste token dialog (`teamId:secret:MasterName:` + checksum); `/mama token [new|<token>]`.
  Signed, timestamped addon messages (WHISPER to master/team + PARTY/RAID + GUILD); payloads `I;slot;name;flag`, `A;questID`, `L;name`, `Z;count`.
  Slot 1 = master/relay. Max slot 40. SAY/YELL addon messages do NOT work in Forever (retail-style client); only GUILD is used as an extra broadcast.
- Auto-accept of invites checks `db.team`. It is filled when a verified info message records a slot member (`RecordMember`), or by
  `/mama team add [name]` (no name: everyone grouped). Alerts also use `db.team` to skip whisper forwarding for team members.
  That command does not pair the character or let it exchange signed team messages; it still needs a slot and the shared token.
  Auto invite, raid conversion, and disband are implemented.
- Per-faction pairing (no cross faction grouping in Forever): ONE account wide token (`db.token`, `db.tokenFaction`), but the slot map
  (`db.slotsBy[faction]`, exposed as `db.slots`) and a history of the last 5 characters per slot (`db.history[faction][slot]`) are per faction.
  Announcing whispers the same faction's master/slot owners + up to 3 recent holders per slot, retried every 20s until someone answers
  (offline whispers are lost). Slot 1 of each faction is that faction's master (`IsMaster` = slot 1 + token), so each faction's team auto-invites.
  `/mama s 1` reuses the token; `/mama token new` makes a new one and clears the current faction's slots.
- Cross-home-realm whisper support (different realm IDs confirmed working; sender shown without realm).
- Status window (DynamicBoxer parity): slot column + `>` marker, class/connection state, row click targets/invites, left invite, middle disband,
  right options, shift-left party/raid, shift-right compact, shift-middle big slot number, ctrl-left auto-invite, ctrl-right token dialog,
  alt-left resend info, alt-right mark the team complete, ctrl-middle toggle Mama off/on for this character, wheel resize, drag to move.
- Identify overlay (big slot number + class icon + name), also at login for 6s.
  Identify splash: faction crest (Horde 516953, Alliance 516949 enlarged to 100; no Pandaren in Forever, no glow layer)
  left of the slot number, class icon right, name below, all anchored to the number.
- Follow/assist via CLICK keybindings (secure buttons, key-up, ignore `down`), plus account macro "MAMA" (icon 132171 only at creation).
  Keybinds: follow+assist lead, assist lead, follow train + assist lead, make-me-lead (`MAMA_LEAD`, also `/mama lead`;
  `auto` follows the group leader), invite, disband, identify, complete.
  Binding category `BINDING_HEADER_MAMAFOREVER` = "Mama-forever" (the keybindings UI shows `_G[category]` verbatim, so
  the category must be the global's name, not `MAMAFOREVER`).
  `/click Button` from a macro does NOT work (PreClick fires but the action doesn't happen); must use keybinds or action-bar macros.
- Quests: auto-accept, auto-share on accept (guard against re-sharing received quests), abandon sync (not for completed quests),
  all options on by default. Quest share CONFIRMED: sender QuestLogPushQuest -> receiver QUEST_DETAIL -> AcceptQuest() -> QUEST_ACCEPTED.
- Options panel in Settings (Game Menu > Options > AddOns).
- Loot (option `autoFFA`, default on): group leader sets free-for-all when the whole team (up to the highest known slot)
  is first grouped, group loot when strangers (no slot) join, free-for-all again once they leave. Nothing else
  (reload, leader change, manual change) triggers a switch. Uses `C_PartyInfo.GetLootMethod/SetLootMethod`.
- Commands: `/mama help`, `/mama debug [on|off]`, `/mama s N`, `/mama token [new|<token>]`, `/mama lead [name|auto]`,
  `/mama team [list|add|remove|clear]`, `/mama invite`, `/mama disband`, `/mama raid`, `/mama complete [N]`,
  `/mama autoinvite [on|off]`, `/mama macro [on|off]`, `/mama quest [on|off]`, `/mama dialog [on|off]`,
  `/mama profs [sync]`, `/mama trade`, `/mama ui [on|off]`, `/mama enable [off]`, `/mama disable`,
  `/mama identify`, `/mama options`, `/mama bug`, `/mama clearlog`, `/mama status`.
  The log gets a `---reload--- <date> <name>` line at each login/reload.
- Debug (`/mama debug on`) logs every received addon message, rejection reasons and the auto-invite decision.
- Message signing: HMAC-SHA256, truncated to 64 bits, using the shared token secret (implemented in `Hash.lua`).
  The token's typo-check character uses simple hashes and is not a message signature. Messages include a random
  team ID and timestamp; accepted signatures are rejected if replayed, and messages older than 120s or more than 5s in
  the future are rejected. Guild broadcasts are visible to guild members but filtered by team ID and signature.
  Sufficient for the threat model (other players in same guild/raid cannot spoof team commands).
- Account-wide macro "MAMA" (CreateMacro with numeric fileID icon 132171 at first creation; EditMacro preserves user-chosen icon).
  Body "/assist Name\n/follow Name" for minions; lead window gets "/follow player" (harmless no-op, no chat output).
  Body "/assist Name\n/follow Name" (unquoted; client appends trailing newline, kept for user additions).

## Professions + mats trade (in progress, 2026-10-06)
- Probe (`/mf check`, `/mf items`, `/mf copy` window): `GetProfessions()` returns profession indexes (prof1, prof2, then
  first aid, fishing, cooking); `GetProfessionInfo(i)` 7th value = skillLine ID (Tailoring 197, Enchanting 333...).
  `GetNumSkillLines`/`GetSkillLineInfo` and `Enum.ItemTradeGoodsSubclass` don't exist. Item class/subclass as retail:
  Tradegoods 7 (Parts 1, Cloth 5, Leather 6, Metal & Stone 7 = ore+bars+stone, Cooking 8, Herb 9, Elemental 10,
  Other 11, Enchanting 12), Recipe 9 (subclass = profession: LW 1, Alchemy 6...). `C_Container.GetContainerItemInfo`
  gives `isBound`/`quality`; `C_Item.GetItemInfo` is nil for uncached items, `GetItemInfoInstant` always works.
- `Professions.lua`: `P;id:rank,...` whispered once per newly seen member (`MEMBER_SEEN` fired from `HandleInfo`),
  sent to the team when a 25 point step changes, `Q;` asks. Saved in `db.profs[faction][name]`.
- `Trade.lua`: on `TRADE_SHOW` with a team member, fills up to 6 stacks the partner can use and we can't (or they are
  the team's best holder); the "Mama: give mats" button also gives mats we could use (`MF:GivesTo`). Verified in game.
- Options: sections, 2 checkboxes per row; Trade subcategory page (`Settings.RegisterCanvasLayoutSubcategory`) with
  one checkbox per category; "Send settings to team" sends `O;<0/1 per option>;<0/1 per trade category>` on the group channel
  (positional, same addon version assumed; length mismatch is reported and ignored).
  Unverified in game: subcategory page, settings sync.

## Team stats, alerts and off switch (2026-10-07, verified in game)
- `MEMBER_SEEN` now also fires when a member asks (`I` flag 1, i.e. it logged in/reloaded), so it gets our `P`/`G`
  again even if we already knew it.
- `Stats.lua`: `G;copper;free;slots` (general bags only), whispered on `MEMBER_SEEN`, sent to the team 5s after
  `PLAYER_MONEY`/`BAG_UPDATE_DELAYED` when changed (`SendTeam(payload, true)`: group + online whispers only). Saved in
  `db.stats[faction][name]` with a timestamp. Status window: free slots right of each name, team gold footer (current
  slot holders), footer tooltip lists every known character of the faction (alts, with age) and the total.
- `Alerts.lua` (options `followWarn`, `forwardWhispers`): on `AUTOFOLLOW_END` out of combat (us and the lead), watch
  10s; if not following again and `CheckInteractDistance(lead, 4)` fails, whisper `F;subzone` to the lead (raid
  warning + sound, 15s per sender). `CHAT_MSG_WHISPER` from non team senders -> `W;i/n;flag;sender;text` to the
  lead (150 byte UTF-8 safe parts), printed with a player link. GM whispers come as plain `CHAT_MSG_WHISPER` with
  `specialFlags` (arg6) `"GM"` (as `Blizzard_GMChatUI` checks): flag `GM` -> `<GM>` tag, raid warning, GM chat sound.
  Text/sender are `SecretInChatMessagingLockdown` per 1.60.1 docs: if `issecretvalue` (when it exists) says so, send
  `W;0/0;flag;;` and the lead prints "look in its window" (untested, never seen a lockdown on Forever).

- Per character off switch `db.disabled[name]` (`MF:Disabled/SetDisabled/ToggleDisabled`, `/mama disable`,
  `/mama enable [off]`, binding `MAMA_TOGGLE`, Ctrl+Middle on the status window, red "disabled" in its title): all
  sends dropped in `schedule`, incoming addon messages ignored, no announce loop; `MF:OnTeam(event, fn)` registers
  handlers skipped while disabled (invite/quest auto accept); loot, auto invite, quest share, trade fill check it too.

## Possible improvements
- `/mama find <item>`: which character (alts included) has an item, bags and bank (recorded on bank visits).
- Global inventory: per character bags/bank contents saved and shared across the team.

## Still to do
- Port from old Mama maybe: mount/dismount sync.
- Still unverified on Forever: `C_PartyInfo.UninviteUnit` edge cases and raid conversion with more than 5 characters.
