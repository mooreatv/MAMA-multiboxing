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

_G.MAMAFOREVER = "Mama-forever" -- the category name shown above the bindings
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
  f:SetSize(420, 130)
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
  dialog = f
  return f
end

function MamaForever:ShowTokenDialog(mode)
  local f = GetDialog()
  local e = f.edit
  if mode == "copy" then
    f.title:SetText("Mama-forever: team token (slot 1)")
    f.text:SetText("Ctrl-C to copy this token, then Enter. In each other window: /mama s N and Ctrl-V it, Enter.")
    local token = self:TokenText()
    e:SetScript("OnTextChanged", function(box, user)
      if user then box:SetText(token) box:HighlightText() end -- read only
    end)
    e:SetScript("OnEnterPressed", function() f:Hide() end)
    e:SetText(token)
    e:HighlightText()
  else
    f.title:SetText("Mama-forever: paste team token")
    f.text:SetText("Ctrl-V the token copied from slot 1 (|cFF99E5FF/mama token|r there), then Enter.")
    e:SetScript("OnTextChanged", nil)
    e:SetScript("OnEnterPressed", function(box)
      local ok, err = MamaForever:AcceptToken(box:GetText())
      if ok then f:Hide() else MamaForever:Print("%s", err) end
    end)
    e:SetText("")
  end
  f:Show()
  e:SetFocus()
end

BINDING_NAME_MAMA_INVITE = "Invite team |cFF99E5FF(/mama invite)|r"
BINDING_NAME_MAMA_DISBAND = "Disband team |cFF99E5FF(/mama disband)|r"
BINDING_NAME_MAMA_IDENTIFY = "Identify slot |cFF99E5FF(/mama identify)|r"
