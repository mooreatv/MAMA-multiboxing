--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/Mama
   (and the MoLib library at https://github.com/mooreatv/MoLib)

   Releases detail/changes are on https://github.com/mooreatv/Mama/releases
   ]] --
--
-- our name, our empty default (and unused) anonymous ns
local addon, _ns = ...

-- Table and base functions created by MoLib
local MM = _G[addon]
-- localization
MM.L = MM:GetLocalization()
local L = MM.L

-- MM.debug = 9 -- to debug before saved variables are loaded


-- TODO: move most of this to MoLib

function MM:SetupMenu()
  MM:WipeFrame(MM.mmb)
  MM.minimapButtonAngle = 137 -- not overlap with PPA/default angle
  local b = MM:minimapButton(MM.buttonPos)
  local _nw, _nh, s, w, h = MM:PixelPerfectSnap(b)
  self:Debug("new w % h %", w, h)
  local t = b:CreateTexture(nil, "ARTWORK")
	t:SetSize(19, 19)
  t:SetTexture("Interface/Addons/Mama/mama.blp")
	t:SetPoint("TOPLEFT", 7, -6)
  b:SetScript("OnClick", function(_w, button, _down)
    if button == "RightButton" then
      MM.Slash("config")
    else
      MM:PrintDefault("Mama TODO: do something when clicked...")
    end
  end)
  b.tooltipText = "|cFFF2D80CMama|r:\n" ..
                    L["|cFF99E5FFLeft|r click to TODO\n" .. "|cFF99E5FFRight|r click for options\n\n" ..
                      "Drag to move this button."]
  b:SetScript("OnEnter", function()
    MM:ShowToolTip(b, "ANCHOR_LEFT")
    MM.inButton = true
  end)
  b:SetScript("OnLeave", function()
    GameTooltip:Hide()
    MM.inButton = false
    MM:Debug("Hide tool tip...")
  end)
  MM:MakeMoveable(b, MM.SavePositionCB)
  MM.mmb = b
  MM.mmb.icon = icon
end

function MM.SavePositionCB(_f, pos, _scale)
  MM:SetSaved("buttonPos", pos)
end

MM.EventHdlrs = {

  PLAYER_ENTERING_WORLD = function(_self, ...)
    MM:Debug("OnPlayerEnteringWorld " .. MM:Dump(...))
    MM:CreateOptionsPanel()
    MM:SetupMenu()
  end,

  DISPLAY_SIZE_CHANGED = function(_self)
    if MM.mmb then
      MM:SetupMenu() -- should be able to just RestorePosition() but...
    end
  end,

  UI_SCALE_CHANGED = function(_self, ...)
    MM:DebugEvCall(1, ...)
    if MM.mmb then
      MM:SetupMenu() -- buffer with the one above?
    end
  end,

  ADDON_LOADED = function(_self, _event, name)
    MM:Debug(9, "Addon % loaded", name)
    if name ~= addon then
      return -- not us, return
    end
    -- check for dev version (need to split the tags or they get substituted)
    if MM.manifestVersion == "@" .. "project-version" .. "@" then
      MM.manifestVersion = "vX.YY.ZZ"
    end
    MM:PrintDefault("Mama " .. MM.manifestVersion ..
                            " by MooreaTv: type /mama for command list/help.")
    if MamaSaved == nil then
      MM:Debug("Initialized empty saved vars")
      MamaSaved = {}
    end
    MamaSaved.addonVersion = MM.manifestVersion
    MamaSaved.addonHash = "@project-abbreviated-hash@"
    MM:deepmerge(MM, nil, MamaSaved)
    MM:Debug(3, "Merged in saved variables.")
  end
}

function MM:OnEvent(event, first, ...)
  MM:Debug(8, "OnEvent called for % e=% %", self:GetName(), event, first)
  local handler = MM.EventHdlrs[event]
  if handler then
    return handler(self, event, first, ...)
  end
  MM:Error("Unexpected event without handler %", event)
end

function MM:Help(msg)
  MM:PrintDefault("Mama: " .. msg .. "\n" .. "/mama config -- open addon config\n" ..
                          "/mama bug -- report a bug\n" ..
                          "/mama debug on/off/level -- for debugging on at level or off.\n" ..
                          "/mama version -- shows addon version")
end

