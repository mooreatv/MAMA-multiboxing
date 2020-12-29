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

MM.chatPrefix = "mama1" -- protocol version in prefix for the addon messages

-- MM.debug = 9 -- to debug before saved variables are loaded

local DB = _G.DynBoxer

MM.emaSetMaster = true -- do it by default, turn off in config if not needed
MM.followAfterMount = true

function MM:SetEMAMaster(fullName)
  if not MM.emaSetMaster then
    MM:Debug("EMA set master config is off, not setting ema master")
    return
  end
  if not DB.EMA then
    MM:Debug("EMA not installed, not setting master")
    return
  end
  MM:PrintDefault("Mama: Setting EMA master to %", fullName)
  DB.EMA.CommandIAmMaster()
  --DB.EMA.db.master = fullName
  --DB.EMA:SendMessage(DB.EMA.MESSAGE_TEAM_ORDER_CHANGED) -- needed to refresh EMA ui if set
end

function MM:FollowCommand(fullName)
  local payload =  "F" .. " " .. fullName
  DB:Debug(3, "Created follow payload for %: %", fullName, payload)
  return payload
end

function MM:LeadCommand(fullName)
  local payload =  "L" .. " " .. fullName
  DB:Debug(3, "Created lead payload for %: %", fullName, payload)
  return payload
end

function MM:AltogetherCommand(fullName)
  local payload =  "A" .. " " .. fullName
  DB:Debug(3, "Created combo F+L=A payload for %: %", fullName, payload)
  return payload
end

function MM:MountCommand(onoff)
  local payload =  "M" .. " " .. tostring(onoff)
  DB:Debug(3, "Created mount payload for %: %", onoff, payload)
  return payload
end

function MM:SecureCommand(payload)
  return DB:CreateSecureMessage(payload, DB.Channel, DB.Secret)
end

function MM:SendSecureCommand(payload, partyOnly)
  MM:Debug("Sending %", payload)
  if not MM:IsSetup() then
    return
  end
  local secureMessage, messageId = MM:SecureCommand(payload)
  if IsInGroup() then
    local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "RAID")
    MM:Debug("Party/raid msg for % ret %", payload, ret)
  end
  if partyOnly then
    return
  end
  -- TODO: that's broken in SL but it's ok because in SL we have the channel anyway
  if DB.GuildCache.n > 0 then
    local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "GUILD")
    MM:Debug("Guild msg for % ret %", payload, ret)
  end
  if DB.channelId and DB.channelId > 0 then
    -- retail
    local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "CHANNEL", DB.channelId)
    MM:Debug("Retail channel msg for %: % (mid %)", payload, ret, messageId)
  else
    -- classic
    local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "SAY")
    MM:Debug("Classic Say msg for %: % (mid %)", payload, ret, messageId)
  end
end

function MM:MakeMeLead()
  -- first check if we aren't already lead
  if UnitIsGroupLeader("Player") then
    MM:Debug("Already leader, skipping...")
    return
  end
  if not IsInGroup() then
    MM:Debug("Not in a group, skipping make me lead...")
    return
  end
  MM:SetEMAMaster(DB.fullName)
  MM:PrintDefault("Mama: Requesting to be made lead")
  MM:SendSecureCommand(MM:LeadCommand(DB.fullName), true) -- party only
end

function MM:ExecuteLeadCommand(fullName, msg)
  local shortName = DB:ShortName(fullName)
  if fullName == DB.fullName then
    MM:SetEMAMaster(fullName)
  end
  if not UnitIsGroupLeader("Player") then
    MM:Debug("I'm not leader, skipping %", msg)
    return
  end
  MM:PrintDefault("Mama: Setting % (%) as leader", shortName, fullName)
  PromoteToLeader(shortName)
end

function MM:ExecuteFollowCommand(fullName)
  local shortName = DB:ShortName(fullName)
  MM:PrintDefault("Mama: Following % (%)", shortName, fullName)
  FollowUnit(shortName)
end

