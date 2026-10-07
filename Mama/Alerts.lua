--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Alerts sent from the other windows to the lead's:
-- "F;subzone": we stopped following out of combat and the lead got away (stuck behind something).
-- "W;i/n;flag;sender;text": a whisper from someone outside the team (in parts, addon messages are limited to 255
-- bytes), flag "GM" or "". "W;0/0;flag;;" when the whisper was secret (chat lockdown).
local _, MF = ...

local WATCH = 10 -- seconds after follow ends during which the lead getting out of range means we're stuck
local SPAM = 15 -- seconds between two follow warnings from the same window
local CHUNK = 150 -- bytes of whisper text per message

local function lead(self)
  local l = self:GetLead()
  if l and l ~= self.myName then return l end
end

local function busy(unit) return UnitAffectingCombat("player") or (unit and UnitAffectingCombat(unit)) end

local following, watch

local function stopWatch()
  if watch then watch:Cancel() end
  watch = nil
end

MF:On("AUTOFOLLOW_BEGIN", function()
  following = true
  stopWatch()
end)

-- Following ends when we move by hand, the lead gets too far, a fight starts... Only worth a warning when it happened
-- out of combat and the lead then gets out of follow range (about 28 yards) without us following again.
MF:On("AUTOFOLLOW_END", function(self)
  local was = following
  following = false
  stopWatch()
  local l = lead(self)
  if not (self.db.followWarn and was and l and self.roster[l]) or busy(self.roster[l]) then return end
  local ticks = 0
  watch = C_Timer.NewTicker(1, function()
    ticks = ticks + 1
    local unit = self.roster[l]
    if following or not unit or ticks > WATCH or busy(unit) or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then
      stopWatch()
      return
    end
    if not CheckInteractDistance(unit, 4) then
      stopWatch()
      self:Debug("follow of %s broken and they're out of range, telling them", l)
      self:SendWhisper(l, "F;" .. (GetSubZoneText() or ""), "follow broken")
    end
  end)
end)

local lastWarn = {}
MF.messageHandlers.F = function(self, sender, rest)
  local slot = self:SlotOf(sender)
  if not slot or GetTime() - (lastWarn[sender] or -SPAM) < SPAM then return end
  lastWarn[sender] = GetTime()
  local where = rest ~= "" and (" near " .. rest) or ""
  local msg = ("Slot %d %s stopped following%s"):format(slot, sender, where)
  self:Print("|cFFFF4040%s|r", msg)
  RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo.RAID_WARNING)
  PlaySound(SOUNDKIT.RAID_WARNING)
end

-- Splits text in parts of at most size bytes, never inside a UTF-8 character.
local function split(text, size)
  local parts, i = {}, 1
  while i <= #text do
    local j = math.min(i + size - 1, #text)
    while j < #text and j > i do
      local b = text:byte(j + 1)
      if b < 128 or b >= 192 then break end -- next byte starts a character: we can cut after j
      j = j - 1
    end
    parts[#parts + 1] = text:sub(i, j)
    i = j + 1
  end
  return parts
end

-- Chat text and sender can be secret values (chat messaging lockdown): unreadable, even as table keys.
local function secret(v) return issecretvalue and issecretvalue(v) end

-- flag (specialFlags) is never secret, "GM" for a game master.
MF:On("CHAT_MSG_WHISPER", function(self, text, sender, _, _, _, flag)
  local l = lead(self)
  if not (self.db.forwardWhispers and l and sender) then return end
  flag = flag == "GM" and "GM" or ""
  if secret(text) or secret(sender) then
    self:SendWhisper(l, "W;0/0;" .. flag .. ";;", "forwarding a hidden whisper")
    return
  end
  if self:SlotOf(sender) or self.db.team[sender] then return end
  local parts = split(text, CHUNK)
  for i, part in ipairs(parts) do
    self:SendWhisper(l, ("W;%d/%d;%s;%s;%s"):format(i, #parts, flag, sender, part), "forwarding a whisper")
  end
end)

MF.messageHandlers.W = function(self, sender, rest)
  local i, n, flag, from, text = rest:match("^(%d+)/(%d+);(%a*);([^;]*);(.*)$")
  if not i then return end
  local slot = self:SlotOf(sender)
  local who = (slot and ("slot " .. slot .. " ") or "") .. sender
  local gm = flag == "GM"
  local tag = gm and "|cFF00CCFF<GM>|r " or ""
  if from == "" then
    self:Print("|cFFFF80FF%s got a %swhisper|cFFFF80FF we can't read (chat lockdown), look in its window|r", who, tag)
  else
    local part = n ~= "1" and (" (" .. i .. "/" .. n .. ")") or ""
    self:Print("|cFFFF80FF%s got a whisper%s from|r %s|Hplayer:%s|h[%s]|h|cFFFF80FF: %s|r", who, part, tag, from, from,
               text)
  end
  if tonumber(i) > 1 then return end
  if gm then
    RaidNotice_AddMessage(RaidWarningFrame, who .. " got a whisper from a GM", ChatTypeInfo.RAID_WARNING)
    PlaySound(SOUNDKIT.GM_CHAT_WARNING)
  else
    PlaySound(SOUNDKIT.TELL_MESSAGE)
  end
end