-- returns 1 if changed, 0 if same as live value
-- number instead of boolean so we can add them in handleOk
-- (saved var isn't checked/always set)
function MM:SetSaved(name, value)
  local changed = (value ~= self[name])
  self[name] = value
  MamaSaved[name] = value
  MM:Debug(8, "(Saved) Setting % set to % - MamaSaved=%", name, value, MamaSaved)
  if changed then
    return 1
  else
    return 0
  end
end

function MM.Slash(arg) -- can't be a : because used directly as slash command
  MM:Debug("Got slash cmd: %", arg)
  if #arg == 0 then
    MM:Help("commands, you can use the first letter of each:")
    return
  end
  local cmd = string.lower(string.sub(arg, 1, 1))
  local posRest = string.find(arg, " ")
  local rest = ""
  if not (posRest == nil) then
    rest = string.sub(arg, posRest + 1)
  end
  if cmd == "b" then
    local subText = L["Please submit on discord or on curse or github or email"]
    MM:PrintDefault(L["Mama bug report open: "] .. subText)
    -- base molib will add version and date/timne
    MM:BugReport(subText, "@project-abbreviated-hash@\n\n" .. L["Bug report from slash command"])
  elseif cmd == "v" then
    -- version
    MM:PrintDefault("PixelPerfectAlign " .. MM.manifestVersion ..
                            " (@project-abbreviated-hash@) by MooreaTv (moorea@ymail.com)")
  elseif cmd == "c" then
    -- Show config panel
    -- InterfaceOptionsList_DisplayPanel(MM.optionsPanel)
    InterfaceOptionsFrame:Show() -- onshow will clear the category if not already displayed
    InterfaceOptionsFrame_OpenToCategory(MM.optionsPanel) -- gets our name selected
  elseif MM:StartsWith(arg, "debug") then
    -- debug
    if rest == "on" then
      MM:SetSaved("debug", 1)
    elseif rest == "off" then
      MM:SetSaved("debug", nil)
    else
      MM:SetSaved("debug", tonumber(rest))
    end
    MM:PrintDefault("PixelPerfectAlign debug now %", MM.debug)
  else
    MM:Help('unknown command "' .. arg .. '", usage:')
  end
end

-- Run/set at load time:

-- Slash

SlashCmdList["Mama_Slash_Command"] = MM.Slash

SLASH_Mama_Slash_Command1 = "/mama"

-- Events handling
MM.frame = CreateFrame("Frame")

MM.frame:SetScript("OnEvent", MM.OnEvent)
for k, _ in pairs(MM.EventHdlrs) do
  MM.frame:RegisterEvent(k)
end

-- Options panel

function MM:CreateOptionsPanel()
  if MM.optionsPanel then
    MM:Debug("Options Panel already setup")
    return
  end
  MM:Debug("Creating Options Panel")

  local p = MM:Frame(L["Mama"])
  MM.optionsPanel = p
  p:addText(L["Mama options"], "GameFontNormalLarge"):Place()
  p:addText(L["Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)"]):Place()
  p:addText(L["These options let you control the behavior of Mama"] .. " " .. MM.manifestVersion ..
              " @project-abbreviated-hash@"):Place()

  -- TODO add some option

  p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 20)

  p:addButton("Bug Report", L["Get Information to submit a bug."] .. "\n|cFF99E5FF/mama bug|r", "bug"):Place(4,
                                                                                                                    20)

  p:addButton(L["Reset minimap button"], L["Resets the minimap button to back to initial default location"], function()
    MM:SetSaved("buttonPos", nil)
    MM:SetupMenu()
  end):Place(4, 20)

  local debugLevel = p:addSlider(L["Debug level"], L["Sets the debug level"] .. "\n|cFF99E5FF/mama debug X|r", 0,
                                 9, 1, "Off"):Place(16, 30)

  function p:refresh()
    MM:Debug("Options Panel refresh!")
    if MM.debug then
      -- expose errors
      xpcall(function()
        self:HandleRefresh()
      end, geterrorhandler())
    else
      -- normal behavior for interface option panel: errors swallowed by caller
      self:HandleRefresh()
    end
  end

  function p:HandleRefresh()
    p:Init()
    debugLevel:SetValue(MM.debug or 0)
  end

  function p:HandleOk()
    MM:Debug(1, "MM.optionsPanel.okay() internal")
    --    local changes = 0
    --    changes = changes + MM:SetSaved("lineLength", lineLengthSlider:GetValue())
    --    if changes > 0 then
    --      MM:PrintDefault("MM: % change(s) made to grid config", changes)
    --    end
    local sliderVal = debugLevel:GetValue()
    if sliderVal == 0 then
      sliderVal = nil
      if MM.debug then
        MM:PrintDefault("Options setting debug level changed from % to OFF.", MM.debug)
      end
    else
      if MM.debug ~= sliderVal then
        MM:PrintDefault("Options setting debug level changed from % to %.", MM.debug, sliderVal)
      end
    end
    MM:SetSaved("debug", sliderVal)
  end

  function p:cancel()
    MM:Warning("Options screen cancelled, not making any changes.")
  end

  function p:okay()
    MM:Debug(3, "MM.optionsPanel.okay() wrapper")
    if MM.debug then
      -- expose errors
      xpcall(function()
        self:HandleOk()
      end, geterrorhandler())
    else
      -- normal behavior for interface option panel: errors swallowed by caller
      self:HandleOk()
    end
  end
  -- Add the panel to the Interface Options
  InterfaceOptions_AddCategory(MM.optionsPanel)
end

-- bindings / localization
_G.MAMA = "Mama"
_G.BINDING_HEADER_MM = L["Mama addon key bindings"]
_G.BINDING_NAME_MM_SOMETHING = L["TODO something"] .. " |cFF99E5FF/mama todo|r"

-- MM.debug = 2
MM:Debug("mama main file loaded")