function MM:ExecuteMountCommand(onoff, from)
  if onoff == "true" or onoff == "mount" or onoff == "on" or onoff == "" or onoff == "up" then
    if DB.isClassic then
      MM:PrintDefault("Mounting requested from % - can't implement on classic. follow after mount is %", from, MM.followAfterMount)
    else
      MM:PrintDefault("Mounting requested from %, follow after mount is %", from, MM.followAfterMount)
      if IsMounted() then
        MM:PrintDefault("Mounting requested from %, already mounted. Follow after mount is %", from, MM.followAfterMount)
      else
        MM:PrintDefault("Mounting requested from %, follow after mount is %", from, MM.followAfterMount)
        C_MountJournal.SummonByID(0)
      end
    end
    if MM.followAfterMount then
      MM:ExecuteFollowCommand(from)
    end
  else
    MM:PrintDefault("Dismount requested")
    Dismount()
  end
end

function MM:ProcessMessage(source, from, data)
  -- refactor shared copy/pasta with dynamicboxer's version
  local directMessage = (source == "WHISPER" or source == "CHAT_FILTER")
  if from == DB.fullName then
    MM:Debug(2, "Skipping our own message on %: %", source, data)
    return
  end
  -- check authenticity (channel sends unsigned messages)
  local valid, msg, lag, msgId = DB:VerifySecureMessage(data, DB.Channel, DB.Secret)
  if valid then
    MM:Debug(2, "Received valid secure direct=% message from % lag is %s, msg id is % part of full message %",
               directMessage, from, lag, msgId, data)
    if DB.duplicateMsg:exists(msgId) then
      MM:Debug("!!!Received % duplicate msg from %, will ignore: %", source, from, data)
      return
    end
    DB.duplicateMsg:add(msgId)
  else
    -- in theory warning if the source isn't guild/say/...
    DB:Debug("Received invalid (" .. msg .. ") message % from %: %", source, from, data)
    return
  end
  local cmd, fullName = msg:match("^([LFAM]) ([^ ]+)") -- or strplit(" ", data)
  MM:Debug("on % from %, got % -> cmd=% fullname=%", source, from, msg, cmd, fullName)
  if cmd == "F" then
    -- Follow cmd...
    if fullName == "stop" then
      MM:PrintDefault("Mama: stopping follow per request from %", from)
      FollowUnit("player")
      return
    end
    MM:ExecuteFollowCommand(fullName)
  elseif cmd == "L" then
    -- Lead cmd...
    MM:ExecuteLeadCommand(fullName, msg)
  elseif cmd == "A" then
    -- Follow+Lead cmd
    MM:ExecuteLeadCommand(fullName, msg)
    MM:ExecuteFollowCommand(fullName)
  elseif cmd == "M" then
    MM:ExecuteMountCommand(fullName, from)
  else
    MM:Warning("Unexpected command in % from %", msg, from)
  end
end

function MM:ChatAddonMsg(event, prefix, data, channel, sender, zoneChannelID, localID, name, instanceID)
  MM:Debug(7, "OnChatEvent called for % e=% channel=% p=% data=% from % z=%, lid=%, name=%, instance=%", self:GetName(),
           event, channel, prefix, data, sender, zoneChannelID, localID, name, instanceID)
  if prefix == MM.chatPrefix then
    MM:ProcessMessage(channel, sender, data)
    return
  end
  MM:Debug(9, "wrong prefix % or channel % or instance % vs %, skipping!", prefix, channel, instanceID, DB.joinedChannel)
  return -- not our message(s)
end

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

  local ret = C_ChatInfo.RegisterAddonMessagePrefix(MM.chatPrefix)
  DB:Debug("Prefix register success %", ret)

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

  CHAT_MSG_ADDON = MM.ChatAddonMsg,

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

function MM:IsSetup()
  if DB.fullName and DB.Secret then
    return true
  end
  MM:Error("You need to setup Mama and your DynamicBoxer team one time setup first: |cFF99E5FF/mama config|r")
  return false
end

