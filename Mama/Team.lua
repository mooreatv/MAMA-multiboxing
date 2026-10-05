--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --

-- Team: who is in the group, who is the lead, which characters are "ours".

local _, MF = ...

MF.roster = {} -- full name -> unit token, for the other group members

function MF:RefreshRoster()
  wipe(self.roster)
  for _, u in ipairs(self:GroupUnits()) do
    local n = self:FullName(u)
    if n and n ~= UNKNOWN then self.roster[n] = u end
  end
  self:Fire("TEAM_CHANGED")
end

-- Explicit lead if set, otherwise whoever else leads the group. nil when we lead or are alone.
function MF:GetLead()
  if self.db.lead then return self.db.lead end
  for _, u in ipairs(self:GroupUnits()) do
    if UnitIsGroupLeader(u) then return self:FullName(u) end
  end
end

function MF:SetLead(name)
  self.db.lead = name or false
  self:Fire("TEAM_CHANGED")
end

for _, ev in ipairs({"GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "UNIT_NAME_UPDATE"}) do
  MF:On(ev, function(self) self:RefreshRoster() end)
end
MF:Listen("LOGIN", function(self) self:RefreshRoster() end)

-- Auto-accept invites only from characters we were told are on our team.
MF:On("PARTY_INVITE_REQUEST", function(self, from)
  if self.db.autoAccept and self.db.team[from] then
    self:Debug("accepting invite from %s", from)
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
  end
end)

local function sortedTeam(team)
  local names = {}
  for n in pairs(team) do names[#names + 1] = n end
  table.sort(names)
  return names
end

-- Make `name` the lead on every window; whoever is group leader promotes them if needed.
function MF:AnnounceLead(name)
  self:SetLead(name)
  self:SendTeam("L;" .. name)
  if IsInGroup() and not UnitIsGroupLeader("player") and name == self.myName then
    self:Print("asking the team to make us lead")
  end
  if UnitIsGroupLeader("player") and name ~= self.myName and self.roster[name] then
    PromoteToLeader(self.roster[name])
  end
end

function MF:MakeMeLead()
  self:AnnounceLead(self.myName)
end

MF.messageHandlers.L = function(self, sender, rest)
  if rest == "" then return end
  self:Print("%s says %s is the lead", sender, rest)
  self:SetLead(rest)
  if UnitIsGroupLeader("player") and rest ~= self.myName and self.roster[rest] then
    PromoteToLeader(self.roster[rest])
  end
end

MF:AddCommand("lead", function(self, rest)
  if rest == "" then
    self:MakeMeLead()
  elseif rest:lower() == "auto" then
    self:SetLead(nil)
  else
    self:AnnounceLead(rest)
  end
  self:Print("lead is %s%s", self:GetLead() or "(none)", self.db.lead and "" or " (follows group leader)")
end, "lead [Full Name|auto] - no name: make this window the lead (all windows follow it); auto: follow the group leader")

MF:AddCommand("team", function(self, rest)
  local sub, arg = rest:match("^(%S*)%s*(.-)$")
  sub = sub:lower()
  local team = self.db.team
  if sub == "add" then
    if arg == "" then
      for n in pairs(self.roster) do team[n] = true end -- no name: add everyone currently grouped with us
    else
      team[arg] = true
    end
  elseif sub == "remove" and arg ~= "" then
    team[arg] = nil
  elseif sub == "clear" then
    wipe(team)
  elseif sub ~= "" and sub ~= "list" then
    self:Print("usage: /mama team [list | add [Full Name] | remove Full Name | clear]")
    return
  end
  local names = sortedTeam(team)
  self:Print("team (%d): %s", #names, table.concat(names, ", "))
end, "team [list|add [name]|remove name|clear] - characters we auto-accept invites from")

MF:AddCommand("invite", function(self)
  self:InviteMissing()
end, "invite - invite the team members that aren't in the group yet (converts to raid above 5)")

local inviteQueue
local inviteCount

-- Invites the missing team members in slot order; above 5 it waits for the group to exist, then converts to raid.
local function processInvites(tries)
  while inviteQueue and #inviteQueue > 0 do
    local name = inviteQueue[1]
    if MF.roster[name] then
      table.remove(inviteQueue, 1)
    else
      if inviteCount >= 5 and not IsInRaid() then
        if not MF.db.autoRaid then
          MF:Print("group is full: turn on auto raid (/mama options) to invite more than 5")
          inviteQueue = nil
          return
        end
        if tries > 20 then
          MF:Print("giving up inviting: couldn't convert to a raid (are the characters too low level?)")
          inviteQueue = nil
          return
        end
        if IsInGroup() and UnitIsGroupLeader("player") then C_PartyInfo.ConvertToRaid() end
        C_Timer.After(0.5, function() processInvites(tries + 1) end)
        return
      end
      MF:Print("inviting %s", name)
      C_PartyInfo.InviteUnit(name)
      inviteCount = inviteCount + 1
      tries = 0
      table.remove(inviteQueue, 1)
    end
  end
  inviteQueue = nil
end

function MF:InviteMissing()
  if inviteQueue then return end -- already running
  inviteQueue = {}
  local slots = {}
  for s, n in pairs(self.db.slots) do slots[#slots + 1] = s end
  table.sort(slots)
  for _, s in ipairs(slots) do
    local n = self.db.slots[s]
    if n ~= self.myName and not self.roster[n] then inviteQueue[#inviteQueue + 1] = n end
  end
  if #inviteQueue == 0 then
    inviteQueue = nil
    self:Print("everyone is already in the group")
    return
  end
  inviteCount = math.max(1, GetNumGroupMembers())
  processInvites(0)
end

-- Several teammates tend to announce themselves at once: collect them into a single invite pass.
local invitePending
function MF:ScheduleInvites()
  if invitePending then return end
  invitePending = true
  C_Timer.After(1.5, function()
    invitePending = false
    local missing = false
    for _, n in pairs(self.db.slots) do
      if n ~= self.myName and not self.roster[n] and self.online[n] then missing = true end
    end
    if missing then self:InviteMissing() end
  end)
end

function MF:PartyToggle()
  if IsInRaid() then
    self:Print("switching to party (if possible)")
    C_PartyInfo.ConvertToParty()
  else
    self:Print("switching to raid")
    C_PartyInfo.ConvertToRaid()
  end
end

-- Leader: uninvite the team members. Otherwise just leave the group.
function MF:Disband()
  if not IsInGroup() then return end
  if UnitIsGroupLeader("player") then
    local uninvite = C_PartyInfo.UninviteUnit or UninviteUnit
    for name in pairs(self.roster) do
      if self:SlotOf(name) then
        self:Print("uninviting %s", name)
        uninvite(name)
      end
    end
  else
    self:Print("disband requested, we aren't the group leader so we're just leaving")
    C_PartyInfo.LeaveParty()
  end
end

MF:AddCommand("disband", function(self) self:Disband() end,
  "disband - leader: uninvite the team; otherwise leave the group")
MF:AddCommand("raid", function(self) self:PartyToggle() end, "raid - toggle between party and raid")
MF:AddCommand("autoinvite", function(self, rest)
  self.db.autoInvite = self:ParseOnOff(rest, self.db.autoInvite)
  self:Print("slot 1 auto invite is now %s", tostring(self.db.autoInvite))
end, "autoinvite [on|off] - slot 1 invites team members as they come online")

MF:AddCommand("status", function(self)
  local lead = self:GetLead()
  self:Print("me: %s, lead: %s, grouped: %s", self.myName or "?", lead or "(none)", tostring(IsInGroup()))
end, "status - show current character, lead and group state")
