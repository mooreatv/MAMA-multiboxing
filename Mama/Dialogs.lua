-- Dialogs: the lead's choices in NPC dialogs (gossip options, quest pick/return/reward, flight paths) are mirrored on
-- the other windows. Each message carries the NPC id and the identity of the choice (option or quest id, reward item
-- id, node name); a window only follows when the dialog it has open offers that same choice. The lead is usually a bit
-- ahead of us, so an unmatched choice stays pending for a few seconds and is retried whenever a dialog event arrives.
--
-- What the Forever client does (see the dialog probe logs): GOSSIP_SHOW with GossipFrame; quests are picked with
-- C_GossipInfo.SelectActiveQuest/SelectAvailableQuest(questID), which closes the gossip and opens QuestFrame
-- (QuestFrameRewardPanel for a quest that can be turned in) with GetQuestID() set; GetQuestReward(choiceIndex) turns in.

local _, MF = ...

local PENDING_SECONDS = 6
local DEDUP_SECONDS = 0.3
local MAX_TEXT = 80

local mirroring = false -- true while we replay the lead's choice, so our own hooks don't send it back
local pending = {}
local lastSent = {}
local lastNpc = 0 -- the "npc" unit is already gone when some hooks run, so remember the last one seen
local taxiNames = {} -- node index -> name, cached when the map opens
local hooked = {} -- reward buttons whose clicks we already track
local reward = {questID = 0, items = {}, picked = 0} -- reward choices of the quest complete dialog we have open

local function setPicked(index, source)
  if not index or index < 1 or index > #reward.items or reward.picked == index then return end
  reward.picked = index
  MF:Debug("dialog: reward %d selected here (item %s, via %s): it will be kept, not the lead's", index, tostring(reward.items[index]), source)
end

-- Every clickable reward choice under the quest frame, whatever it is named in this client.
local function hookButtons()
  local function scan(f, depth)
    if depth > 6 then return end
    for _, c in ipairs({f:GetChildren()}) do
      local name = c.GetName and c:GetName() or ""
      if not hooked[c] and c.HookScript and c.HasScript and c:HasScript("OnClick")
        and (c.type == "choice" or name:find("QuestInfoItem") or name:find("QuestInfoReward")) and (c:GetID() or 0) > 0 then
        hooked[c] = true
        c:HookScript("OnClick", function(b) setPicked(b:GetID(), "button " .. (b:GetName() or "?")) end)
      end
      scan(c, depth + 1)
    end
  end
  for _, name in ipairs({"QuestFrame", "QuestInfoFrame"}) do
    if _G[name] then scan(_G[name], 0) end
  end
end

-- Last resort: Blizzard's own selection, polled while the reward panel is open.
local poll = CreateFrame("Frame")
poll:SetScript("OnUpdate", function()
  if reward.questID ~= 0 and #reward.items > 1 and shown("QuestFrameRewardPanel") then
    local c = QuestInfoFrame and QuestInfoFrame.itemChoice or 0
    if c > 0 then setPicked(c, "QuestInfoFrame.itemChoice") end
  end
end)

