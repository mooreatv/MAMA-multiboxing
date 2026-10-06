--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --

-- Team status window: one row per slot with name and link state, plus mouse shortcuts for team management.
-- Colors: white = this window, green = in our group, yellow = linked but not grouped, grey = not seen yet.
-- Window clicks (header or any row, see the tooltip): invite, disband, party/raid, auto invite, resync,
-- token dialog, options, compact view, identify. Plain click on a row targets it (or invites it if not grouped).

local _, MF = ...

local ROW_H, WIDTH = 18, 190
local rows = {}
local frame
local pendingRefresh

local TIP = table.concat({
  "|cFF99E5FFLeft click|r invite the team",
  "|cFF99E5FFMiddle click|r disband (leader uninvites the team, others leave)",
  "|cFF99E5FFRight click|r options",
  "|cFF99E5FFShift left|r toggle party/raid",
  "|cFF99E5FFShift right|r toggle compact view",
  "|cFF99E5FFShift middle|r identify this window (big slot number)",
  "|cFF99E5FFCtrl left|r toggle auto invite",
  "|cFF99E5FFCtrl right|r show/paste the team token",
  "|cFF99E5FFAlt left|r resend our info to the team",
  "|cFF99E5FFMousewheel|r resize, |cFF99E5FFdrag|r the header to move",
  "On a row: left click targets (or invites if not in group), right click unit menu.",
}, "\n")

local function expectedCount()
  local n = 0
  for s in pairs(MF.db.slots) do
    if s > n then n = s end
  end
  return n
end

local function stateOf(name)
  if name == MF.myName then return "me", 1, 1, 1, "ffffff" end
  if name and MF.roster[name] then return "grouped", 0.2, 1, 0.2, "33ff33" end
  if name and MF.online[name] then return "online", 1, 0.85, 0.1, "ffd91a" end
  return "unknown", 0.6, 0.6, 0.6, "999999"
end

function MF:Identify(seconds)
  local f = self.identifyFrame
  if not f then
    f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetSize(600, 420)
    f:SetPoint("TOP", 0, -80)
    f.num = f:CreateFontString(nil, "OVERLAY", "GameFont_Gigantic")
    f.num:SetPoint("TOP")
    f.num:SetTextColor(0.95, 0.85, 0.05)
    f.num:SetScale(4)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(64, 64)
    f.icon:SetPoint("LEFT", f.num, "RIGHT", 15, 0) -- class icon right of the number, faction crest left of it
    f.faction = f:CreateTexture(nil, "ARTWORK")
    f.faction:SetPoint("RIGHT", f.num, "LEFT", -15, 0)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFont_Gigantic")
    f.name:SetPoint("TOP", f.num, "BOTTOM", 0, -10)
    f.name:SetScale(1.5)
    f.name:SetTextColor(0.6, 0.9, 1)
    self.identifyFrame = f
  end
  f.num:SetText(self.db.slot > 0 and tostring(self.db.slot) or "?")
  f.name:SetText(self.myName or "")
  local faction = UnitFactionGroup("player")
  local baseId, size = 516953, 90
  if faction == "Alliance" then
    baseId, size = 516949, 100 -- horde crest is a bit taller
  end
  f.faction:SetTexture(baseId)
  f.faction:SetSize(size, size)
  local _, class = UnitClass("player")
  local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    f.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    f.icon:SetTexCoord(unpack(coords))
    f.icon:Show()
  else
    f.icon:Hide()
  end
  f:Show()
  if f.timer then f.timer:Cancel() end
  f.timer = C_Timer.NewTimer(seconds or 4, function() f:Hide() end)
end

MF:Listen("LOGIN", function(self)
  if self.db.identifyOnLogin and self.db.slot > 0 then
    C_Timer.After(2, function() self:Identify(6) end)
  end
end)
MF:AddCommand("identify", function(self) self:Identify() end, "identify - show this window's slot big on screen")

local function WindowClick(button)
  local ctrl, shift, alt = IsControlKeyDown(), IsShiftKeyDown(), IsAltKeyDown()
  if button == "LeftButton" then
    if ctrl then
      MF.db.autoInvite = not MF.db.autoInvite
      MF:Print("slot 1 auto invite is now %s", tostring(MF.db.autoInvite))
    elseif shift then MF:PartyToggle()
    elseif alt then MF:Announce(); MF:Print("resent our info to the team")
    else MF:InviteMissing() end
  elseif button == "RightButton" then
    if ctrl then MF:ShowTokenDialog(MF.db.slot == 1 and "copy" or "paste")
    elseif shift then
      MF.db.compact = not MF.db.compact
      MF:RefreshStatus()
    else MF.commands.options.fn(MF) end
  elseif button == "MiddleButton" then
    if shift then MF:Identify() else MF:Disband() end
  end
end

local function ApplyScale(scale)
  scale = math.max(0.5, math.min(4, scale))
  MF.db.statusScale = scale
  frame:SetScale(scale)
end

