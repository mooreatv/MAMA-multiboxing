--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Key binding labels (the bindings themselves are in Bindings.xml, which the client loads automatically).
BINDING_HEADER_MAMAFOREVER = "Mama-forever"
BINDING_NAME_MAMA_LEAD = "Make me lead |cFF99E5FF(/mama lead)|r"
_G["BINDING_NAME_CLICK MamaFollow:LeftButton"] = "Follow + assist lead"
_G["BINDING_NAME_CLICK MamaAssist:LeftButton"] = "Assist lead (no follow)"
_G["BINDING_NAME_CLICK MamaTrain:LeftButton"] = "Follow train + assist lead"

-- One small dialog used both to copy the token (slot 1) and to paste it (other slots).
local dialog
local function GetDialog()
  if dialog then return dialog end
  local f = CreateFrame("Frame", "MamaForeverTokenDialog", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(420, 145)
  f:SetPoint("CENTER", 0, 150)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, f:GetName()) -- Escape closes it
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", 0, -5)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", 15, -35)
  f.text:SetPoint("TOPRIGHT", -15, -35)
  f.text:SetJustifyH("LEFT")
  local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  e:SetAutoFocus(true)
  e:SetSize(380, 24)
  e:SetPoint("BOTTOM", 0, 20)
  e:SetMaxLetters(200)
  e:SetScript("OnEscapePressed", function() f:Hide() end)
  f.edit = e
  -- copy mode: saves the token for the other accounts of this PC (written at /reload or logout, see MF:ShareToken)
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetSize(80, 22)
  b:SetPoint("BOTTOMRIGHT", -12, 20)
  b:SetText("Reload")
  b:SetScript("OnClick", ReloadUI)
  f.reload = b
  dialog = f
  return f
end

-- withReload: narrower edit box, with the Reload button on its right.
local function layout(f, withReload)
  local e = f.edit
  e:ClearAllPoints()
  if withReload then
    e:SetSize(290, 24)
    e:SetPoint("BOTTOMLEFT", 22, 20)
  else
    e:SetSize(380, 24)
    e:SetPoint("BOTTOM", 0, 20)
  end
  f.reload:SetShown(withReload)
end

-- note: optional extra line under the instructions (paste mode).
function MamaForever:ShowTokenDialog(mode, note)
  local f = GetDialog()
  local e = f.edit
  e:SetNumeric(false)
  local onPC = self:CanShareToken()
  layout(f, mode == "copy" and onPC)
  if mode == "copy" then
    f.title:SetText("Mama-forever: team token (slot 1)")
    local help = "Ctrl-C to copy this token, then Enter. In each other window: /mama s N and Ctrl-V it, Enter."
    if onPC then help = help .. " Or Reload here: other accounts on this PC get it when they log in." end
    f.text:SetText(help)
    local token = self:TokenText()
    local function selectAll(box) box:HighlightText() end
    e:SetScript("OnTextChanged", function(box, user)
      if user then
        box:SetText(token)
        box:HighlightText()
      end -- read only
    end)
    -- a click would otherwise drop the selection and Ctrl-C would copy nothing
    e:SetScript("OnMouseUp", selectAll)
    e:SetScript("OnEditFocusGained", selectAll)
    e:SetScript("OnEnterPressed", function() f:Hide() end)
    e:SetText(token)
    e:HighlightText()
  else
    f.title:SetText("Mama-forever: paste team token")
    local help = "Ctrl-V the token copied from slot 1 (|cFF99E5FF/mama token|r there), then Enter."
    f.text:SetText(note and help .. "\n" .. note or help)
    e:SetScript("OnTextChanged", nil)
    e:SetScript("OnMouseUp", nil)
    e:SetScript("OnEditFocusGained", nil)
    e:SetScript("OnEnterPressed", function(box)
      local ok, err = MamaForever:AcceptToken(box:GetText())
      if ok then
        f:Hide()
      else
        MamaForever:Error("%s", err)
        f.text:SetText(help .. "\n|cFFFF4040" .. err:gsub("^%l", string.upper) .. "|r")
        box:HighlightText()
      end
    end)
    e:SetText("")
  end
  f:Show()
  e:SetFocus()
end

-- Asked at login when this PC has a team token and this window has no slot yet (see MF:UseSharedToken).
-- Escape or the close button: not asked again until the next login or /reload.
function MamaForever:ShowSlotDialog()
  local f = GetDialog()
  local e = f.edit
  local tok = self:Token()
  if not tok then return end
  local guess = 1
  if tok.master ~= self.myName then
    guess = 2
    while self.db.slots[guess] do guess = guess + 1 end
  end
  f.title:SetText("Mama-forever: this window's slot")
  local help = ("Team token found on this PC (master %s). Slot number of this window, then Enter.\n" ..
                 "Escape: not now (|cFF99E5FF/mama s N|r later, |cFF99E5FF/mama s 0|r: never ask this character)."):format(
                 tok.master)
  f.text:SetText(help)
  e:SetScript("OnTextChanged", nil)
  e:SetScript("OnMouseUp", nil)
  e:SetScript("OnEditFocusGained", nil)
  e:SetNumeric(true)
  layout(f, false)
  e:SetScript("OnEnterPressed", function(box)
    local n = tonumber(box:GetText())
    if not n or n < 1 or n > self.maxSlot then
      f.text:SetText(("%s\n|cFFFF4040Type a slot from 1 to %d.|r"):format(help, self.maxSlot))
      box:HighlightText()
      return
    end
    f:Hide()
    self:SetSlot(n, true)
  end)
  e:SetText(tostring(guess))
  e:HighlightText()
  f:Show()
  e:SetFocus()
end

-- After new character setup switched the Edit Mode layout: the game menu's Logout/Exit are blocked until a reload
-- (see Setup.lua's classicLayout). Its own frame: the slot dialog can be open at the same time.
local reloadDialog
function MamaForever:ShowReloadDialog()
  local f = reloadDialog
  if not f then
    f = CreateFrame("Frame", "MamaForeverReloadDialog", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(360, 110)
    f:SetPoint("CENTER", 0, -40) -- under the slot dialog
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, f:GetName()) -- Escape closes it
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Mama-forever: reload needed")
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 15, -35)
    text:SetPoint("TOPRIGHT", -15, -35)
    text:SetJustifyH("LEFT")
    text:SetText(
      "The layout changed: reload the UI, or the game menu can't log out or exit (|cFF99E5FF/reload|r later).")
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(100, 22)
    b:SetPoint("BOTTOM", 0, 15)
    b:SetText("Reload")
    b:SetScript("OnClick", ReloadUI)
    reloadDialog = f
  end
  f:Show()
end

BINDING_NAME_MAMA_INVITE = "Invite team |cFF99E5FF(/mama invite)|r"
BINDING_NAME_MAMA_DISBAND = "Disband team |cFF99E5FF(/mama disband)|r"
BINDING_NAME_MAMA_IDENTIFY = "Identify slot |cFF99E5FF(/mama identify)|r"
BINDING_NAME_MAMA_COMPLETE = "Team is complete |cFF99E5FF(/mama complete)|r"
BINDING_NAME_MAMA_TOGGLE = "Turn Mama off/on for this character |cFF99E5FF(/mama disable, /mama enable)|r"
