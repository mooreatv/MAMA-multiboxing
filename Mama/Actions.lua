-- Actions: follow/assist/train secure buttons (for keybinds), the account-wide "MAMA" macro, quest auto-accept.
-- Findings on Forever: /click MamaFollow from a macro does nothing, but the same button works from a keybind
-- and an action-bar macro with the plain text "/assist Name" + "/follow Name" works too.
local _, MF = ...

local MACRO_NAME = "MAMA"
local MACRO_ICON = 132171 -- numeric file ID only; set at creation so users can pick their own later

local function makeButton(name)
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetAttribute("type", "macro")
  b:SetAttribute("useOnKeyDown", false)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:HookScript("PreClick", function(btn, button, down)
    MF:Debug("%s pressed (%s, down=%s): %s", name, tostring(button), tostring(down),
             tostring(btn:GetAttribute("macrotext")):gsub("\n", " | "))
  end)
  return b
end

local function stripTrailing(s) return (s or ""):gsub("%s+$", "") end

-- Returns true when the macro had to be created or changed.
function MF:UpdateMacro(lead)
  if not self.db.macro then return false end
  local body
  if lead and lead ~= self.myName then
    body = "/assist " .. lead .. "\n/follow " .. lead
  else
    -- Lead window: follow self (harmless, no chat output) so the macro is a no-op button for the lead.
    body = "/follow player"
  end
  local idx = GetMacroIndexByName(MACRO_NAME)
  if not idx or idx == 0 then
    local ok, err = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, body, false) -- false: account-wide
    self:Debug("CreateMacro %s -> %s, %s", MACRO_NAME, tostring(ok), tostring(err))
    if not ok or not err then self:Print("couldn't create the %s macro: %s", MACRO_NAME, tostring(err)) end
    return true
  end
  local _, _, current = GetMacroInfo(idx)
  if stripTrailing(current) == body then return false end
  self:Debug("macro %s (index %d) now: %s", MACRO_NAME, idx, body:gsub("\n", " | "))
  EditMacro(idx, nil, nil, body) -- nil name/icon: keep whatever the user chose
  return true
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
  local target = lead and lead ~= self.myName and (self.roster[lead] or lead) or nil
  local follow, assist = "", ""
  if target then
    assist = "/assist " .. target
    follow = assist .. "\n/follow " .. target
  end
  local train = "/follow player"
  if target and self.db.slot > 0 then
    local count = 0
    for slot in pairs(self.db.slots) do if slot > count then count = slot end end
    if count > 0 then
      local previousSlot = ((self.db.slot + count - 2) % count) + 1
      local previous = self.db.slots[previousSlot]
      train = assist .. "\n/follow " .. (previous or "player")
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

-- Quests we got from a team member (shared to us, or picked up by mirroring the lead's dialog, see Dialogs.lua):
-- don't share them back out when they get accepted, the others already have them.
MF.noShare = {}
local escortConfirmed = false -- the next accepted quest is an escort we joined: its starter already has everyone

-- Opening the NPC (gossip/greeting) or clicking a quest with a modifier held skips auto accept, to read it first.
local heldNpc -- GUID of the NPC whose dialog was opened with a modifier held
local function noteModifier() heldNpc = IsModifierKeyDown() and UnitGUID("npc") or nil end
MF:On("GOSSIP_SHOW", noteModifier)
MF:On("QUEST_GREETING", noteModifier)

local function acceptQuest(self)
  if IsModifierKeyDown() or (heldNpc and heldNpc == UnitGUID("npc")) then
    self:Debug("not auto accepting quest: modifier held")
    return
  end
  if self.db.autoQuest and IsInGroup() then
    self:Debug("accepting quest")
    if UnitIsPlayer("questnpc") then self.noShare[GetQuestID()] = true end
    AcceptQuest()
  end
end
MF:OnTeam("QUEST_DETAIL", acceptQuest)

-- Someone in the group started an escort/event quest: that's a confirmation popup, answered with ConfirmAcceptQuest.
MF:OnTeam("QUEST_ACCEPT_CONFIRM", function(self, who, title)
  if not (self.db.autoQuest and IsInGroup()) then return end
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
  if not self.db.autoShare or not IsInGroup() or self:Disabled() then return end
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
  if abandoning or not MF.db.autoAbandon then return end
  if id and id ~= 0 then MF:SendTeam("A;" .. id) end
end
hooksecurefunc(C_QuestLog, "AbandonQuest", abandonHook)

MF.messageHandlers.A = function(self, sender, rest)
  local id = tonumber(rest)
  if not self.db.autoAbandon or not id then return end
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
  if setting == "on" or setting == "off" then self.db.macro = setting == "on" end
  self:Print("keeping the account macro \"%s\" up to date is now %s", MACRO_NAME, tostring(self.db.macro))
  self:RefreshActions()
end, "macro [on|off] - show or set whether to maintain the account-wide MAMA macro (drag it to a bar once)")

MF:AddCommand("quest", function(self, rest)
  self.db.autoQuest = self:ParseOnOff(rest, self.db.autoQuest)
  self:Print("auto accept quests (while grouped) is now %s", tostring(self.db.autoQuest))
end, "quest [on|off] - auto accept shared quests/quest dialogs while grouped")
