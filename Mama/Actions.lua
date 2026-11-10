-- Actions: follow/assist/train secure buttons (for keybinds), the per-character "MAMA" macro, quest auto-accept.
-- Findings on Forever: /click MamaFollow from a macro does nothing, but the same button works from a keybind
-- and an action-bar macro with the plain text "/assist Name" + "/follow Name" works too.
local _, MF = ...

local MACRO_NAME = "MAMA"
local MACRO_ICON = 132171 -- numeric file ID only; set at creation so users can pick their own later
local DYNAMIC_ICON = 134400 -- question mark: the client shows the #showtooltip spell's icon

-- Starting point of each class's MAMA macro (the user edits it from there): pet = also send the pet. All get
-- /startattack (hunters too: melee in range, doesn't stop Auto Shot). Stages = spells to /cast; while the macro is
-- an untouched starter it moves to the last stage whose `known` spell IDs (rank 1) are all learned. "!" keeps spamming
-- from toggling Auto Shot off (Serpent Sting starts Auto Shot by itself, even on cooldown); "#" lines are ignored by
-- the client. The bare #showtooltip shows the first spell the macro would cast. `old` = that stage's spells in older
-- versions (still an untouched starter).
local STARTERS = {
  DRUID = {{"Wrath"}},
  HUNTER = {pet = true, {"!Auto Shot"}, {"Serpent Sting", known = {1978}, old = {"!Auto Shot", "Serpent Sting"}}},
  MAGE = {{WOW_PROJECT_ID == 1 and "Frostbolt" or "Fireball"}}, -- retail mages start with Frostbolt
  PALADIN = {{hint = "# /cast Judgement"}, {"Judgement", known = {20271}}},
  PRIEST = {{"Smite"}, {"Shadow Word: Pain", known = {589}}},
  ROGUE = {{"Sinister Strike"}},
  SHAMAN = {{"Lightning Bolt"}},
  WARLOCK = {pet = true, {"Shadow Bolt"}},
  -- Charge (100) in when out of combat, then Rend (772) or Heroic Strike: either can be learned first
  WARRIOR = {
    {"Heroic Strike"}, {"[nocombat] Charge", "Heroic Strike", known = {100}}, {"Rend", known = {772}},
    {"[nocombat] Charge", "Rend", known = {100, 772}}
  }
}

local function classStarter()
  local _, class = UnitClass("player")
  return STARTERS[class] or {{}}
end

local function knowsAll(ids)
  for _, id in ipairs(ids or {}) do if not C_SpellBook.IsSpellKnown(id) then return false end end
  return true
end

local function bestStage(starter)
  local best = 1
  for i, stage in ipairs(starter) do if knowsAll(stage.known) then best = i end end
  return best
end

-- Older versions' tooltip line: the conditional spells first, in order, then the last spell
-- (e.g. "[nocombat] Charge; Rend").
local function oldTooltip(spells)
  local parts = {}
  for _, spell in ipairs(spells) do if spell:match("^%[") then parts[#parts + 1] = spell end end
  local last = spells[#spells]
  if last and not last:match("^%[") then parts[#parts + 1] = (last:gsub("^!", "")) end
  return #parts > 0 and " " .. table.concat(parts, "; ") or ""
end

-- What a bare #showtooltip shows: the first spell the macro would cast, i.e. the conditional spells in order up to
-- the first unconditional one.
local function bareTooltip(spells)
  local parts = {}
  for _, spell in ipairs(spells) do
    if not spell:match("^%[") then
      parts[#parts + 1] = (spell:gsub("^!", ""))
      break
    end
    parts[#parts + 1] = spell
  end
  return #parts > 0 and " " .. table.concat(parts, "; ") or ""
end

-- Older versions always named the spell: drops a "#showtooltip <spells>" that a bare one shows anyway (also in
-- edited macros: same tooltip either way). Any /use, /castsequence... before the first unconditional /cast keeps it.
local function dropRedundantTooltip(body)
  local casts = {}
  for line in body:gmatch("[^\n]+") do
    local cmd, arg = line:match("^%s*/(%a+)%s+(.-)%s*$")
    cmd = cmd and cmd:lower()
    if cmd == "cast" then
      casts[#casts + 1] = arg
    elseif cmd == "use" or cmd == "castsequence" or cmd == "castrandom" or cmd == "userandom" then
      casts[#casts + 1] = "\0" -- never matches a tooltip
    end
  end
  local done
  return (body:gsub("[^\n]+", function(line)
    if done then return end
    local arg = line:match("^#showtooltip%s+(.-)%s*$")
    if not arg or arg == "" then return end
    done = true
    if " " .. arg == bareTooltip(casts) then return "#showtooltip" end
  end))
end

-- Returns the class starter macro body and icon, for the given stage (default: the best known one); old = that
-- stage as older versions made it (nil if unchanged).
local function starterMacro(target, stage, old)
  local starter = classStarter()
  local spells = starter[stage or bestStage(starter)]
  local tip = ""
  if old then
    if not spells.old then return end
    spells = spells.old
    tip = oldTooltip(spells)
  end
  local last = spells[#spells]
  local lines = {
    "#showtooltip" .. tip, "/follow " .. target, "/assist " .. target, "/stopmacro [help][dead][noexists][noharm]",
    "/startattack"
  }
  if starter.pet then lines[#lines + 1] = "/petattack" end
  for _, spell in ipairs(spells) do lines[#lines + 1] = "/cast " .. spell end
  if spells.hint then lines[#lines + 1] = spells.hint end
  return table.concat(lines, "\n"), last and DYNAMIC_ICON or MACRO_ICON
end

local function stripTrailing(s) return (s:gsub("%s+$", "")) end

local function findMacro(first, last) for i = first, last do if GetMacroInfo(i) == MACRO_NAME then return i end end end

-- Character macros come after all the account macro slots.
local function charMacroIndex()
  local _, count = GetNumMacros()
  local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
  return findMacro(base + 1, base + count)
end

function MF:MamaMacroIndex() return charMacroIndex() end

local function accountMacroIndex() return findMacro(1, (GetNumMacros())) end

-- The only part of the macro Mama manages: every /follow and /assist line gets the target, the rest is the user's.
local function retarget(body, target)
  return (body:gsub("[^\n]+", function(line)
    local cmd = (line:match("^%s*/(%a+)") or ""):lower()
    if cmd == "follow" or cmd == "assist" then return "/" .. cmd .. " " .. target end
  end))
end

-- What the follow/assist lines name: in a party, the group leader is party1 on every other window (the client lists
-- it first, again after a promotion), so lines naming party1 keep up with a new leader even in combat, when they can't
-- be rewritten; otherwise (raid, lead not the group leader, not grouped) the lead's name. nil: we lead, or no lead.
local function leadTarget(self, lead)
  if not lead or lead == self.myName then return nil end
  if not IsInRaid() and self.roster[lead] == "party1" and UnitIsGroupLeader("party1") then return "party1" end
  return self:CommandName(lead)
end

-- Lead window (or no lead): follow self (harmless, no chat output) so the macro only does the rest for the lead.
local function macroTarget(self, lead) return leadTarget(self, lead) or "player" end

local function makeButton(name)
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetAttribute("type", "macro")
  b:SetAttribute("useOnKeyDown", false)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:HookScript("PreClick", function(btn, button, down)
    if down then return end -- the action runs on key up: one log line per press (repeats collapse in the log)
    MF:Debug("%s pressed (%s): %s", name, tostring(button), tostring(btn:GetAttribute("macrotext")):gsub("\n", " | "))
  end)
  return b
end

local createFailed -- only say once per session that the macro couldn't be created

-- Creates this character's macro from the class starter; replaces the old account-wide one (older versions).
function MF:CreateMamaMacro(target)
  local old = accountMacroIndex()
  if old then
    DeleteMacro(old)
    self:Debug("deleted the account macro %s (index %d)", MACRO_NAME, old)
  end
  local body, icon = starterMacro(target)
  local ok, err = pcall(CreateMacro, MACRO_NAME, icon, body, true) -- true: per character
  self:Debug("CreateMacro %s -> %s, %s", MACRO_NAME, tostring(ok), tostring(err))
  if ok and err then
    self:Print(
      "created the %s macro for this character: drag it from the character tab of /macro to an action bar, " ..
        "then edit it as you like (Mama only changes the /follow and /assist lines)", MACRO_NAME)
  elseif not createFailed then
    createFailed = true
    self:Error("couldn't create the %s macro (character macros full?): %s", MACRO_NAME, tostring(err))
  end
  return ok and err ~= nil
end

-- Returns true when the macro had to be created or changed.
function MF:UpdateMacro(lead)
  if not self.db.macro then return false end
  local target = macroTarget(self, lead)
  local idx = charMacroIndex()
  if not idx then return self:CreateMamaMacro(target) end
  local _, icon, current = GetMacroInfo(idx)
  current = current or ""
  local body = dropRedundantTooltip(retarget(current, target))
  local newIcon -- nil: keep whatever the user chose
  local best = bestStage(classStarter())
  local trimmed = stripTrailing(body)
  for stage = 1, best do
    local older, oldIcon = starterMacro(target, stage)
    if stage == best then older = nil end -- already the best starter
    local legacy, legacyIcon = starterMacro(target, stage, true)
    if trimmed == older or trimmed == legacy then -- still a starter, not edited: the current best one
      body, newIcon = starterMacro(target, best)
      if icon ~= (trimmed == older and oldIcon or legacyIcon) then newIcon = nil end
      if stage < best then self:Print("the %s macro now uses your newly learned spell", MACRO_NAME) end
      break
    end
  end
  if body == current then return false end
  self:Debug("macro %s (index %d) now: %s", MACRO_NAME, idx, body:gsub("\n", " | "))
  EditMacro(idx, nil, newIcon, body)
  return true
end

-- Puts the class starter back (body and icon).
function MF:ResetMacro()
  local target = macroTarget(self, self:GetLead())
  local idx = charMacroIndex()
  if not idx then
    self:CreateMamaMacro(target)
    return
  end
  local body, icon = starterMacro(target)
  EditMacro(idx, nil, icon, body)
  self:Print("the %s macro is back to the %s starter", MACRO_NAME, (UnitClass("player")))
end

-- Sets a button's macro text; returns true when it changed.
local function setText(button, text)
  if button:GetAttribute("macrotext") == text then return false end
  button:SetAttribute("macrotext", text)
  return true
end

-- Called on every team/roster/leader change (often several times in a row): only acts and logs when something differs.
function MF:RefreshActions()
  if InCombatLockdown() then
    self.pendingRefresh = true
    return
  end
  self.pendingRefresh = nil
  local lead = self:GetLead()
  local target = leadTarget(self, lead)
  local follow, assist = "", ""
  if target then
    assist = "/assist " .. target
    -- /follow takes no conditionals; a dead lead is still assisted (it keeps targeting), just not followed
    follow = assist .. (target == "party1" and "\n/stopmacro [@party1,dead]" or "") .. "\n/follow " .. target
  end
  local train = "/follow player"
  if target and self.db.slot > 0 then
    local count = 0
    for slot in pairs(self.db.slots) do if slot > count then count = slot end end
    if count > 0 then
      local previousSlot = ((self.db.slot + count - 2) % count) + 1
      local previous = self.db.slots[previousSlot]
      train = assist .. "\n/follow " .. (self:CommandName(previous) or "player")
    end
  end
  local changed = setText(self.buttons.MamaFollow, follow)
  changed = setText(self.buttons.MamaAssist, assist) or changed
  changed = setText(self.buttons.MamaTrain, train) or changed
  changed = self:UpdateMacro(lead) or changed
  if changed then self:Debug("actions refreshed, lead=%s target=%s", tostring(lead), tostring(target)) end
end

MF:Listen("LOGIN", function(self)
  self.buttons = {
    MamaFollow = makeButton("MamaFollow"),
    MamaAssist = makeButton("MamaAssist"),
    MamaTrain = makeButton("MamaTrain")
  }
  self:RefreshActions()
  -- the macro list may not be ready yet at login, so check again once the world is loaded
  C_Timer.After(3, function() self:RefreshActions() end)
end)
MF:On("PLAYER_ENTERING_WORLD", function(self) if self.buttons then self:RefreshActions() end end)
MF:Listen("TEAM_CHANGED", function(self) if self.buttons then self:RefreshActions() end end)
MF:On("PLAYER_REGEN_ENABLED", function(self) if self.pendingRefresh then self:RefreshActions() end end)
MF:On("LEARNED_SPELL_IN_SKILL_LINE", function(self) if self.buttons then self:RefreshActions() end end)

-- Quests we got from a team member (shared to us, or picked up by mirroring the lead's dialog, see Dialogs.lua):
-- don't share them back out when they get accepted, the others already have them.
MF.noShare = {}
local escortConfirmed = false -- the next accepted quest is an escort we joined: its starter already has everyone

-- Opening the NPC (gossip/greeting) or clicking a quest with a modifier held skips auto accept, to read it first.
-- Not for quests shared by a player: the modifier state is seen by every window, so a modifier still held on the
-- lead while it accepts would leave the shared quest open on the others.
local heldNpc -- GUID of the NPC whose dialog was opened with a modifier held
-- nil without a dialog, or when the GUID is a secret value (in dungeons: can't be compared)
local function npcGUID()
  local guid = UnitGUID("npc")
  if not MF.IsSecret(guid) then return guid end
end
local function noteModifier() heldNpc = IsModifierKeyDown() and npcGUID() or nil end
MF:On("GOSSIP_SHOW", noteModifier)
MF:On("QUEST_GREETING", noteModifier)

local function acceptQuest(self)
  local shared = UnitIsPlayer("questnpc")
  if not shared and (IsModifierKeyDown() or (heldNpc and heldNpc == npcGUID())) then
    self:Debug("not auto accepting quest: modifier held")
    return
  end
  if self.db.autoQuest and IsInGroup() and not self:IsAway() then
    self:Debug("accepting quest")
    if shared then self.noShare[GetQuestID()] = true end
    AcceptQuest()
  end
end
MF:On("QUEST_DETAIL", function(self)
  self:Debug("QUEST_DETAIL %s: autoQuest=%s grouped=%s disabled=%s", tostring(GetQuestID()),
             tostring(self.db.autoQuest), tostring(IsInGroup()), tostring(self:Disabled()))
end)
MF:OnTeam("QUEST_DETAIL", acceptQuest)

-- Someone in the group started an escort/event quest: that's a confirmation popup, answered with ConfirmAcceptQuest.
MF:OnTeam("QUEST_ACCEPT_CONFIRM", function(self, who, title)
  if not (self.db.autoQuest and IsInGroup()) or self:IsAway() then return end
  self:Debug("confirming quest %s started by %s", tostring(title), tostring(who))
  escortConfirmed = true
  C_Timer.After(5, function() escortConfirmed = false end) -- in case it doesn't get accepted after all
  ConfirmAcceptQuest()
  StaticPopup_Hide("QUEST_ACCEPT")
end)

-- Share every quest we accept with the group, so the other windows pick it up (their QUEST_DETAIL auto-accepts).
MF:On("QUEST_ACCEPTED", function(self, id)
  self:Debug("QUEST_ACCEPTED %s", tostring(id))
  local skip = self.noShare[id] or escortConfirmed
  self.noShare[id], escortConfirmed = nil, false
  if not self.db.autoShare or not IsInGroup() or self:Disabled() or self:IsAway() then return end
  if skip then
    self:Debug("not sharing quest %s: we got it from the team", tostring(id))
    return
  end
  if not C_QuestLog.IsPushableQuest(id) then
    self:Debug("quest %s is not shareable", tostring(id))
    return
  end
  C_QuestLog.SetSelectedQuest(id)
  QuestLogPushQuest()
  self:Debug("shared quest %s", tostring(id))
end)

-- Abandon on one window, abandon everywhere (only quests that aren't complete yet).
-- The quest is the one selected when SetAbandonQuest is called (before the confirmation popup): the selection can
-- change while the popup is up, so remember it then.
local abandoning = false
local abandonID
hooksecurefunc(C_QuestLog, "SetAbandonQuest", function() abandonID = C_QuestLog.GetSelectedQuest() end)
local function abandonHook()
  local id = abandonID
  abandonID = nil
  if abandoning or not MF.db.autoAbandon or MF:IsAway() then return end
  if id and id ~= 0 then MF:SendTeam("A;" .. id) end
end
hooksecurefunc(C_QuestLog, "AbandonQuest", abandonHook)

MF.messageHandlers.A = function(self, sender, rest)
  local id = tonumber(rest)
  if not self.db.autoAbandon or not id then return end
  if self:IsAway() or self:IsAway(sender) then
    self:Debug("abandon of %d from %s: %s away", id, sender, self:IsAway() and "we're" or "they're")
    return
  end
  if not C_QuestLog.GetLogIndexForQuestID(id) then
    self:Debug("abandon of %d from %s: not in our log", id, sender)
    return
  end
  if C_QuestLog.ReadyForTurnIn(id) then
    self:Print("not abandoning completed quest %d despite request from %s", id, sender)
    return
  end
  self:Print("abandoning quest %d as %s did", id, sender)
  abandoning = true
  C_QuestLog.SetSelectedQuest(id)
  C_QuestLog.SetAbandonQuest()
  C_QuestLog.AbandonQuest()
  abandoning = false
end

MF:AddCommand("macro", function(self, rest)
  local setting = rest:lower()
  if setting == "reset" then
    if InCombatLockdown() then
      self:Error("can't change macros in combat")
    else
      self:ResetMacro()
    end
    return
  end
  if setting == "on" or setting == "off" then self:SetOption("macro", setting == "on") end
  self:Print("keeping this character's \"%s\" macro up to date is now %s", MACRO_NAME, tostring(self.db.macro))
  self:RefreshActions()
end, "macro [on|off|reset] - show or set whether to maintain this character's MAMA macro (drag it to a bar " ..
                "once, edit it freely: only its /follow and /assist lines are updated); reset puts the class starter back")

MF:AddCommand("quest", function(self, rest)
  self:SetOption("autoQuest", self:ParseOnOff(rest, self.db.autoQuest))
  self:Print("auto accept quests (while grouped) is now %s", tostring(self.db.autoQuest))
end, "quest [on|off] - while grouped, auto accept the quests NPCs offer and the ones shared by the team")
