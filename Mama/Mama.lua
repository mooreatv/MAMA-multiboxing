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
MF.defaults = {
  debug = false,
  macro = true,
  autoQuest = true,
  autoDialog = true,
  autoAccept = true,
  lead = false,
  slot = 0,
  token = false,
  showStatus = true,
  autoShare = true,
  autoAbandon = true,
  autoInvite = true,
  autoRaid = true,
  autoFFA = true,
  compact = false,
  identifyOnLogin = true,
  statusScale = 1
}

-- Everything we print (debug included, shown or not) is also kept: last MAX_LOG lines, saved across reloads (see Bug.lua).
local MAX_LOG = 100
local log = {}
MF.log = log

local function record(msg)
  msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  log[#log + 1] = date("%H:%M:%S") .. " " .. msg
  if #log > MAX_LOG then table.remove(log, 1) end
end

function MF:Print(msg, ...)
  if select("#", ...) > 0 then msg = msg:format(...) end
  record(msg)
  print(self.prefix .. msg)
end

function MF:Debug(msg, ...)
  if select("#", ...) > 0 then msg = msg:format(...) end
  record("[debug] " .. msg)
  if not (self.db and self.db.debug) then return end
  print("|cFF808080Mama debug:|r " .. msg)
end

-- Once the saved variables are loaded, continue the log of the previous session with what was recorded so far.
function MF:LoadLog()
  local saved = MamaForeverSaved.log or {}
  for _, line in ipairs(log) do saved[#saved + 1] = line end
  while #saved > MAX_LOG do table.remove(saved, 1) end
  MamaForeverSaved.log = saved
  MF.log = saved
  log = saved
end

-- Internal (non-Blizzard) callbacks between modules.
local listeners = {}
function MF:Listen(name, fn)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], fn)
end

function MF:Fire(name, ...) for _, fn in ipairs(listeners[name] or {}) do fn(self, ...) end end

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

frame:SetScript("OnEvent", function(_, event, ...) for _, fn in ipairs(handlers[event]) do fn(MF, ...) end end)

MF:On("ADDON_LOADED", function(self, name)
  if name ~= addonName then return end
  MamaForeverSaved = MamaForeverSaved or {}
  local s = MamaForeverSaved.settings or {}
  MamaForeverSaved.settings = s
  for k, v in pairs(self.defaults) do if s[k] == nil then s[k] = v end end
  s.team = s.team or {} -- set of full names ("First Last") allowed to auto-invite us
  s.slots = s.slots or {} -- slot number -> character full name ("First Last"), learned from the team handshake
  self.db = s
  self:LoadLog()
end)

MF:On("PLAYER_LOGIN", function(self)
  self.myName = self:FullName("player")
  -- each login or /reload starts with a marker, so it's easy to see where to start copying in /mama bug
  record(("---reload--- %s %s"):format(date("%Y-%m-%d"), tostring(self.myName)))
  -- Team slots and the history of who held which slot are remembered per faction (the saved variables are account wide).
  self.faction = UnitFactionGroup("player") or "Neutral"
  local s = self.db
  s.slotsBy = s.slotsBy or {}
  s.slotsBy[self.faction] = s.slotsBy[self.faction] or {}
  s.slots = s.slotsBy[self.faction]
  s.history = s.history or {}
  s.history[self.faction] = s.history[self.faction] or {}
  self:Fire("LOGIN")
end)

-- Names in Forever are "First Last" with a space and no realm part: always treat them as opaque whole strings.
function MF:FullName(unit) return GetUnitName(unit, true) end

-- Unit tokens of the other group members (not including the player).
function MF:GroupUnits()
  local others = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if UnitExists(unit) and not UnitIsUnit(unit, "player") then others[#others + 1] = unit end
    end
  elseif IsInGroup() then
    for i = 1, GetNumGroupMembers() - 1 do
      local unit = "party" .. i
      if UnitExists(unit) and not UnitIsUnit(unit, "player") then others[#others + 1] = unit end
    end
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
  for _, name in ipairs(self.commandOrder) do print("  |cFF99E5FF/mama|r " .. self.commands[name].help) end
end

SLASH_MAMA1 = "/mama"
SlashCmdList["MAMA"] = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  local c = MF.commands[cmd:lower()]
  if c then
    c.fn(MF, rest)
  else
    MF:Help()
  end
end

MF:AddCommand("help", function(self) self:Help() end, "help - this list")
MF:AddCommand("debug", function(self, rest)
  self.db.debug = self:ParseOnOff(rest, self.db.debug)
  self:Print("debug is now %s", tostring(self.db.debug))
end, "debug [on|off] - toggle debug output")
