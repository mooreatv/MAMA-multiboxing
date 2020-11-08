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

local DB = _G.DynBoxer

-- TODO: move most of this to MoLib

function MM:SetupMenu()
  MM:WipeFrame(MM.mmb)
  MM.minimapButtonAngle = 137 -- not overlap with PPA/default angle
  local b = MM:minimapButton(MM.buttonPos)
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetSize(19, 19)
  t:SetTexture("Interface/Addons/Mama/mama.blp")
  t:SetPoint("TOPLEFT", 7, -6)
  b:SetScript("OnClick", function(_w, button, _down)
    if button == "RightButton" then
      MM.Slash("config")
    elseif button == "MiddleButton" then
      DB.Slash("party disband")
    else
      DB.Slash("party")
    end
  end)
  b.tooltipText = "|cFFF2D80CMama|r:\n" ..
                    L["|cFF99E5FFLeft|r click to invite your team\n" .. "|cFF99E5FFMiddle|r click to disband\n" ..
                      "|cFF99E5FFRight|r click for options\n\n" .. "Drag to move this button."]
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
end

function MM.SavePositionCB(_f, pos, _scale)
  MM:SetSaved("buttonPos", pos)
end

MM.slashCmdName = "mama"
MM.addonHash = "@project-abbreviated-hash@"
MM.savedVarName = "MamaSaved"

function MM:AfterSavedVars()
  DB.name = "Mama-DBox" -- only ok/allowed because they are both my addons
end

local additionalEventHandlers = {

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
  end

}

function DB:SlotCommand(slot, fullName, firstFlag)
  local payload =
    "S" .. tostring(slot) .. " " .. fullName .. " " .. firstFlag .. " msg " .. tostring(DB.syncNum) .. "/" ..
      tostring(DB.sentMessageCount)
  DB:Debug(3, "Created slot payload for slot %: %", slot, payload)
  return payload
end


function MM:Help(msg)
  MM:PrintDefault("Mama: " .. msg .. "\n" .. "/mama config -- open addon config.\n" .. "/mama bug -- report a bug.\n" ..
                    "/mama debug on/off/level -- for debugging on at level or off.\n" ..
                    "/mama follow [x] -- follow me or follow optional slot x.\n" ..
                    "/mama lead [x] -- make me lead or make optional slot x the lead.\n" ..
                    "/mama version -- shows addon version.\nSee also /dbox commands.")
end

function MM:FollowCommand(_slot)
end

function MM:LeadCommand(_slot)
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
    local subText = L["Please submit on discord or on https://|cFF99E5FFbit.ly/mamabug|r or email"]
    MM:PrintDefault(L["Mama bug report open: "] .. subText)
    -- base molib will add version and date/timne
    MM:BugReport(subText, "@project-abbreviated-hash@\n\n" .. L["Bug report from slash command"])
  elseif cmd == "v" then
    -- version
    MM:PrintDefault("Mama " .. MM.manifestVersion .. " (@project-abbreviated-hash@) by MooreaTv (moorea@ymail.com)")
  elseif cmd == "f" then
    -- follow
    MM:PrintDefault("Mama: Requesting to be followed - not yet implemented")
  elseif cmd == "l" then
    -- follow
    MM:PrintDefault("Mama: Requesting to be made lead - not yet implemented")
  elseif cmd == "c" then
    -- Show config panel
    -- InterfaceOptionsList_DisplayPanel(MM.optionsPanel)
    InterfaceOptionsFrame:Show() -- onshow will clear the category if not already displayed
    InterfaceOptionsFrame_OpenToCategory(MM.optionsPanel) -- gets our name selected
  elseif MM:StartsWith(arg, "debug") then
    -- debug
    if rest == "on" then
      MM:SetSaved("debug", 1)
      DB:SetSaved("debug", 1)
    elseif rest == "off" then
      MM:SetSaved("debug", nil)
      DB:SetSaved("debug", nil)
    else
      local lvl = tonumber(rest)
      MM:SetSaved("debug", lvl)
      DB:SetSaved("debug", lvl)
    end
    MM:PrintDefault("Mama and DynamicBoxer debug now " .. (MM.debug and tostring(MM.debug) or "Off"))
  else
    MM:Help('unknown command "' .. arg .. '", usage:')
  end
