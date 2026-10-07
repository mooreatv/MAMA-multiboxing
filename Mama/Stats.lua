--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Stats: each window tells the team its gold and free bag slots ("G;copper;free;slots"), whispered once to each team
-- member we first hear from directly and sent again (debounced) when they change. Remembered per faction across
-- sessions, so characters not logged in (alts) still count, with their last known values.
local _, MF = ...

local DELAY = 5 -- seconds to wait after a change before telling the team (looting changes them in bursts)

-- name -> {money = copper, free = free bag slots, slots = bag slots, t = time()} for this faction.
function MF:TeamStats()
  self.db.stats = self.db.stats or {}
  self.db.stats[self.faction] = self.db.stats[self.faction] or {}
  return self.db.stats[self.faction]
end

function MF:StatsOf(name) return name and self:TeamStats()[name] end

-- Only general purpose bags count (a quiver or herb bag's free slots don't help with loot).
local function refreshOwn(self)
  local free, slots = 0, 0
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    local f, family = C_Container.GetContainerNumFreeSlots(bag)
    if n > 0 and (family or 0) == 0 then
      slots = slots + n
      free = free + (f or 0)
    end
  end
  local s = {money = GetMoney(), free = free, slots = slots, t = time()}
  self:TeamStats()[self.myName] = s
  return s
end

local function payload(s) return ("G;%d;%d;%d"):format(s.money, s.free, s.slots) end

local lastSent

function MF:SendStats(to, why)
  local p = payload(refreshOwn(self))
  if to then
    self:SendWhisper(to, p, why)
  else
    lastSent = p
    self:SendTeam(p, true)
  end
end

MF.messageHandlers.G = function(self, sender, rest)
  local money, free, slots = rest:match("^(%d+);(%d+);(%d+)$")
  if not money then return end
  self:TeamStats()[sender] = {money = tonumber(money), free = tonumber(free), slots = tonumber(slots), t = time()}
  self:Fire("STATS", sender)
end

local pending
local function changed(self)
  if not self.myName then return end
  refreshOwn(self)
  self:Fire("STATS", self.myName)
  if pending then return end
  pending = true
  C_Timer.After(DELAY, function()
    pending = nil
    local p = payload(refreshOwn(self))
    if p ~= lastSent and self.db.slot > 0 then self:SendStats(nil) end
  end)
end

MF:On("PLAYER_MONEY", changed)
MF:On("BAG_UPDATE_DELAYED", changed)
MF:Listen("LOGIN", function(self) lastSent = payload(refreshOwn(self)) end)
MF:Listen("MEMBER_SEEN", function(self, name) self:SendStats(name, "hello") end)

-- "12g 34s 56c" with coin colors; copper and silver are left out of large amounts.
function MF:MoneyText(copper)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "|cFFFFD700g|r" end
  if (s > 0 or g > 0) and g < 1000 then parts[#parts + 1] = s .. "|cFFC7C7CFs|r" end
  if g < 10 then parts[#parts + 1] = c .. "|cFFEDA55Fc|r" end
  return table.concat(parts, " ")
end

-- "5m", "3h", "2d" since time t.
function MF:AgeText(t)
  local d = math.max(0, time() - (t or 0))
  if d < 3600 then return math.floor(d / 60) .. "m" end
  if d < 86400 then return math.floor(d / 3600) .. "h" end
  return math.floor(d / 86400) .. "d"
end

-- Sum of the gold of the current slot holders (those we have stats for).
function MF:TeamMoney()
  local total = 0
  for _, name in pairs(self.db.slots) do
    local s = self:StatsOf(name)
    if s then total = total + s.money end
  end
  return total
end
