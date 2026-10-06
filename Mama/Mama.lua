--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --

-- Mama-forever: multiboxing assistant for WoW Forever (single addon, no libraries).
-- Derived from MoLib + DynamicBoxer + MAMA (LGPLv3).

local addonName, MF = ...
_G.MamaForever = MF

MF.prefix = "|cFF99E5FFMama:|r "
MF.defaults = {debug = false, macro = true, autoQuest = true, autoAccept = true, lead = false, slot = 0, token = false, showStatus = true,
                autoShare = true, autoAbandon = true, autoInvite = true, autoRaid = true, autoFFA = true, compact = false, identifyOnLogin = true,
                statusScale = 1}

function MF:Print(msg, ...)
  if select("#", ...) > 0 then msg = msg:format(...) end
  print(self.prefix .. msg)
end

function MF:Debug(msg, ...)
  if not (self.db and self.db.debug) then return end
  if select("#", ...) > 0 then msg = msg:format(...) end
  print("|cFF808080Mama debug:|r " .. msg)
end

-- Internal (non-Blizzard) callbacks between modules.
local listeners = {}
function MF:Listen(name, fn)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], fn)
end

function MF:Fire(name, ...)
  for _, fn in ipairs(listeners[name] or {}) do fn(self, ...) end
end

-- Blizzard events: any number of handlers per event, called as fn(MF, ...).
local frame = CreateFrame("Frame")
local handlers = {}
function MF:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(MF, ...) end
end)

MF:On("ADDON_LOADED", function(self, name)
  if name ~= addonName then return end
  MamaForeverSaved = MamaForeverSaved or {}
  local s = MamaForeverSaved.settings or {}
  MamaForeverSaved.settings = s
  for k, v in pairs(self.defaults) do
    if s[k] == nil then s[k] = v end
  end
  s.team = s.team or {} -- set of full names ("First Last") allowed to auto-invite us
  s.slots = s.slots or {} -- slot number -> character full name ("First Last"), learned from the team handshake
  self.db = s
end)

MF:On("PLAYER_LOGIN", function(self)
  self.myName = self:FullName("player")
  -- Team slots and the history of who held which slot are remembered per faction (the saved variables are account wide).
  self.faction = UnitFactionGroup("player") or "Neutral"
  local s = self.db
  s.slotsBy = s.slotsBy or {}
  s.slotsBy[self.faction] = s.slotsBy[self.faction] or {}
  s.slots = s.slotsBy[self.faction]
  s.history = s.history or {}
  s.history[self.faction] = s.history[self.faction] or {}
  if s.tokens then -- undo the short-lived per faction tokens: keep a single account wide one
    for f, t in pairs(s.tokens) do
      if not s.token then s.token, s.tokenFaction = t, f end
    end
    s.tokens = nil
  end
  if s.token and not s.tokenFaction then
    local tok = self:ParseToken(s.token)
    for _, n in pairs(s.slots) do
      if tok and n == tok.master then s.tokenFaction = self.faction end
    end
  end
  self:Fire("LOGIN")
end)

-- Names in Forever are "First Last" with a space and no realm part: always treat them as opaque whole strings.
function MF:FullName(unit)
  return GetUnitName(unit, true)
end

-- Unit tokens of the other group members (not including the player).
function MF:GroupUnits()
  local t = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do t[#t + 1] = "raid" .. i end
  elseif IsInGroup() then
    for i = 1, GetNumGroupMembers() - 1 do t[#t + 1] = "party" .. i end
  end
  local others = {}
  for _, u in ipairs(t) do
    if UnitExists(u) and not UnitIsUnit(u, "player") then others[#others + 1] = u end
  end
  return others
end

function MF:ParseOnOff(arg, current)
  arg = (arg or ""):lower()
  if arg == "on" then return true end
  if arg == "off" then return false end
  return not current
end

-- Message kind letter -> function(MF, sender, rest of payload); modules register theirs (see Comm.lua).
MF.messageHandlers = {}

-- Slash commands: /mama <command> <rest of line>
MF.commands = {}
MF.commandOrder = {}
function MF:AddCommand(name, fn, help)
  self.commands[name] = {fn = fn, help = help}
  table.insert(self.commandOrder, name)
end

function MF:Help()
  self:Print("commands (|cFF99E5FF/mama <command>|r):")
  for _, name in ipairs(self.commandOrder) do
    print("  |cFF99E5FF/mama|r " .. self.commands[name].help)
  end
end

SLASH_MAMA1 = "/mama"
SlashCmdList["MAMA"] = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  local c = MF.commands[cmd:lower()]
  if c then c.fn(MF, rest) else MF:Help() end
end

MF:AddCommand("help", function(self) self:Help() end, "help - this list")
MF:AddCommand("debug", function(self, rest)
  self.db.debug = self:ParseOnOff(rest, self.db.debug)
  self:Print("debug is now %s", tostring(self.db.debug))
end, "debug [on|off] - toggle debug output")
