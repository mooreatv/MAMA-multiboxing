--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Trade: opening a trade with a team member puts the mats their professions use in the trade window (cloth to the
-- tailor, ore to the miner...). Each category goes to the best holder on the team (see Professions.lua), so mats only
-- move towards whoever will use them; the trade itself is still accepted by hand.
local _, MF = ...

local P = MF.PROF
local TRADE_SLOTS = 6 -- the 7th trade slot is "will not be traded"

-- Item class / subclass numbers (Enum.ItemTradeGoodsSubclass doesn't exist on Forever).
local TRADEGOODS, RECIPE, WEAPON, ARMOR = 7, 9, 2, 4
local PARTS, EXPLOSIVES, DEVICES, CLOTH, LEATHER, METAL_STONE, COOKING, HERB, ENCHANTING = 1, 2, 3, 5, 6, 7, 8, 9, 12

-- Ores share Metal & Stone with bars and stones: they go to the miner to smelt.
local ORES = {
  [2770] = true, -- Copper
  [2771] = true, -- Tin
  [2775] = true, -- Silver
  [2772] = true, -- Iron
  [2776] = true, -- Gold
  [3858] = true, -- Mithril
  [7911] = true, -- Truesilver
  [10620] = true, -- Thorium
  [11370] = true, -- Dark Iron
  [18562] = true -- Elementium
}

-- Recipe subclass -> profession.
local RECIPES = {
  [1] = P.LEATHERWORKING,
  [2] = P.TAILORING,
  [3] = P.ENGINEERING,
  [4] = P.BLACKSMITHING,
  [5] = P.COOKING,
  [6] = P.ALCHEMY,
  [7] = P.FIRST_AID,
  [8] = P.ENCHANTING,
  [9] = P.FISHING
}

local function tradeGoods(sub) return function(it) return it.class == TRADEGOODS and it.sub == sub end end

-- key, label, on by default, matcher, receiving professions in priority order (or a function of the item).
MF.tradeCategories = {
  {"cloth", "cloth", true, tradeGoods(CLOTH), {P.TAILORING}},
  {"leather", "leather and hides", true, tradeGoods(LEATHER), {P.LEATHERWORKING}}, {
    "ore", "ore", true, function(it) return it.class == TRADEGOODS and it.sub == METAL_STONE and ORES[it.id] end,
    {P.MINING}
  }, {
    "bars", "bars and stones", true,
    function(it) return it.class == TRADEGOODS and it.sub == METAL_STONE and not ORES[it.id] end,
    {P.BLACKSMITHING, P.ENGINEERING}
  }, {"herbs", "herbs", true, tradeGoods(HERB), {P.ALCHEMY}},
  {"enchanting", "enchanting mats", true, tradeGoods(ENCHANTING), {P.ENCHANTING}}, {
    "greens", "BoE greens (to disenchant)", true,
    function(it) return (it.class == WEAPON or it.class == ARMOR) and it.quality == 2 end, {P.ENCHANTING}
  }, {
    "parts", "engineering parts", true,
    function(it) return it.class == TRADEGOODS and (it.sub == PARTS or it.sub == EXPLOSIVES or it.sub == DEVICES) end,
    {P.ENGINEERING}
  }, {"cooking", "raw meat and fish", false, tradeGoods(COOKING), {P.COOKING}}, {
    "recipes", "recipes", false, function(it) return it.class == RECIPE and RECIPES[it.sub] end,
    function(it) return {RECIPES[it.sub]} end
  }
}

function MF:TradeCategoryOn(key, default)
  local v = self.db.tradeCats and self.db.tradeCats[key]
  if v == nil then return default end
  return v
end

-- The team member (us included) who should get mats for these professions: the first profession anyone on the team
-- has wins, then the highest rank; ties keep the mats where they are, then go to the lowest slot.
function MF:BestHolder(profs)
  local team = self:TeamProfessions()
  local members = {}
  for s, name in pairs(self.db.slots) do members[name] = s end
  members[self.myName] = 0 -- wins ties
  for _, prof in ipairs(profs) do
    local best, bestRank, bestSlot
    for name, slot in pairs(members) do
      local rank = team[name] and team[name][prof]
      if rank and (not best or rank > bestRank or (rank == bestRank and slot < bestSlot)) then
        best, bestRank, bestSlot = name, rank, slot
      end
    end
    if best then return best end
  end
end

-- Bag stacks that should go to partner: list of {bag, slot, count, label}, biggest stacks first.
function MF:MatsFor(partner)
  local list = {}
  local holders = {} -- cache: category key -> best holder (recipes vary per item, not cached)
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isBound and not info.isLocked then
        local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(info.itemID)
        local it = {id = info.itemID, class = class, sub = sub, quality = info.quality}
        for _, c in ipairs(self.tradeCategories) do
          local key, label, default, match, to = c[1], c[2], c[3], c[4], c[5]
          if self:TradeCategoryOn(key, default) and match(it) then
            local holder
            if type(to) == "function" then
              holder = self:BestHolder(to(it))
            else
              if holders[key] == nil then holders[key] = self:BestHolder(to) or false end
              holder = holders[key]
            end
            if holder == partner then
              list[#list + 1] = {bag = bag, slot = slot, count = info.stackCount, label = label}
            end
            break -- first matching category decides
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.count > b.count end)
  return list
end

local partner -- full name of the current trade partner, nil when no trade is open
local waitingFor -- partner whose professions we asked for, to fill once they answer

function MF:FillTrade(manual)
  if not partner then return end
  if partner == self.myName or not self:SlotOf(partner) then
    if manual then self:Print("%s isn't on the team", tostring(partner)) end
    return
  end
  if not self:ProfessionsOf(partner) then
    self:Print("asking %s for their professions", partner)
    waitingFor = partner
    self:AskProfessions(partner)
    return
  end
  local mats = self:MatsFor(partner)
  if #mats == 0 then
    if manual then self:Print("nothing for %s (%s)", partner, self:ProfessionsText(partner)) end
    return
  end
  local given, labels, seen = 0, {}, {}
  local tslot = 1
  for _, m in ipairs(mats) do
    while tslot <= TRADE_SLOTS and GetTradePlayerItemInfo(tslot) do tslot = tslot + 1 end
    if tslot > TRADE_SLOTS then break end
    ClearCursor()
    C_Container.PickupContainerItem(m.bag, m.slot)
    if not CursorHasItem() then
      self:Debug("couldn't pick up bag %d slot %d", m.bag, m.slot)
    else
      ClickTradeButton(tslot)
      ClearCursor()
      given = given + 1
      if not seen[m.label] then
        seen[m.label] = true
        labels[#labels + 1] = m.label
      end
    end
  end
  local left = #mats - given
  if given > 0 then self:Print("trade: %d stacks for %s (%s)", given, partner, table.concat(labels, ", ")) end
  if left > 0 then self:Print("%d more stacks for %s: trade again after this one", left, partner) end
end

MF:On("TRADE_SHOW", function(self)
  partner = self:FullName("NPC")
  waitingFor = nil
  self:Debug("trade with %s", tostring(partner))
  self.tradeButton:SetShown(not self.db.autoTrade) -- only needed when filling isn't automatic
  -- let the trade window settle before putting items in
  if self.db.autoTrade then C_Timer.After(0.3, function() self:FillTrade(false) end) end
end)

MF:On("TRADE_CLOSED", function()
  partner = nil
  waitingFor = nil
end)

MF:Listen("PROFESSIONS", function(self, name)
  if waitingFor and name == waitingFor and partner == name then
    waitingFor = nil
    self:FillTrade(true)
  end
end)

MF:Listen("LOGIN", function(self)
  local b = CreateFrame("Button", nil, TradeFrame, "UIPanelButtonTemplate")
  b:SetSize(120, 22)
  b:SetPoint("BOTTOMRIGHT", TradeFrame, "TOPRIGHT", 0, 2)
  b:SetText("Mama: give mats")
  b:SetScript("OnClick", function() self:FillTrade(true) end)
  b:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Give mats")
    GameTooltip:AddLine("Put the mats this team member's professions use in the trade (see /mama trade list).", 1, 1, 1,
                        true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  self.tradeButton = b
end)

MF:AddCommand("trade", function(self, rest)
  local key, setting = rest:lower():match("^(%S*)%s*(%S*)$")
  if key == "" or key == "on" or key == "off" then
    if key ~= "" then self.db.autoTrade = key == "on" end
    self:Print("auto fill trades with mats for team members is %s", tostring(self.db.autoTrade))
    return
  end
  if key ~= "list" then
    for _, c in ipairs(self.tradeCategories) do
      if c[1] == key then
        self.db.tradeCats = self.db.tradeCats or {}
        self.db.tradeCats[key] = self:ParseOnOff(setting, self:TradeCategoryOn(key, c[3]))
        self:Print("trading %s is now %s", c[2], tostring(self.db.tradeCats[key]))
        return
      end
    end
    self:Print("unknown category %q", key)
  end
  for _, c in ipairs(self.tradeCategories) do
    self:Print("  %s (%s): %s", c[1], c[2], self:TradeCategoryOn(c[1], c[3]) and "on" or "off")
  end
end, "trade [on|off|list|<category> [on|off]] - auto fill trades with mats for the team member who uses them")