end

-- Run/set at load time:

-- Slash

SlashCmdList["Mama_Slash_Command"] = MM.Slash

SLASH_Mama_Slash_Command1 = "/mama"

-- Events handling
MM:RegisterEventHandlers(additionalEventHandlers)

-- Options panel

function MM:CreateOptionsPanel()
  if MM.optionsPanel then
    MM:Debug("Options Panel already setup")
    return
  end
  MM:Debug("Creating Options Panel")

  local p = MM:Frame(L["Mama"])
  MM.optionsPanel = p
  p:addText(L["M.A.M.A options"], "GameFontNormalLarge"):Place()
  p:addText(
    L["|cFF99E5FFM|rooreaTv's/minimal yet |cFF99E5FFA|rwesome |cFF99E5FFM|rultiboxing |cFF99E5FFA|rssistant "] ..
      L["(name inspired by Jamba)"]):Place()
  p:addText(L["These options let you control the behavior of Mama"] .. " " .. MM.manifestVersion ..
              " @project-abbreviated-hash@"):Place()

  p:addText(
    L["Remember to use the |cFF99E5FFDynamicBoxer|r (v3 or newer) options tab to configure many additional options\n"..
    "This a very early alpha/prototype. See also keybindings and |cFF99E5FF/mama|r slash commands."])
    :Place(0, 16)

  -- TODO add some option

--  local teamSize = p:addSlider("Team size", "How many wow windows\n" ..
 --                                "or e.g |cFF99E5FF/mama teamsize 5|r for 5 windows", 2, 11,
 --                              1):Place(4,20)

  local slot = p:addSlider("This window's slot #", "This window's index in the team (must be unique)\n" ..
                               "or e.g |cFF99E5FF/mama slot 3|r for setting this to be window 3, 0 to revert to ISboxer", 0, 11,
                             1):Place(4,40)

  p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 20)

  p:addButton("Bug Report", L["Get Information to submit a bug."] .. "\n|cFF99E5FF/mama bug|r", "bug"):Place(4, 20)

  p:addButton(L["Reset minimap button"], L["Resets the minimap button to back to initial default location"], function()
    MM:SetSaved("buttonPos", nil)
    MM:SetupMenu()
  end):Place(4, 20)

  local debugLevel = p:addSlider(L["Debug level"], L["Sets the debug level"] .. "\n|cFF99E5FF/mama debug X|r", 0, 9, 1,
                                 "Off"):Place(16, 30)

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
    -- teamSize:SetValue(DB.manualTeamSize or 0)
    slot:SetValue(DB.manual)
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
        MM:PrintDefault("Mama: options setting debug level changed from % to OFF.", MM.debug)
      end
    else
      if MM.debug ~= sliderVal then
        MM:PrintDefault("Mama: options setting debug level changed from % to %.", MM.debug, sliderVal)
      end
    end
--    DB:SetSaved("manualTeamSize", teamSize:GetValue())
    DB:SetSaved("manual", slot:GetValue())
    MM:SetSaved("debug", sliderVal)
  end

  function p:cancel()
    MM:PrintDefault("Mama: options screen cancelled, not making any changes.")
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
_G.BINDING_NAME_MM_FOLLOWME = L["Follow me"] .. " |cFF99E5FF/mama follow me|r (or |cFF99E5FF/mama f|r for short)"
_G.BINDING_NAME_MM_LEAD = L["Make me lead"] .. " |cFF99E5FF/mama lead|r (or |cFF99E5FF/mama l|r for short)"

-- MM.debug = 2
MM:Debug("mama main file loaded")