local function clean(s)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[;:|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return s:sub(1, MAX_TEXT)
end

local function shown(frameName)
  local f = _G[frameName]
  return f and f:IsShown() or false
end

-- Creature id from the GUID of the NPC we're talking to ("Creature-0-server-instance-zone-ID-spawn"); nil: no dialog.
local function currentNpc()
  local guid = UnitGUID("npc")
  if not guid then return nil end
  lastNpc = tonumber((select(6, strsplit("-", guid)))) or 0
  return lastNpc
end

local function iAmLead(self)
  if not IsInGroup() then return false end
  local lead = self:GetLead()
  return lead == nil or lead == self.myName
end

local function send(self, verb, id, text)
  if mirroring or not self.db.autoDialog or not iAmLead(self) then return end
  local t = GetTime()
  local key = verb .. tostring(id) .. tostring(text)
  if lastSent[key] and t - lastSent[key] < DEDUP_SECONDS then return end
  lastSent[key] = t
  local payload = ("D;%s;%d;%d;%s"):format(verb, currentNpc() or lastNpc, tonumber(id) or 0, clean(text))
  self:Debug("dialog: mirroring %s", payload)
  self:SendTeam(payload)
end

-- Receivers: return true once handled, false when our dialog doesn't offer that choice (yet).

local function gossipOption(self, id, text)
  for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
    if (id > 0 and o.gossipOptionID == id) or (id == 0 and clean(o.name) == text) then
      self:Debug("dialog: selecting gossip option %s (%s)", tostring(o.gossipOptionID), clean(o.name))
      C_GossipInfo.SelectOption(o.gossipOptionID)
      return true
    end
  end
  return false
end

local function questPick(listFn, selectFn)
  return function(self, id)
    if not shown("GossipFrame") then return false end
    for _, q in ipairs(C_GossipInfo[listFn]() or {}) do
      if q.questID == id then
        self:Debug("dialog: %s(%d) '%s'", selectFn, id, clean(q.title))
        C_GossipInfo[selectFn](id)
        return true
      end
    end
    return false
  end
end

local function questContinue(self, id)
  if not shown("QuestFrameProgressPanel") or GetQuestID() ~= id then return false end
  if not IsQuestCompletable() then
    self:Print("not continuing quest %d: it can't be completed on this window yet", id)
    return true
  end
  self:Debug("dialog: continuing quest %d", id)
  CompleteQuest()
  return true
end

local function questReward(self, id, text)
  if not shown("QuestFrameRewardPanel") or GetQuestID() ~= id then return false end
  local want, choice = tonumber(text) or 0, 0
  local picked = reward.picked or 0
  if picked == 0 and QuestInfoFrame and (QuestInfoFrame.itemChoice or 0) > 0 then picked = QuestInfoFrame.itemChoice end
  if #reward.items > 1 and picked > 0 and picked <= #reward.items then
    choice = picked -- selected by hand in this window: keep it rather than following the lead
  elseif #reward.items == 1 then
    choice = 1
  elseif #reward.items > 1 then
    for i, item in ipairs(reward.items) do
      if want > 0 and item == want then choice = i end
    end
    if choice == 0 then
      self:Print("not turning in quest %d: the lead's reward (item %d) isn't offered here", id, want)
      return true
    end
  end
  self:Debug("dialog: turning in quest %d with reward %d: %s (hand-picked %d, lead's item %d)", id, choice,
    picked > 0 and choice == picked and "YOUR selection" or "following the lead", picked, want)
  GetQuestReward(choice)
  return true
end

local function taxi(self, _, text)
  for i = 1, NumTaxiNodes() do
    if clean(TaxiNodeName(i)) == text then
      if TaxiNodeGetType(i) ~= "REACHABLE" then
        self:Print("not flying to %s: the node is %s for us", text, tostring(TaxiNodeGetType(i)))
        return true
      end
      self:Debug("dialog: taking taxi node %d (%s)", i, text)
      TakeTaxiNode(i)
      return true
    end
  end
  return false
end

local receivers = {
  go = gossipOption,
  qa = questPick("GetAvailableQuests", "SelectAvailableQuest"),
  qc = questPick("GetActiveQuests", "SelectActiveQuest"),
  qp = questContinue,
  qr = questReward,
  tx = taxi,
}

-- Try every pending choice (in order): a stale one that doesn't match must not block the ones behind it.
local function run(self)
  local now = GetTime()
  local i = 1
  while pending[i] do
    local p = pending[i]
    local done = false
    if now > p.expires then
      self:Debug("dialog: gave up mirroring %s %d '%s'", p.verb, p.id, p.text)
      done = true
    else
      local npc = currentNpc()
      if p.verb == "tx" or (npc and (p.npc == 0 or npc == 0 or p.npc == npc)) then
        mirroring = true
        local ok, handled = pcall(receivers[p.verb], self, p.id, p.text)
        mirroring = false
        if not ok then
          self:Debug("dialog: error mirroring %s: %s", p.verb, tostring(handled))
          done = true
        else
          done = handled
        end
      end
    end
    if done then table.remove(pending, i) else i = i + 1 end
  end
end

MF.messageHandlers.D = function(self, sender, rest)
  local verb, npc, id, text = rest:match("^(%a+);(%d+);(%d+);(.*)$")
  if not verb or not receivers[verb] then return end
  if not self.db.autoDialog or sender ~= self:GetLead() then
    self:Debug("dialog: ignoring %s from %s (disabled or not the lead)", verb, sender)
    return
  end
  table.insert(pending, {verb = verb, npc = tonumber(npc), id = tonumber(id), text = text, expires = GetTime() + PENDING_SECONDS})
  run(self)
end

-- Events that can make a pending choice applicable. Frames may show slightly after the event: retry next frame too.
local function retry(self)
  if #pending == 0 then return end
  run(self)
  C_Timer.After(0, function() run(self) end)
end

MF:On("GOSSIP_SHOW", function(self)
  currentNpc()
  retry(self)
end)
MF:On("QUEST_PROGRESS", function(self)
  currentNpc()
  retry(self)
end)
MF:On("QUEST_COMPLETE", function(self)
  currentNpc()
  if reward.questID ~= GetQuestID() then reward.picked = 0 end
  reward.questID = GetQuestID()
  reward.items = {}
  for i = 1, GetNumQuestChoices() do reward.items[i] = tonumber((GetQuestItemLink("choice", i) or ""):match("item:(%d+)")) or 0 end
  hookButtons()
  C_Timer.After(0, hookButtons) -- the buttons may only be created after this event
  C_Timer.After(0.5, hookButtons)
  self:Debug("dialog: quest %d offers %d reward choices", reward.questID, #reward.items)
  retry(self)
end)
MF:On("TAXIMAP_OPENED", function(self)
  currentNpc()
  wipe(taxiNames)
  for i = 1, NumTaxiNodes() do taxiNames[i] = TaxiNodeName(i) end
  retry(self)
end)

-- The lead's choices, noticed with secure hooks right after the Blizzard UI made them.
MF:Listen("LOGIN", function(self)
  hooksecurefunc(C_GossipInfo, "SelectOption", function(id)
    local text
    for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do
      if o.gossipOptionID == id then text = o.name end
    end
    send(self, "go", id, text)
  end)
  hooksecurefunc(C_GossipInfo, "SelectAvailableQuest", function(id) send(self, "qa", id, "") end)
  hooksecurefunc(C_GossipInfo, "SelectActiveQuest", function(id) send(self, "qc", id, "") end)
  hooksecurefunc("CompleteQuest", function()
    if shown("QuestFrameProgressPanel") then send(self, "qp", GetQuestID(), "") end
  end)
  if _G.QuestInfoItem_OnClick then
    hooksecurefunc("QuestInfoItem_OnClick", function(b)
      if b and b.type == "choice" then setPicked(b:GetID(), "QuestInfoItem_OnClick") end
    end)
  end
  hooksecurefunc("GetQuestReward", function(choice)
    if reward.questID == 0 then return end
    send(self, "qr", reward.questID, tostring(choice and choice > 0 and reward.items[choice] or 0))
  end)
  hooksecurefunc("TakeTaxiNode", function(index)
    send(self, "tx", 0, taxiNames[index] or TaxiNodeName(index))
  end)
end)

MF:AddCommand("dialog", function(self, rest)
  self.db.autoDialog = self:ParseOnOff(rest, self.db.autoDialog)
  self:Print("mirroring the lead's dialog choices (gossip, quests, flight paths) is now %s", tostring(self.db.autoDialog))
end, "dialog [on|off] - make the other windows pick the same dialog options/flight path as the lead")
