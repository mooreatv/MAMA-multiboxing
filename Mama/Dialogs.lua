-- Dialogs: the lead's choices in NPC dialogs (gossip options, quest pick/return/reward, flight paths) are mirrored on
-- the other windows. Each message carries the NPC id and the identity of the choice (option or quest id, reward item
-- id, node name); a window only follows when the dialog it has open offers that same choice. The lead is usually a bit
-- ahead of us, so an unmatched choice stays pending for a few seconds and is retried whenever a dialog event arrives.
--
-- What the Forever client does (see the dialog probe logs): GOSSIP_SHOW with GossipFrame; quests are picked with
-- C_GossipInfo.SelectActiveQuest/SelectAvailableQuest(questID), which closes the gossip and opens QuestFrame
-- (QuestFrameRewardPanel for a quest that can be turned in) with GetQuestID() set; GetQuestReward(choiceIndex) turns in.
--
-- Popups (StaticPopup: spirit healer, resurrect, summon, release spirit...) are mirrored too: the button the lead
-- clicks goes out with the popup's name ("which") and is clicked on the windows that have that same popup open.
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
-- Popups never mirrored: about the lead's own items or session, or answered elsewhere (team invites, Team.lua).
local noPopup = {CAMP = true, QUIT = true, PARTY_INVITE = true}
local function mirroredPopup(which) return which ~= "" and not noPopup[which] and not which:find("^DELETE") end

local function setPicked(index, source)
  if not index or index < 1 or index > #reward.items or reward.picked == index then return end
  reward.picked = index
  MF:Debug("dialog: reward %d selected here (item %s, via %s): it will be kept, not the lead's", index,
           tostring(reward.items[index]), source)
end

-- Every clickable reward choice under the quest frame, whatever it is named in this client.
local function hookButtons()
  local function scan(f, depth)
    if depth > 6 then return end
    for _, c in ipairs({f:GetChildren()}) do
      local name = c.GetName and c:GetName() or ""
      if not hooked[c] and c.HookScript and c.HasScript and c:HasScript("OnClick") and
        (c.type == "choice" or name:find("QuestInfoItem") or name:find("QuestInfoReward")) and (c:GetID() or 0) > 0 then
        hooked[c] = true
        c:HookScript("OnClick", function(b) setPicked(b:GetID(), "button " .. (b:GetName() or "?")) end)
      end
      scan(c, depth + 1)
    end
  end
  for _, name in ipairs({"QuestFrame", "QuestInfoFrame"}) do if _G[name] then scan(_G[name], 0) end end
end

local function shown(frameName)
  local f = _G[frameName]
  return f and f:IsShown() or false
end

-- Last resort: Blizzard's own selection, polled while the reward panel is open.
local poll = CreateFrame("Frame")
poll:SetScript("OnUpdate", function()
  if reward.questID ~= 0 and #reward.items > 1 and shown("QuestFrameRewardPanel") then
    local c = _G.QuestInfoFrame and _G.QuestInfoFrame.itemChoice or 0
    if c > 0 then setPicked(c, "QuestInfoFrame.itemChoice") end
  end
end)

local function clean(s)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[;:|]", ""):gsub("^%s+", "")
        :gsub("%s+$", "")
  return s:sub(1, MAX_TEXT)
end

-- Creature id from the GUID of the NPC we're talking to ("Creature-0-server-instance-zone-ID-spawn"); nil: no dialog.
local function currentNpc()
  local guid = UnitGUID("npc")
  if not guid then return nil end
  lastNpc = tonumber((select(6, strsplit("-", guid)))) or 0
  return lastNpc
end

local gossipCache = {} -- options of the last gossip dialog shown

local function iAmLead(self)
  if not IsInGroup() then return false end
  local lead = self:GetLead()
  return lead == nil or lead == self.myName
end

local function send(self, verb, id, text)
  if mirroring or not self.db.autoDialog or not iAmLead(self) then
    self:Debug("dialog: not sending %s %s (mirroring=%s autoDialog=%s lead=%s grouped=%s)", verb, tostring(id),
               tostring(mirroring), tostring(self.db.autoDialog), tostring(self:GetLead()), tostring(IsInGroup()))
    return
  end
  local t = GetTime()
  local key = verb .. tostring(id) .. tostring(text)
  if lastSent[key] and t - lastSent[key] < DEDUP_SECONDS then return end
  lastSent[key] = t
  local payload = ("D;%s;%d;%d;%s"):format(verb, currentNpc() or lastNpc, tonumber(id) or 0, clean(text))
  self:Debug("dialog: mirroring %s", payload)
  self:SendTeam(payload)
