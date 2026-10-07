--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Professions: each window tells the team its own professions (there is no API to inspect someone else's).
-- "P;id:rank,id:rank" (skill line IDs) is whispered once to each team member we first hear from directly, sent to the
-- team again only when a profession is learned/dropped or a rank moves to another 25 point step, and on request ("Q;").
local _, MF = ...

MF.PROF = {
  ALCHEMY = 171,
  BLACKSMITHING = 164,
  ENCHANTING = 333,
  ENGINEERING = 202,
  HERBALISM = 182,
  LEATHERWORKING = 165,
  MINING = 186,
  SKINNING = 393,
  TAILORING = 197,
  COOKING = 185,
  FIRST_AID = 129,
  FISHING = 356
}

-- English fallback names for other characters' professions (our own come localized from GetProfessionInfo).
local NAMES = {
  [171] = "Alchemy",
  [164] = "Blacksmithing",
  [333] = "Enchanting",
  [202] = "Engineering",
  [182] = "Herbalism",
  [165] = "Leatherworking",
  [186] = "Mining",
  [393] = "Skinning",
  [197] = "Tailoring",
  [185] = "Cooking",
  [129] = "First Aid",
  [356] = "Fishing"
}

local STEP = 25 -- rank changes within the same step aren't worth a message

-- {[skillLineID] = rank} for this character.
function MF:MyProfessions()
  local profs = {}
  for _, index in pairs({GetProfessions()}) do
    local name, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
    if skillLine then
      profs[skillLine] = rank
      NAMES[skillLine] = name
    end
  end
  return profs
end

local function encode(profs)
  local ids = {}
  for id in pairs(profs) do ids[#ids + 1] = id end
  table.sort(ids)
  local parts = {}
  for i, id in ipairs(ids) do parts[i] = id .. ":" .. profs[id] end
  return table.concat(parts, ",")
end

local function decode(text)
  local profs = {}
  for id, rank in text:gmatch("(%d+):(%d+)") do profs[tonumber(id)] = tonumber(rank) end
  return profs
end

-- Same as encode but with ranks rounded down to STEP: what decides whether a change is worth telling the team.
local function signature(profs)
  local rounded = {}
  for id, rank in pairs(profs) do rounded[id] = rank - rank % STEP end
  return encode(rounded)
end

-- name -> {[skillLineID] = rank} for this faction's team (us included), remembered across sessions.
function MF:TeamProfessions()
  self.db.profs = self.db.profs or {}
  self.db.profs[self.faction] = self.db.profs[self.faction] or {}
  return self.db.profs[self.faction]
end

function MF:ProfessionsOf(name) return self:TeamProfessions()[name] end

function MF:ProfessionsText(name)
  local profs = self:ProfessionsOf(name)
  if not profs then return nil end
  local ids = {}
  for id in pairs(profs) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (NAMES[a] or "") < (NAMES[b] or "") end)
  local parts = {}
  for i, id in ipairs(ids) do parts[i] = ("%s %d"):format(NAMES[id] or ("skill " .. id), profs[id]) end
  return #parts > 0 and table.concat(parts, ", ") or "none"
end

local lastSignature

local function refreshOwn(self)
  local profs = self:MyProfessions()
  self:TeamProfessions()[self.myName] = profs
  return profs
end

function MF:SendProfessions(to, why)
  local profs = refreshOwn(self)
  lastSignature = signature(profs)
  local payload = "P;" .. encode(profs)
  if to then
    self:SendWhisper(to, payload, why)
  else
    self:SendTeam(payload)
  end
end

MF.messageHandlers.P = function(self, sender, rest)
  local profs = decode(rest)
  self:TeamProfessions()[sender] = profs
  self:Debug("professions of %s: %s", sender, self:ProfessionsText(sender))
  self:Fire("PROFESSIONS", sender)
end

MF.messageHandlers.Q = function(self, sender) self:SendProfessions(sender, "they asked") end

function MF:AskProfessions(name) self:SendWhisper(name, "Q;", "need their professions") end

MF:Listen("LOGIN", function(self) lastSignature = signature(refreshOwn(self)) end)

-- A team member we just heard from directly (login, reload, first contact) gets ours once.
MF:Listen("MEMBER_SEEN", function(self, name) self:SendProfessions(name, "first contact") end)

local changePending
MF:On("SKILL_LINES_CHANGED", function(self)
  if changePending or not self.myName then return end
  changePending = true
  C_Timer.After(10, function() -- fires in bursts (and on every skill point while leveling)
    changePending = nil
    local profs = refreshOwn(self)
    local sig = signature(profs)
    if sig == lastSignature then return end
    self:Debug("professions changed: %s -> %s", tostring(lastSignature), sig)
    self:SendProfessions(nil)
  end)
end)

MF:AddCommand("profs", function(self, rest)
  if rest:lower() == "sync" then
    self:SendTeam("Q;")
    self:SendProfessions(nil)
    self:Print("asked the team for their professions")
    return
  end
  refreshOwn(self)
  local slots = {}
  for s in pairs(self.db.slots) do slots[#slots + 1] = s end
  table.sort(slots)
  for _, s in ipairs(slots) do
    local name = self.db.slots[s]
    self:Print("%d %s: %s", s, name, self:ProfessionsText(name) or "unknown (try /mama profs sync)")
  end
  if #slots == 0 then self:Print("%s: %s", self.myName, self:ProfessionsText(self.myName)) end
end, "profs [sync] - list the team's professions (sync: ask everyone again)")