local function MakeFrame()
  local f = CreateFrame("Frame", "MamaForeverStatus", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, 40)
  f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
  f:SetBackdropColor(0, 0, 0, 0.6)
  f:SetBackdropBorderColor(0, 0, 0, 1)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:EnableMouseWheel(true)
  f:SetScale(MF.db.statusScale or 1)
  f:SetScript("OnMouseWheel", function(_, delta)
    if InCombatLockdown() then return end
    ApplyScale((MF.db.statusScale or 1) * (delta > 0 and 1.05 or 0.95))
  end)
  local pos = MF.db.statusPos
  if pos then
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    f:SetPoint("TOP", UIParent, "TOP", UIParent:GetWidth() / 5, -2)
  end

  local header = CreateFrame("Button", nil, f)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(ROW_H)
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header.text:SetPoint("LEFT", 6, 0)
  header:RegisterForClicks("AnyUp")
  header:SetScript("OnClick", function(_, button) WindowClick(button) end)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() f:StartMoving() end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, rp, x, y = f:GetPoint()
    MF.db.statusPos = {p, rp, x, y}
  end)
  header:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Mama-forever team")
    GameTooltip:AddLine(TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  header:SetScript("OnLeave", GameTooltip_Hide)
  f.header = header
  return f
end

local function GetRow(i)
  if rows[i] then return rows[i] end
  local b = CreateFrame("Button", "MamaForeverStatusRow" .. i, frame, "SecureActionButtonTemplate")
  b:SetHeight(ROW_H)
  b:SetPoint("TOPLEFT", 0, -ROW_H * i)
  b:SetPoint("TOPRIGHT", 0, -ROW_H * i)
  b:SetAttribute("useOnKeyDown", false) -- act on mouse up (the client defaults to key down)
  b:RegisterForClicks("AnyUp", "AnyDown")
  -- only plain left/right clicks are secure actions; modified and middle clicks are handled in PreClick
  b:SetAttribute("type1", "target")
  b:SetAttribute("type2", "togglemenu")
  b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.mark:SetPoint("LEFT", 3, 0)
  b.slotText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.slotText:SetPoint("LEFT", 12, 0)
  b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.name:SetPoint("LEFT", 28, 0)
  b.name:SetPoint("RIGHT", -4, 0)
  b.name:SetJustifyH("LEFT")
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.hl:SetColorTexture(1, 1, 1, 0.15)
  b.slot = i
  b:SetScript("PreClick", function(self, button, down)
    if down then return end
    local modified = IsControlKeyDown() or IsShiftKeyDown() or IsAltKeyDown()
    if modified or button == "MiddleButton" then
      WindowClick(button)
    elseif button == "LeftButton" and self.missingName and not self.unit then
      MF:Print("inviting %s", self.missingName)
      C_PartyInfo.InviteUnit(self.missingName)
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("Slot %d: %s"):format(self.slot, self.fullName or "(not seen yet)"))
    if self.unit then
      GameTooltip:AddLine("|cFF99E5FFLeft click|r target, |cFF99E5FFright click|r unit menu", 1, 1, 1)
    elseif self.fullName then
      GameTooltip:AddLine("|cFF99E5FFLeft click|r to invite", 1, 1, 1)
    else
      GameTooltip:AddLine("Run |cFF99E5FF/mama s " .. self.slot .. "|r in that window", 1, 1, 1)
    end
    GameTooltip:AddLine("Other clicks: see the header tooltip", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  rows[i] = b
  return b
end

function MF:RefreshStatus()
  if not frame then return end
  if InCombatLockdown() then -- secure attributes can't change in combat
    pendingRefresh = true
    return
  end
  local n = expectedCount()
  local lead = self:GetLead()
  local grouped = 0
  local compact = {}
  for i = 1, n do
    local name = self.db.slots[i]
    local state, r, g, b, hex = stateOf(name)
    if state == "me" or state == "grouped" then grouped = grouped + 1 end
    local label = (i == self.db.slot and ">" or "") .. i
    compact[#compact + 1] = ("|cFF%s%s|r"):format(hex, label)
    local row = GetRow(i)
    local unit = name and self.roster[name]
    row.fullName, row.unit = name, unit
    row.missingName = (name and name ~= self.myName) and name or nil
    row:SetAttribute("unit", unit or (name == self.myName and "player") or nil)
    row.mark:SetText(i == self.db.slot and ">" or "")
    row.slotText:SetText(tostring(i))
    row.name:SetText((name or "?") .. (name and name == lead and " |cFFFFD100*|r" or ""))
    row.name:SetTextColor(r, g, b)
    row:SetShown(not self.db.compact)
  end
  for i = n + 1, #rows do rows[i]:Hide() end
  local count = ("|cFFFFD100(%d/%d)|r"):format(grouped, n)
  if self.db.compact then
    frame.header.text:SetText(table.concat(compact, " ") .. " " .. count)
    frame:SetSize(math.max(60, frame.header.text:GetStringWidth() + 14), ROW_H + 2)
  else
    frame.header.text:SetText("Mama team  " .. count)
    frame:SetSize(WIDTH, ROW_H * (n + 1) + 2)
  end
  frame:SetShown(self.db.slot > 0 and self.db.showStatus and n > 0)
end

local function Refresh() MF:RefreshStatus() end

MF:Listen("LOGIN", function(self)
  frame = MakeFrame()
  self:RefreshStatus()
end)
MF:Listen("TEAM_CHANGED", Refresh)
MF:On("GROUP_ROSTER_UPDATE", Refresh)
MF:On("PLAYER_REGEN_ENABLED", function(self)
  if pendingRefresh then
    pendingRefresh = false
    self:RefreshStatus()
  end
end)

MF:AddCommand("ui", function(self, rest)
  self.db.showStatus = self:ParseOnOff(rest, self.db.showStatus)
  self:Print("status window is now %s", self.db.showStatus and "shown" or "hidden")
  self:RefreshStatus()
end, "ui [on|off] - show or hide the team status window (hover it for all the mouse shortcuts)")