end

local function sendGossipIndex(self, index)
  local o
  for i, c in ipairs(gossipCache) do -- the client's index is 0-based (orderIndex)
    if (c.orderIndex or i - 1) == index then o = c end
  end
  if not o then self:Debug("dialog: no cached gossip option at index %s", tostring(index)) end
  if o then send(self, "go", o.gossipOptionID or 0, o.name) end
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

-- Open quest id (active: to turn in, else to pick up) from the gossip or the quest greeting (NPCs with only quests,
-- listed by index) we have open; false when it isn't offered there. A quest picked up because we mirror the lead must
-- not be shared again (noShare, Actions.lua).
local function openQuest(self, id, active)
  local index
  if shown("GossipFrame") then
    for _, q in ipairs((active and C_GossipInfo.GetActiveQuests or C_GossipInfo.GetAvailableQuests)() or {}) do
      if q.questID == id then index = 0 end
    end
  elseif shown("QuestFrameGreetingPanel") then
    for i = 1, active and GetNumActiveQuests() or GetNumAvailableQuests() do
      if active and GetActiveQuestID(i) == id or not active and select(5, GetAvailableQuestInfo(i)) == id then
        index = i
      end
    end
  end
  if not index then return false end
  self:Debug("dialog: opening quest %d (%s, %s)", id, active and "active" or "available",
             index > 0 and "greeting index " .. index or "gossip")
  if not active then self.noShare[id] = true end
  if index == 0 then
    (active and C_GossipInfo.SelectActiveQuest or C_GossipInfo.SelectAvailableQuest)(id)
  else
    (active and SelectActiveQuest or SelectAvailableQuest)(index)
  end
  return true
end

local function questPick(active) return function(self, id) return openQuest(self, id, active) end end

-- Our dialog still lists the quest the lead is turning in (its qc came before our dialog opened, or never came): open
-- it ourselves, once per pending choice and unless an earlier pending choice is already doing it.
local function openActive(self, id, p)
  if p.opened then return end
  for _, o in ipairs(pending) do
    if o == p then break end
    if o.id == id and (o.verb == "qc" or o.verb == "qp") then return end
  end
  p.opened = openQuest(self, id, true)
end

local function questContinue(self, id, _, p)
  if not shown("QuestFrameProgressPanel") or GetQuestID() ~= id then
    openActive(self, id, p)
    return false
  end
  if not IsQuestCompletable() then
    self:Print("not continuing quest %d: it can't be completed on this window yet", id)
    return true
  end
  self:Debug("dialog: continuing quest %d", id)
  CompleteQuest()
  return true
end

local function questReward(self, id, text, p)
  if not shown("QuestFrameRewardPanel") or GetQuestID() ~= id then
    -- the lead is past the gossip and progress pages: catch up through them
    if not p.continued and shown("QuestFrameProgressPanel") and GetQuestID() == id then
      p.continued = true
      return questContinue(self, id, nil, p) and not IsQuestCompletable()
    end
    openActive(self, id, p)
    return false
  end
  local want, choice = tonumber(text) or 0, 0
  local picked = reward.picked or 0
  if picked == 0 and _G.QuestInfoFrame and (_G.QuestInfoFrame.itemChoice or 0) > 0 then
    picked = _G.QuestInfoFrame.itemChoice
  end
  if #reward.items > 1 and picked > 0 and picked <= #reward.items then
    choice = picked -- selected by hand in this window: keep it rather than following the lead
  elseif #reward.items == 1 then
    choice = 1
  elseif #reward.items > 1 then
    for i, item in ipairs(reward.items) do if want > 0 and item == want then choice = i end end
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
      local kind = TaxiNodeGetType(i)
      if kind ~= "REACHABLE" and kind ~= "DISTANT" then
        self:Print("not flying to %s: the node is %s for us", text, tostring(TaxiNodeGetType(i)))
        return true
      end
      self:Debug("dialog: taking taxi node %d (%s, %s)", i, text, tostring(kind))
      GetNumRoutes(i) -- needed before taking a node that isn't directly connected
      TakeTaxiNode(i)
      return true
    end
  end
  return false