function MM:Help(msg)
  MM:PrintDefault("Mama: " .. msg .. "\n" .. "/mama config -- open addon config.\n" .. "/mama bug -- report a bug.\n" ..
                    "/mama debug on/off/level -- for debugging on at level or off.\n" ..
                    "/mama follow [stop|Name-Server] -- follow me (no arg) or request stop follow.\n" ..
                    "/mama lead [Name-Server] -- make me lead or make optional Name-Server the lead.\n" ..
                    "/mama altogether -- both makemelead and followme in 1 combo command.\n" ..
                    "/mama mount on|off -- mount or dismount team.\n" ..
                    "/mama version -- shows addon version.\nSee also /dbox commands.")
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
    if not MM:IsSetup() then
      return
    end
    if rest ~= "" then
      MM:PrintDefault("Mama: Requesting follow %", rest)
      local shortName = DB:ShortName(rest)
      if rest == "stop" then
        shortName = "player"
      end
      DB:Debug("calling local FollowUnit(%)", shortName)
      FollowUnit(shortName)
    else
      MM:PrintDefault("Mama: Requesting to be followed")
      rest = DB.fullName
    end
    MM:SendSecureCommand(MM:FollowCommand(rest))
  elseif cmd == "l" then
    -- lead
    if not MM:IsSetup() then
      return
    end
    if rest == "" then
      MM:MakeMeLead()
    else
      if UnitIsGroupLeader("Player") then
        local shortName = DB:ShortName(rest)
        MM:PrintDefault("Mama: directly setting % (%) as leader", shortName, rest)
        PromoteToLeader(shortName)
      else
        MM:PrintDefault("Mama: Requesting % to be made lead", rest)
        MM:SendSecureCommand(MM:LeadCommand(rest))
      end
    end
  elseif cmd == "a" then
    -- lead and follow in 1 command
    if not MM:IsSetup() then
      return
    end
    MM:SetEMAMaster(DB.fullName)
    MM:PrintDefault("Mama: Requesting to both be made lead and followed")
    MM:SendSecureCommand(MM:AltogetherCommand(DB.fullName))
  elseif cmd == "m" then
    -- mount
    if not MM:IsSetup() then
      return
    end
    MM:ExecuteMountCommand(rest, "player")
    MM:SendSecureCommand(MM:MountCommand(rest))
  elseif cmd == "s" then
    -- slot setting
    local sn = tonumber(rest)
    if not sn or sn < 0 or sn > 40 then
      MM:Error("Use /mama slot number to set slot#, % is not a valid number", rest)
      return
    end
    DB:SetSaved("manual", sn)
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
    "And do dbox one time setup and |cFF99E5FF/reload|r . See also keybindings and |cFF99E5FF/mama|r slash commands."])
    :Place(0, 16)

  -- TODO add some option

--  local teamSize = p:addSlider("Team size", "How many wow windows\n" ..
 --                                "or e.g |cFF99E5FF/mama teamsize 5|r for 5 windows", 2, 11,
 --                              1):Place(4,20)

  local slot = p:addSlider("This window's slot #", "This window's index in the team (must be unique)\n" ..
                               "or e.g |cFF99E5FF/mama slot 3|r for setting this to be window 3, 0 to revert to ISboxer", 0, 11,
                             1):Place(4,50)

  local emaSetMaster = p:addCheckBox("Set EMA master based on leader",
      "Sets the EMA master when setting the group leader"):Place(4,20)

  local followAfterMount = p:addCheckBox("Follow after mount",
      "Automatically follow in addition to mount up"):Place(4,20)

  p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 60)

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
    emaSetMaster:SetChecked(MM.emaSetMaster)
    followAfterMount:SetChecked(MM.followAfterMount)
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
    MM:SetSaved("emaSetMaster", emaSetMaster:GetChecked())
    MM:SetSaved("followAfterMount", followAfterMount:GetChecked())
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
_G.BINDING_NAME_MM_FOLLOWME = L["Follow me"] .. " |cFF99E5FF/mama followme|r (or |cFF99E5FF/mama f|r for short)"
_G.BINDING_NAME_MM_FOLLOW_STOP = L["Stop Follow"] .. " |cFF99E5FF/mama follow stop|r (or |cFF99E5FF/mama f stop|r for short)"
_G.BINDING_NAME_MM_LEAD = L["Make me lead"] .. " |cFF99E5FF/mama lead|r (or |cFF99E5FF/mama l|r for short)"
_G.BINDING_NAME_MM_FL_COMBO = L["Combo make me lead and follow me"] ..
  " |cFF99E5FF/mama altogether|r (or |cFF99E5FF/mama a|r for short)"
_G.BINDING_NAME_MM_MOUNT_UP = L["Mount up"] .. " |cFF99E5FF/mama mount up|r (or |cFF99E5FF/mama m|r for short)"
_G.BINDING_NAME_MM_DISMOUNT = L["Dismount"] .. " |cFF99E5FF/mama mount dismount|r (or |cFF99E5FF/mama m d|r for short)"

-- MM.debug = 2
MM:Debug("mama main file loaded")
