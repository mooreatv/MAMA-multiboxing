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
  return b
end

local function stripTrailing(s)
  return (s or ""):gsub("%s+$", "")
end

function MF:UpdateMacro(lead)
  if not self.db.macro then return end
  local body = "/mama status"
  if lead and lead ~= self.myName then body = "/assist " .. lead .. "\n/follow " .. lead end
  local idx = GetMacroIndexByName(MACRO_NAME)
  if idx == 0 then
    local ok, err = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, body, false) -- false: account-wide
    if not ok then self:Print("couldn't create the %s macro: %s", MACRO_NAME, tostring(err)) end
    return
  end
  local _, _, current = GetMacroInfo(idx)
  if stripTrailing(current) ~= body then
    EditMacro(idx, nil, nil, body) -- nil name/icon: keep whatever the user chose
  end
end

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
    for slot in pairs(self.db.slots) do
      if slot > count then count = slot end
    end
    if count > 0 then
      local previousSlot = ((self.db.slot + count - 2) % count) + 1
      local previous = self.db.slots[previousSlot]
      train = assist .. "\n/follow " .. (previous or "player")
    end
  end
  self.buttons.MamaFollow:SetAttribute("macrotext", follow)
  self.buttons.MamaAssist:SetAttribute("macrotext", assist)
  self.buttons.MamaTrain:SetAttribute("macrotext", train)
  self:UpdateMacro(lead)
  self:Debug("actions refreshed, lead=%s target=%s", tostring(lead), tostring(target))
end

MF:Listen("LOGIN", function(self)
  self.buttons = {
    MamaFollow = makeButton("MamaFollow"),
    MamaAssist = makeButton("MamaAssist"),
    MamaTrain = makeButton("MamaTrain"),
  }
  self:RefreshActions()
end)
MF:Listen("TEAM_CHANGED", function(self)
  if self.buttons then self:RefreshActions() end
end)
MF:On("PLAYER_REGEN_ENABLED", function(self)
  if self.pendingRefresh then self:RefreshActions() end
end)

-- Quests we got shared by a team member: don't share them back out when they get accepted.
local receivedQuests = {}

local function acceptQuest(self)
  if self.db.autoQuest and IsInGroup() then
    self:Debug("accepting quest")
    if UnitIsPlayer("questnpc") then receivedQuests[GetQuestID()] = true end
    AcceptQuest()
  end
end
MF:On("QUEST_DETAIL", acceptQuest)
MF:On("QUEST_ACCEPT_CONFIRM", acceptQuest)

-- Share every quest we accept with the group, so the other windows pick it up (their QUEST_DETAIL auto-accepts).
MF:On("QUEST_ACCEPTED", function(self, a, b)
  local id = b or a -- Forever sends the quest id; be lenient in case a log index comes first
  self:Debug("QUEST_ACCEPTED %s %s", tostring(a), tostring(b))
  if not self.db.autoShare or not IsInGroup() then return end
  if receivedQuests[id] then
    receivedQuests[id] = nil
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
local abandoning = false
local function abandonHook()
  if abandoning or not MF.db.autoAbandon then return end
  local id = C_QuestLog.GetSelectedQuest()
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
  self.db.macro = self:ParseOnOff(rest, self.db.macro)
  self:Print("keeping the account macro \"%s\" up to date is now %s", MACRO_NAME, tostring(self.db.macro))
  self:RefreshActions()
end, "macro [on|off] - maintain the account-wide MAMA macro (drag it to a bar once)")

MF:AddCommand("quest", function(self, rest)
  self.db.autoQuest = self:ParseOnOff(rest, self.db.autoQuest)
  self:Print("auto accept quests (while grouped) is now %s", tostring(self.db.autoQuest))
end, "quest [on|off] - auto accept shared quests/quest dialogs while grouped")