end

-- Popup choice as sent: "which,label" (the label tells apart per character buttons, like the self res options of DEATH).
local function popupChoice(which, button)
  return clean(which .. "," .. (button and button.GetText and button:GetText() or ""))
end

local function popup(self, index, text)
  local which = text:match("^[^,]*")
  if not mirroredPopup(which) then return true end
  local _, dialog = StaticPopup_Visible(which)
  if not dialog then return false end
  local button = dialog.GetButton and dialog:GetButton(index)
  if button and (not button:IsShown() or not button:IsEnabled() or popupChoice(which, button) ~= text) then
    self:Print("not answering the %s popup like the lead: button %d isn't the same here (%s)", which, index,
               popupChoice(which, button))
    return true
  end
  self:Debug("dialog: clicking button %d of popup %s", index, which)
  StaticPopup_OnClick(dialog, index)
  return true
end

local receivers = {
  go = gossipOption,
  qa = questPick(false),
  qc = questPick(true),
  qp = questContinue,
  qr = questReward,
  tx = taxi,
  pp = popup
}
local anyNpc = {tx = true, pp = true} -- choices not tied to the NPC we talk to

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
      if anyNpc[p.verb] or (npc and (p.npc == 0 or npc == 0 or p.npc == npc)) then
        mirroring = true
        local ok, handled = pcall(receivers[p.verb], self, p.id, p.text, p)
        mirroring = false
        if not ok then
          self:Debug("dialog: error mirroring %s: %s", p.verb, tostring(handled))
          done = true
        else
          done = handled
        end
      end
    end
    if done then
      table.remove(pending, i)
    else
      i = i + 1
    end
  end
end

MF.messageHandlers.D = function(self, sender, rest)
  local verb, npc, id, text = rest:match("^(%a+);(%d+);(%d+);(.*)$")
  if not verb or not receivers[verb] then return end
  if not self.db.autoDialog or sender ~= self:GetLead() or self:IsAway() then
    self:Debug("dialog: ignoring %s from %s (disabled, not the lead or we're away)", verb, sender)
    return
  end
  table.insert(pending, {
    verb = verb,
    npc = tonumber(npc),
    id = tonumber(id),
    text = text,
    expires = GetTime() + PENDING_SECONDS
  })
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
  gossipCache = C_GossipInfo.GetOptions() or {}
  self:Debug("dialog: gossip with %d options, %d available and %d active quests", #gossipCache,
             C_GossipInfo.GetNumAvailableQuests(), C_GossipInfo.GetNumActiveQuests())
  for i, o in ipairs(gossipCache) do
    self:Debug("dialog: gossip option %d: id=%s name=%s", i, tostring(o.gossipOptionID), clean(o.name))
  end
  retry(self)
end)

-- An NPC offering a single gossip option and no quest (vendor, trainer, flight master...) gets that option picked, as
-- the Blizzard UI already does for options flagged selectOptionWhenOnlyOption; one offering a single quest to pick up
-- (then auto accepted, see Actions.lua) or a single completed quest to turn in, and nothing else, gets that quest
-- opened. Only on the first page of a dialog (a one option follow-up page is left to read), and not when a modifier is
-- held while opening the NPC.
local function gossipQuests()
  return C_GossipInfo.GetOptions() or {}, C_GossipInfo.GetAvailableQuests() or {}, C_GossipInfo.GetActiveQuests() or {}
end

