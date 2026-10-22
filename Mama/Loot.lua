--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Loot: help for master loot (masterLoot option; free for all stays the automatic team loot, see UpdateLoot). When
-- master loot is picked in the group menu, the leader lowers the threshold to greys once. The master looter's window
-- then gives each item to the team member who uses it: mats and recipes to the best profession holder (trade
-- categories), armor to the classes that wear that type, weapons to the classes that can use them (taking turns),
-- greens nobody uses to the enchanter, the rest (greys, sell list...) to the most free bag slots. BoP items wait in a
-- picker, suggestion first: there may be other candidates, or the enchanter should disenchant it. Clicking an item in
-- the loot window shows the picker too (when the client doesn't show its own candidate list).
local _, MF = ...

local MASTER = Enum.LootMethod.Masterlooter
local ARMOR, WEAPON, QUEST_CLASS = 4, 2, 12
local BOP, QUEST = 1, 4 -- C_Item.GetItemInfo bindType
local POOR = 0
local MAX_CANDIDATES = 40
local GIVE_DELAY = 0.15 -- between automatic gives

local ARMOR_NAMES = {[1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate"}

-- Best armor type of a class at a level: mail at 40 for hunters and shamans, plate at 40 for warriors and paladins.
local function bestArmor(class, level)
  if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then return 1 end
  if class == "DRUID" or class == "ROGUE" then return 2 end
  if class == "HUNTER" or class == "SHAMAN" then return level >= 40 and 3 or 2 end
  if class == "WARRIOR" or class == "PALADIN" then return level >= 40 and 4 or 3 end
end

local function set(...)
  local t = {}
  for _, v in ipairs({...}) do t[v] = true end
  return t
end

-- Shields and relics (armor subclasses).
local CLASS_ARMOR = {
  [6] = set("WARRIOR", "PALADIN", "SHAMAN"), -- shield
  [7] = set("PALADIN"), -- libram
  [8] = set("DRUID"), -- idol
  [9] = set("SHAMAN") -- totem
}

-- Weapon subclass -> classes that can learn it.
local WEAPONS = {
  [0] = set("WARRIOR", "PALADIN", "HUNTER", "SHAMAN"), -- one handed axe
  [1] = set("WARRIOR", "PALADIN", "HUNTER", "SHAMAN"), -- two handed axe
  [2] = set("WARRIOR", "HUNTER", "ROGUE"), -- bow
  [3] = set("WARRIOR", "HUNTER", "ROGUE"), -- gun
  [4] = set("WARRIOR", "PALADIN", "ROGUE", "PRIEST", "SHAMAN", "DRUID"), -- one handed mace
  [5] = set("WARRIOR", "PALADIN", "SHAMAN", "DRUID"), -- two handed mace
  [6] = set("WARRIOR", "PALADIN", "HUNTER"), -- polearm
  [7] = set("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "MAGE", "WARLOCK"), -- one handed sword
  [8] = set("WARRIOR", "PALADIN", "HUNTER"), -- two handed sword
  [10] = set("WARRIOR", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"), -- staff
  [13] = set("WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "DRUID"), -- fist
  [15] = set("WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"), -- dagger
  [16] = set("WARRIOR", "HUNTER", "ROGUE"), -- thrown
  [18] = set("WARRIOR", "HUNTER", "ROGUE"), -- crossbow
  [19] = set("PRIEST", "MAGE", "WARLOCK") -- wand
}

-- 2: made for this class (its best armor type, its shield or relic), 1: can use it (weapons, lighter armor), 0: can't,
-- nil: not equipment, or anyone can use it (rings, cloaks...).
local function fit(it, class, level)
  if it.class == WEAPON then
    local classes = WEAPONS[it.sub]
    if not classes then return nil end
    return classes[class] and 1 or 0
  end
  if it.class ~= ARMOR or it.equipLoc == "INVTYPE_CLOAK" then return nil end
  if CLASS_ARMOR[it.sub] then return CLASS_ARMOR[it.sub][class] and 2 or 0 end
  if not ARMOR_NAMES[it.sub] then return nil end
  local best = bestArmor(class, math.max(level, it.minLevel or 0)) -- BoE for later: who will wear it then
  if not best then return nil end
  if it.sub == best then return 2 end
  return it.sub < best and 1 or 0
end

local function fitText(it, f)
  if f == 2 then return ARMOR_NAMES[it.sub] and ("wears " .. ARMOR_NAMES[it.sub]) or "class item" end
  if f == 1 then return "can use" end
  if f == 0 then return "can't use" end
end

-- Loot window slot -> {link, name, id, class, sub, equipLoc, quality, minLevel, bindType (nil: not cached), quest}.
local function slotItem(slot)
  if GetLootSlotType(slot) ~= Enum.LootSlotType.Item then return end
  local link = GetLootSlotLink(slot)
  if not link then return end
  local _, name, quantity, _, quality, _, isQuestItem = GetLootSlotInfo(slot)
  local id, _, _, equipLoc, _, class, sub = C_Item.GetItemInfoInstant(link)
  local _, _, _, _, minLevel, _, _, maxStack, _, _, _, _, _, bindType = C_Item.GetItemInfo(link)
  if not bindType then C_Item.RequestLoadItemDataByID(id) end
  return {
    slot = slot,
    link = link,
    name = name,
    count = quantity or 1,
    id = id,
    class = class,
    sub = sub,
    equipLoc = equipLoc,
    quality = quality or 1,
    minLevel = minLevel,
    maxStack = maxStack,
    bindType = bindType,
    quest = isQuestItem or bindType == QUEST or class == QUEST_CLASS
  }
end

-- Candidate names may be just the first name: look them up both ways.
local function unitsByName(self)
  local byName = {}
  local function add(u)
    local full = self:FullName(u)
    if not full then return end
    byName[full] = u
    local first = UnitName(u)
    if first and not byName[first] then byName[first] = u end
  end
  add("player")
  for _, u in ipairs(self:GroupUnits()) do add(u) end
  return byName
end

-- Who can receive the item in this loot slot: {index, name, unit, class, level, slot (nil: not on the team)}.
local function candidates(self, lootSlot)
  local byName, list = unitsByName(self), {}
  if not GetMasterLootCandidate then
    self:Error("no GetMasterLootCandidate on this client")
    return list
  end
  for i = 1, MAX_CANDIDATES do
    local c = GetMasterLootCandidate(lootSlot, i)
    if c then
      local u = byName[c]
      local name = u and self:FullName(u) or c
      local class = u and select(2, UnitClass(u))
      list[#list + 1] = {
        index = i,
        name = name,
        unit = u,
        class = class,
        level = u and UnitLevel(u) or 0,
        slot = self:SlotOf(name)
      }
    end
  end
  return list
end

local function freeSlots(self, name)
  local s = self:StatsOf(name)
  return s and s.free or -1
end

local given = {} -- rule key -> name -> items given this session: equal candidates take turns

local function bySlot(a, b) return (a.slot or 99) < (b.slot or 99) end

local function takeTurns(key, list)
  local count = given[key] or {}
  table.sort(list, function(a, b)
    local ca, cb = count[a.name] or 0, count[b.name] or 0
    if ca ~= cb then return ca < cb end
    return bySlot(a, b)
  end)
  return list[1]
end

local function mostFree(self, team)
  local best
  for _, m in ipairs(team) do
    if not best or freeSlots(self, m.name) > freeSlots(self, best.name) or
      (freeSlots(self, m.name) == freeSlots(self, best.name) and bySlot(m, best)) then best = m end
  end
  return best
end

local function canDisenchant(self, it)
  return (it.class == WEAPON or it.class == ARMOR) and it.quality >= 2 and it.quality <= 4 and
           not self.NO_DISENCHANT[it.id] and self:TradeCategoryOn("greens", true)
end

-- The team member (among the candidates) who should get it: candidate, reason, rule key (for taking turns).
function MF:LootRecipient(it, cands)
  local team, members = {}, {}
  for _, c in ipairs(cands) do
    if c.slot then
      team[#team + 1] = c
      members[c.name] = c.slot
    end
  end
  if #team == 0 then return end
  local function named(name) for _, m in ipairs(team) do if m.name == name then return m end end end
  -- mats and recipes: the best profession holder (as for trades; BoE greens are below)
  for _, c in ipairs(self.tradeCategories) do
    local key, label, default, match, to = c[1], c[2], c[3], c[4], c[5]
    if key ~= "greens" and match(it) then
      if not self:TradeCategoryOn(key, default) then break end
      local best = self:BestHolder(type(to) == "function" and to(it) or to, members)
      if best then return named(best), label end
      break
    end
  end
  -- equipment: who it's made for, then who can use it
  local best, bestFit = {}, 0
  for _, m in ipairs(team) do
    local f = fit(it, m.class or "", m.level)
    if f and f > 0 then
      if f > bestFit then
        best, bestFit = {m}, f
      elseif f == bestFit then
        best[#best + 1] = m
      end
    end
  end
  if bestFit > 0 then
    local key = ("fit:%d:%d"):format(it.class, it.sub)
    return takeTurns(key, best), fitText(it, bestFit), key
  end
  if canDisenchant(self, it) then
    local enchanter = self:BestHolder({self.PROF.ENCHANTING}, members)
    if enchanter then return named(enchanter), "disenchant" end
  end
  local sell = it.quality == POOR or self:VendorList().items[it.id]
  return mostFree(self, team), sell and "to sell, most bag space" or "most bag space"
end

-- Quest items: who still needs one comes from the quests' party progress (what the quest tracker's tooltip shows:
-- a first name line, then that character's objectives), for the quests in our own log.

-- "Tough Wolf Meat: 3/8", "- 3/8 Tough Wolf Meat" -> "Tough Wolf Meat"
local function objectiveItem(text)
  local name = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*", "", 1):gsub("^[%s%-]+", ""):gsub("%s+$", "")
  return name ~= "" and name or nil
end

local LINE = Enum.TooltipDataLineType or {}

-- Reads quest progress tooltip lines into needs (full name -> {have, need}, for those not done with item yet): a quest
-- title (our own objectives follow), a first name (that party member's objectives follow), objectives
-- ("2/8 Tough Wolf Meat"). Returns whether any objective was for item.
local function readProgress(self, lines, item, needs, byName)
  local who, known = nil, false
  for _, line in ipairs(lines or {}) do
    local text = (line.leftText or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local have, need = text:match("(%d+)%s*/%s*(%d+)")
    if line.type ~= nil and line.type == LINE.QuestTitle then
      who = self.myName
    elseif not have and byName[text] then
      who = self:FullName(byName[text])
    elseif have and objectiveItem(text) == item then
      known = true
      if who and tonumber(have) < tonumber(need) then needs[who] = {have = tonumber(have), need = tonumber(need)} end
    end
  end
  return known
end

-- The unit being looted, for its tooltip (it lists the party's progress on its quests, even ours we don't have).
local function lootUnit(slot)
  local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
  for _, u in ipairs({"softinteract", "mouseover", "target"}) do
    if UnitExists(u) and UnitIsDead(u) and (not guid or UnitGUID(u) == guid) then return u end
  end
end

-- Full name -> {have, need} for the group members (us included) on a quest needing this item, not done with it yet:
-- from the looted unit's tooltip, and the party progress of the quests in our log. Also returns whether any of those
-- has the item at all (if not, we can't know who needs it).
function MF:QuestNeeds(item, slot)
  local byName, needs, known = unitsByName(self), {}, false
  local u = lootUnit(slot)
  local data = u and C_TooltipInfo.GetUnit(u)
  if data and readProgress(self, data.lines, item, needs, byName) then known = true end
  self:Debug("quest item %s: looted unit %s, on its tooltip %s", item, tostring(u), tostring(known))
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    data = info and not info.isHeader and C_TooltipInfo.GetQuestPartyProgress(info.questID, true)
    if data and readProgress(self, data.lines, item, needs, byName) then known = true end
  end
  return needs, known
end

-- xp in the current level: ours, the others' from their stats (sent after money/bag changes, turn-ins included).
local function xpOf(self, name)
  if name == self.myName then return UnitXP("player") end
  local s = self:StatsOf(name)
  return s and s.xp or 0
end

-- Furthest behind first (level, then xp), then us (the looter), then slot order.
local function behind(self, a, b)
  if a.level ~= b.level then return a.level < b.level end
  local xa, xb = xpOf(self, a.name), xpOf(self, b.name)
  if xa ~= xb then return xa < xb end
  if a.name == self.myName or b.name == self.myName then return a.name == self.myName end
  return bySlot(a, b)
end

-- The candidate who still needs this quest item and is furthest behind (so they finish the quest first), and the
-- reason. nil: nobody needs it. needs: from QuestNeeds.
function MF:QuestItemRecipient(cands, needs)
  local best
  for _, c in ipairs(cands) do if needs[c.name] and (not best or behind(self, c, best)) then best = c end end
  if not best then return end
  local w = needs[best.name]
  return best, ("quest %d/%d, furthest behind"):format(w.have, w.need)
end

-- What the picker shows next to each candidate (needs, known: QuestNeeds for a quest item).
local function noteFor(self, it, m, needs, known)
  local parts = {}
  if m.class then
    parts[1] = ("%s %d"):format(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.class] or m.class, m.level)
  end
  if needs then
    local w = needs[m.name]
    parts[#parts + 1] = w and ("quest %d/%d"):format(w.have, w.need) or (known and "doesn't need it") or
                          "quest progress unknown"
  end
  local f = fit(it, m.class or "", m.level)
  if f then parts[#parts + 1] = fitText(it, f) end
  local profs = self:ProfessionsOf(m.name)
  if profs and profs[self.PROF.ENCHANTING] and canDisenchant(self, it) then
    parts[#parts + 1] = "Enchanting " .. profs[self.PROF.ENCHANTING]
  end
  local free = freeSlots(self, m.name)
  if free >= 0 then parts[#parts + 1] = free .. " free" end
  if not m.slot then parts[#parts + 1] = "not on the team" end
  return table.concat(parts, ", ")
end

function MF:IsMasterLooter()
  local method, partyID, raidID = C_PartyInfo.GetLootMethod()
  if method ~= MASTER then return false end
  if raidID then return UnitIsUnit("raid" .. raidID, "player") end
  return partyID == 0
end

local lootOpen = false
local queue = {} -- automatic gives: {it, m, why, key}
local picks = {} -- items waiting for a click in the picker
local picker -- the picker window, built on first use

-- Quest items that don't stack (heads...) drop once per player on the quest: we only see our own copy, the others
-- have to loot theirs by hand. A guess (nothing in the API tells), good for the usual unique quest drops.
local function perPlayer(it) return it.quest and it.maxStack == 1 end
local reminders = {} -- per player quest items given from this loot: who else needs one is told to loot it on close

local function give(self, it, m, why, key)
  if GetLootSlotLink(it.slot) ~= it.link then return false end -- already looted
  self:Print("loot: %s%s to %s%s", it.link, it.count > 1 and ("x" .. it.count) or "", m.name,
             why and (" (" .. why .. ")") or "")
  GiveMasterLoot(it.slot, m.index)
  if perPlayer(it) then reminders[it.name] = true end
  if key then
    given[key] = given[key] or {}
    given[key][m.name] = (given[key][m.name] or 0) + 1
  end
  return true
end

local function giveNext(self)
  local g = table.remove(queue, 1)
  if not g or not lootOpen then return end
  give(self, g.it, g.m, g.why, g.key)
  C_Timer.After(GIVE_DELAY, function() giveNext(self) end)
end

local showPick

-- Gives the automatic items, queues the BoP ones (and the ones not cached after a few tries) for the picker.
function MF:DistributeLoot(tries)
  if not lootOpen then return end
  tries = tries or 0
  local items, uncached = {}, false
  local threshold = GetLootThreshold()
  for slot = 1, GetNumLootItems() do
    local it = slotItem(slot)
    if it and (it.quest or it.quality >= threshold) then
      items[#items + 1] = it
      if not it.bindType and not it.quest then uncached = true end
    end
  end
  if uncached and tries < 3 then
    C_Timer.After(0.3, function() self:DistributeLoot(tries + 1) end)
    return
  end
  wipe(queue)
  wipe(picks)
  local questNeeds = {} -- item name -> QuestNeeds, counting what we give now (the next slot may hold the same item)
  for _, it in ipairs(items) do
    local cands = candidates(self, it.slot)
    self:Debug("loot slot %d %s bind %s, %d candidates", it.slot, it.link, tostring(it.bindType), #cands)
    if #cands > 0 then
      if it.quest then
        if not questNeeds[it.name] then questNeeds[it.name] = {self:QuestNeeds(it.name, it.slot)} end
        local needs, known = questNeeds[it.name][1], questNeeds[it.name][2]
        local list = {}
        for n, w in pairs(needs) do list[#list + 1] = ("%s %d/%d"):format(n, w.have, w.need) end
        self:Debug("quest item %s: in our quests %s, needed by %s", it.name, tostring(known), table.concat(list, ", "))
        local m, why = self:QuestItemRecipient(cands, needs)
        if perPlayer(it) and needs[self.myName] then -- our own copy: the others loot theirs
          for _, c in ipairs(cands) do if c.name == self.myName then m, why = c, "quest, our own copy" end end
        end
        if m then
          queue[#queue + 1] = {it = it, m = m, why = why}
          local w = needs[m.name]
          w.have = w.have + it.count
          if w.have >= w.need then needs[m.name] = nil end
        elseif not known then
          picks[#picks + 1] = it -- not one of our quests: who needs it is unknown, ask
        else
          self:Print("loot: nobody needs %s for a quest, left in the loot", it.link)
        end
      elseif not it.bindType or it.bindType == BOP then
        picks[#picks + 1] = it
      else
        local m, why, key = self:LootRecipient(it, cands)
        if m then queue[#queue + 1] = {it = it, m = m, why = why, key = key} end
      end
    end
  end
  giveNext(self)
  if #picks > 0 then showPick(self) end
end

MF:On("LOOT_OPENED", function(self)
  lootOpen = true
  if not self.db.masterLoot or self:Disabled() or not self:IsMasterLooter() then return end
  if IsModifierKeyDown() then -- this loot by hand (clicking an item still shows the picker)
    self:Debug("modifier held: no automatic loot distribution")
    return
  end
  C_Timer.After(0.1, function() self:DistributeLoot() end)
end)

MF:On("LOOT_CLOSED", function(self)
  lootOpen = false
  wipe(queue)
  wipe(picks)
  if picker then picker:Hide() end
  -- the corpse is free now: whoever still needs one of these loots their own copy
  for item in pairs(reminders) do
    self:Debug("reminding the group to loot %s themselves", item)
    self:SendGroup("R;" .. item)
  end
  wipe(reminders)
end)

local function iNeed(item)
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader then
      for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
        if not o.finished and objectiveItem(o.text or "") == item then return true end
      end
    end
  end
  return false
end

-- "R;Item name": the master looter got its copy of a per player quest item, loot ours if we need it.
MF.messageHandlers.R = function(self, sender, rest)
  if rest == "" or self:IsAway() or not iNeed(rest) then return end
  local msg = ("Loot %s from the corpse (%s got theirs)"):format(rest, sender)
  self:Print("|cFFFF4040%s|r", msg)
  RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo.RAID_WARNING)
  PlaySound(SOUNDKIT.RAID_WARNING)
end

MF:On("LOOT_SLOT_CLEARED", function(self, slot)
  if picker and picker:IsShown() and picker.it and picker.it.slot == slot then showPick(self) end
end)

-- An item clicked in the loot window: the picker, unless the client shows its own candidate list.
MF:On("OPEN_MASTER_LOOT_LIST", function(self)
  local slot = LootFrame and LootFrame.selectedSlot
  local it = slot and slotItem(slot)
  if not it then return end
  C_Timer.After(0, function()
    local blizzard = _G.MasterLooterFrame
    self:Debug("master loot list for slot %d, client frame %s", slot,
               blizzard and (blizzard:IsShown() and "shown" or "hidden") or "missing")
    if blizzard and blizzard:IsShown() then return end
    for i, p in ipairs(picks) do if p.slot == slot then table.remove(picks, i) end end
    table.insert(picks, 1, it)
    showPick(self)
  end)
end)

-- Picker window

local ROW_H = 22
local WIDTH = 330

local function buildPicker()
  local f = CreateFrame("Frame", "MamaForeverLootPicker", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(WIDTH, 100)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetText("Mama: give loot to")
  local item = CreateFrame("Button", nil, f)
  item:SetHeight(28)
  item:SetPoint("TOPLEFT", 12, -28)
  item:SetPoint("TOPRIGHT", -12, -28)
  item.icon = item:CreateTexture(nil, "ARTWORK")
  item.icon:SetSize(26, 26)
  item.icon:SetPoint("LEFT")
  item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
  item.text:SetPoint("RIGHT")
  item.text:SetJustifyH("LEFT")
  item.text:SetWordWrap(false)
  item:SetScript("OnEnter", function(b)
    if not f.it then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(f.it.link)
    GameTooltip:Show()
  end)
  item:SetScript("OnLeave", GameTooltip_Hide)
  f.item = item
  f.rows = {}
  local skip = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  skip:SetSize(80, 22)
  skip:SetPoint("BOTTOMRIGHT", -12, 10)
  skip:SetText("Skip")
  skip:SetScript("OnClick", function() showPick(MF) end)
  f.skip = skip
  f.left = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.left:SetPoint("BOTTOMLEFT", 14, 16)
  -- the close button: leave the rest in the loot window
  f.CloseButton:SetScript("OnClick", function()
    wipe(picks)
    f:Hide()
  end)
  return f
end

local function getRow(f, i)
  if f.rows[i] then return f.rows[i] end
  local r = CreateFrame("Button", nil, f)
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -4 - (i - 1) * ROW_H)
  r:SetPoint("TOPRIGHT", f.item, "BOTTOMRIGHT", 0, -4 - (i - 1) * ROW_H)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("LEFT", 4, 0)
  r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.note:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
  r.note:SetPoint("RIGHT", -4, 0)
  r.note:SetJustifyH("LEFT")
  r.note:SetWordWrap(false)
  r.mark = r:CreateTexture(nil, "BACKGROUND")
  r.mark:SetAllPoints()
  r.mark:SetColorTexture(0.6, 0.9, 1, 0.15)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.15)
  f.rows[i] = r
  return r
end

-- Shows the next waiting item (hides the picker when there's none left or the loot window closed).
showPick = function(self)
  picker = picker or buildPicker()
  local f, it = picker, nil
  while #picks > 0 and not it do
    local p = table.remove(picks, 1)
    if lootOpen and GetLootSlotLink(p.slot) == p.link then it = p end
  end
  local cands = it and candidates(self, it.slot) or {}
  if #cands == 0 then
    f.it = nil
    f:Hide()
    return
  end
  f.it = it
  local suggested, why, needs, known
  if it.quest then
    needs, known = self:QuestNeeds(it.name, it.slot)
    suggested, why = self:QuestItemRecipient(cands, needs)
  else
    suggested, why = self:LootRecipient(it, cands)
  end
  table.sort(cands, function(a, b)
    if a == suggested or b == suggested then return a == suggested end
    if (a.slot ~= nil) ~= (b.slot ~= nil) then return a.slot ~= nil end
    return bySlot(a, b)
  end)
  f.item.icon:SetTexture(C_Item.GetItemIconByID(it.id))
  f.item.text:SetText(it.link .. (it.count > 1 and (" x" .. it.count) or ""))
  for i, m in ipairs(cands) do
    local r = getRow(f, i)
    local color = m.class and RAID_CLASS_COLORS[m.class]
    r.name:SetText(color and color:WrapTextInColorCode(m.name) or m.name)
    local note = noteFor(self, it, m, needs, known)
    if m == suggested then note = "|cFF99E5FFsuggested: " .. why .. "|r, " .. note end
    r.note:SetText(note)
    r.mark:SetShown(m == suggested)
    r:SetScript("OnClick", function()
      give(self, it, m, m == suggested and why or "picked")
      showPick(self)
    end)
    r:Show()
  end
  for i = #cands + 1, #f.rows do f.rows[i]:Hide() end
  f.left:SetText(#picks > 0 and (#picks .. " more after this one") or "")
  f:SetHeight(28 + 28 + 4 + #cands * ROW_H + 42)
  if not f:IsShown() then
    f:ClearAllPoints()
    if LootFrame and LootFrame:IsShown() then
      f:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
    else
      f:SetPoint("CENTER", 0, 100)
    end
  end
  f:Show()
end

-- Loot method

local function masterLooterName(self)
  local method, partyID, raidID = C_PartyInfo.GetLootMethod()
  if method ~= MASTER then return end
  if raidID then return self:FullName("raid" .. raidID) end
  if partyID then return partyID == 0 and self.myName or self:FullName("party" .. partyID) end
end

-- Leader: when the loot method becomes master loot (picked in the group menu), greys and up, once: a threshold
-- raised again afterwards stays. The menu doesn't offer below uncommon.
local lastMethod -- nil until the first event (login, reload, joining a group): no change then
MF:On("PARTY_LOOT_METHOD_CHANGED", function(self)
  local method = C_PartyInfo.GetLootMethod()
  local was = lastMethod
  lastMethod = method
  if was == nil or method ~= MASTER or was == MASTER then return end
  if not self.db.masterLoot or self:Disabled() or not UnitIsGroupLeader("player") then return end
  if not SetLootThreshold then
    self:Error("can't set the loot threshold on this client")
    return
  end
  C_Timer.After(0.5, function()
    if GetLootThreshold() > POOR then
      self:Print("master loot to %s: greys and up", masterLooterName(self) or "?")
      SetLootThreshold(POOR)
    end
  end)
end)

MF:Listen("LOGIN", function() lastMethod = IsInGroup() and C_PartyInfo.GetLootMethod() or nil end)

MF:AddCommand("loot", function(self, rest)
  if rest ~= "" then self:SetOption("masterLoot", self:ParseOnOff(rest, self.db.masterLoot)) end
  self:Print("master loot auto distribution is %s; loot method %s, master looter %s, threshold %d",
             self.db.masterLoot and "on" or "off", tostring(C_PartyInfo.GetLootMethod()), masterLooterName(self) or "-",
             GetLootThreshold())
end, "loot [on|off] - as master looter (picked in the group menu; greys and up then), give items to who uses them" ..
                " (BoP after a click)")