local firstPage = true
MF:On("GOSSIP_CLOSED", function() firstPage = true end)
MF:On("GOSSIP_SHOW", function(self)
  local first = firstPage
  firstPage = false
  if not first or not self.db.autoGossip or IsModifierKeyDown() then return end
  local options, available, active = gossipQuests()
  if #options == 0 and #available + #active == 1 then
    local turnIn = #active == 1
    local quest = available[1] or active[1]
    if turnIn and not quest.isComplete then return end -- nothing to do there yet
    local id = quest.questID
    C_Timer.After(0, function()
      local o, a, t = gossipQuests()
      local now = turnIn and t[1] or a[1]
      if #o > 0 or #a + #t ~= 1 or not now or now.questID ~= id then return end
      if turnIn then
        self:Debug("dialog: only one quest, turning in %s (%s)", tostring(id), clean(now.title))
        C_GossipInfo.SelectActiveQuest(id)
      else
        self:Debug("dialog: only one quest, opening %s (%s)", tostring(id), clean(now.title))
        C_GossipInfo.SelectAvailableQuest(id)
      end
    end)
    return
  end
  if #options ~= 1 or options[1].selectOptionWhenOnlyOption or #available + #active > 0 then return end
  local id = options[1].gossipOptionID
  -- next frame: GossipFrame handles this same event and would show itself again over the vendor window
  C_Timer.After(0, function()
    local now = C_GossipInfo.GetOptions() or {}
    if #now ~= 1 or now[1].gossipOptionID ~= id then return end
    self:Debug("dialog: only one option, selecting %s (%s)", tostring(id), clean(now[1].name))
    C_GossipInfo.SelectOption(id)
  end)
end)

MF:On("QUEST_PROGRESS", function(self)
  currentNpc()
  retry(self)
end)
MF:On("QUEST_COMPLETE", function(self)
  currentNpc()
  if reward.questID ~= GetQuestID() then reward.picked = 0 end
  reward.questID = GetQuestID()
  reward.open = true
  reward.items = {}
  for i = 1, GetNumQuestChoices() do
    reward.items[i] = tonumber((GetQuestItemLink("choice", i) or ""):match("item:(%d+)")) or 0
  end
  hookButtons()
  C_Timer.After(0, hookButtons) -- the buttons may only be created after this event
  C_Timer.After(0.5, hookButtons)
  self:Debug("dialog: quest %d offers %d reward choices", reward.questID, #reward.items)
  retry(self)
end)
-- Next frame: the GetQuestReward hook runs after the call, which may already have closed the dialog.
MF:On("QUEST_FINISHED", function()
  C_Timer.After(0, function() if not shown("QuestFrameRewardPanel") then reward.open = false end end)
end)
MF:On("TAXIMAP_OPENED", function(self)
  currentNpc()
  wipe(taxiNames)
  for i = 1, NumTaxiNodes() do taxiNames[i] = TaxiNodeName(i) end
  retry(self)
end)

-- A quest picked in the lead's gossip or quest greeting is noticed from the quest dialog it opens rather than with
-- hooks: a quest addon may call a function it kept a reference to before our hooks were in (RestedXP's auto turn in
-- does, with C_GossipInfo.SelectActiveQuest).
local GOSSIP_QUEST_SECONDS = 2 -- the quest dialog opens right after the gossip closes
local gossipVerbs = {} -- questID -> verb ("qa" available, "qc" active) in the gossip/greeting we have (or just had) open
local gossipClosedAt -- nil while the gossip/greeting is open

MF:On("GOSSIP_SHOW", function()
  wipe(gossipVerbs)
  gossipClosedAt = nil
  for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do gossipVerbs[q.questID] = "qa" end
  for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do gossipVerbs[q.questID] = "qc" end
end)
MF:On("GOSSIP_CLOSED", function() gossipClosedAt = GetTime() end)

-- Quest greeting: the quest frame listing an NPC's quests (instead of a gossip), with quests picked by index.
MF:On("QUEST_GREETING", function(self)
  currentNpc()
  wipe(gossipVerbs)
  gossipClosedAt = nil
  for i = 1, GetNumAvailableQuests() do
    local id = select(5, GetAvailableQuestInfo(i))
    if id then gossipVerbs[id] = "qa" end
  end
  for i = 1, GetNumActiveQuests() do
    local id = GetActiveQuestID(i)
    if id then gossipVerbs[id] = "qc" end
  end
  self:Debug("dialog: quest greeting with %d available and %d active quests", GetNumAvailableQuests(),
             GetNumActiveQuests())
  retry(self)
end)
MF:On("QUEST_FINISHED", function() if not shown("GossipFrame") then gossipClosedAt = gossipClosedAt or GetTime() end end)

local function questOpened(self)
  local id = GetQuestID()
  local verb = gossipVerbs[id]
  local recent = not gossipClosedAt or GetTime() - gossipClosedAt < GOSSIP_QUEST_SECONDS
  wipe(gossipVerbs) -- only the first quest dialog comes from the gossip (not the follow-up offered after a turn in)
  if not iAmLead(self) then return end
  self:Debug("dialog: quest %s opened (gossip pick: %s, gossip closed %s)", tostring(id), tostring(verb),
             gossipClosedAt and ("%.1fs ago"):format(GetTime() - gossipClosedAt) or "no")
  if verb and recent then send(self, verb, id, "") end
end
MF:On("QUEST_DETAIL", questOpened, true) -- before the auto accept (Actions.lua), which clears GetQuestID()
MF:On("QUEST_PROGRESS", questOpened)
MF:On("QUEST_COMPLETE", questOpened)

-- The lead's other choices, noticed with secure hooks right after the Blizzard UI made them.
MF:Listen("LOGIN", function(self)
  -- The options are read from the cache: the dialog may already be closed (flight master) when the hook runs.
  hooksecurefunc(C_GossipInfo, "SelectOption", function(id)
    self:Debug("dialog: hook SelectOption(%s)", tostring(id))
    local text
    for _, o in ipairs(gossipCache) do if o.gossipOptionID == id then text = o.name end end
    for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do if o.gossipOptionID == id then text = o.name end end
    send(self, "go", id, text)
  end)
  if C_GossipInfo.SelectOptionByIndex then
    hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(index)
      self:Debug("dialog: hook SelectOptionByIndex(%s)", tostring(index))
      sendGossipIndex(self, index)
    end)
  end
  hooksecurefunc("CompleteQuest",
                 function() if shown("QuestFrameProgressPanel") then send(self, "qp", GetQuestID(), "") end end)
  if _G.QuestInfoItem_OnClick then
    hooksecurefunc("QuestInfoItem_OnClick",
                   function(b) if b and b.type == "choice" then setPicked(b:GetID(), "QuestInfoItem_OnClick") end end)
  end
  hooksecurefunc("GetQuestReward", function(choice)
    if reward.questID == 0 then return end
    if not reward.open then -- a quest addon calling it blindly (seen with RestedXP)
      self:Debug("dialog: GetQuestReward(%s) with no quest reward dialog open: not mirrored", tostring(choice))
      return
    end
    send(self, "qr", reward.questID, tostring(choice and choice > 0 and reward.items[choice] or 0))
  end)
  hooksecurefunc("TakeTaxiNode", function(index)
    self:Debug("dialog: hook TakeTaxiNode(%s) %s", tostring(index), tostring(taxiNames[index] or TaxiNodeName(index)))
    send(self, "tx", 0, taxiNames[index] or TaxiNodeName(index))
  end)
  -- Every popup button click goes through StaticPopup_OnClick; dialog.which is still set after it closed.
  hooksecurefunc("StaticPopup_OnClick", function(dialog, index)
    local which = dialog and dialog.which or ""
    local button = dialog and dialog.GetButton and dialog:GetButton(index)
    self:Debug("dialog: popup button %s clicked: %s", tostring(index), popupChoice(which, button))
    if mirroredPopup(which) then send(self, "pp", index, popupChoice(which, button)) end
  end)
  hooksecurefunc("StaticPopup_Show", function(which)
    self:Debug("dialog: popup %s shown", tostring(which))
    retry(self)
  end)
end)

MF:AddCommand("dialog", function(self, rest)
  self.db.autoDialog = self:ParseOnOff(rest, self.db.autoDialog)
  self:Print("mirroring the lead's dialog choices (gossip, quests, flight paths, popups) is now %s",
             tostring(self.db.autoDialog))
end, "dialog [on|off] - make the other windows pick the same dialog options/flight path/popup button as the lead")

MF:AddCommand("gossip", function(self, rest)
  self.db.autoGossip = self:ParseOnOff(rest, self.db.autoGossip)
  self:Print("picking the only option of NPC dialogs (vendors, trainers...) is now %s", tostring(self.db.autoGossip))
end, "gossip [on|off] - pick the only option of an NPC dialog (straight to the vendor, trainer...)")
