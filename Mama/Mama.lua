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
MM.showMinimapIcon = true

-- MM.debug = 9 -- to debug before saved variables are loaded

local DB = _G.DynBoxer

MM.emaSetMaster = false -- don't it by default as ema is mostly gone, turn on in config if not needed
MM.followAfterMount = true
MM.ffa = true
MM.autoQuest = true
MM.autoFly = true
MM.autoAbandon = true
MM.autoDialog = true

MM.lead = nil

MM.maxSlot = 16


function MM.AbandonQuestHook()
  MM:Debug("AbandonQuestHook called")
  if MM.autoAbandon then
    local id = MM:GetSelectedQuest()
    MM:SendSecureCommand(MM:AbandonQuestCommand(id))
  end
end

function MM.SelectGossipOptionHook(n, ...)
  MM:Debug("SelectGossipOptionHook called % %", n, MM:Dump(...))
  if MM.autoDialog then
    MM:SendSecureCommand(MM:GossipCommand(n))
  end
end

function MM.SelectAvailableQuestHook(n, ...)
  MM:Debug("SelectAvailableQuestHook called % %", n, MM:Dump(...))
  if MM.autoDialog then
    MM:SendSecureCommand(MM:SelectQuestCommand(n))
  end
end

if DB.isClassic or DB.isLegacy then
  -- original AbandonQuest
  MM.oAQ = AbandonQuest
  hooksecurefunc("AbandonQuest", MM.AbandonQuestHook)
  -- original SelectGossipOption
  MM.oSGO = SelectGossipOption
  hooksecurefunc("SelectGossipOption", MM.SelectGossipOptionHook)
  -- original SelectAvailableQuest
  MM.oSAQ = SelectAvailableQuest
  hooksecurefunc("SelectAvailableQuest", MM.SelectAvailableQuestHook)
else
  -- retail
  -- put back basic global functions gone in 9.x
  function SelectQuestLogEntry(id)
    C_QuestLog.SetSelectedQuest(id)
  end
  function GetQuestLogPushable(id)
    return C_QuestLog.IsPushableQuest(id)
  end
  MM.oAQ = C_QuestLog.AbandonQuest
  hooksecurefunc(C_QuestLog, "AbandonQuest", MM.AbandonQuestHook)
  MM.oSGO = C_GossipInfo.SelectOption
  hooksecurefunc(C_GossipInfo, "SelectOption", MM.SelectGossipOptionHook)
  MM.oSAQ = C_GossipInfo.SelectAvailableQuest
  hooksecurefunc(C_GossipInfo, "SelectAvailableQuest", MM.SelectAvailableQuestHook)
  function SetAbandonQuest()
    C_QuestLog.SetAbandonQuest()
  end
  function GetQuestLogTitle(id)
    local info = C_QuestLog.GetInfo(id)
    local isComplete = C_QuestLog.IsComplete(info.questID)
    -- not really fully compatible but just what I need for MM:FindQuest
    return info.title, nil, nil, nil, nil, isComplete, nil, info.questID
  end
  function GetNumQuestLogEntries()
    return C_QuestLog.GetNumQuestLogEntries()
  end
end

function MM:GetSelectedQuest()
  if DB.isClassic then
    local idx = GetQuestLogSelection()
    return select(8, GetQuestLogTitle(idx))
  else
    return C_QuestLog.GetSelectedQuest()
  end
end


function MM.TakeTaxiNodeHook(id)
  local name = TaxiNodeName(id)
  MM:PrintDefault("Mama: detected flight to % : %, autoFly is %", id, name, MM.autoFly)
  if MM.autoFly then
    -- On SL the ids match always so we could just send that, halas not on classic
    -- so send the name too so it can be matched
    MM:SendSecureCommand(MM:TaxiCommand(id, name))
  end
end

local oTTN = TakeTaxiNode
hooksecurefunc("TakeTaxiNode", MM.TakeTaxiNodeHook)

function MM:TaxiCommand(id, name)
  local payload =  "T" .. " " .. id .. " " .. name
  DB:Debug(3, "Created taxi payload for %: %", id, payload)
  return payload
end

function MM:ExecuteTaxiCommand(rest, from)
  local id, name = rest:match("^([0-9]+) (.+)")
  MM:PrintDefault("Mama: Taxi command from %: % %", from, id, name)
  -- good case where Ids match:
  if TaxiNodeName(id) == name then
    MM:Debug(1, "Taxi ids match on %", id)
    GetNumRoutes(id)
    oTTN(id)
    return
  end
  for i = 1, NumTaxiNodes() do
    if TaxiNodeName(i) == name then
      MM:Debug(1, "Found % at % vs %", name, i, id)
      GetNumRoutes(i)
      oTTN(i)
      return
    end
  end
  MM:PrintDefault("Mama: couldn't find % in this character's flight map (is it open?)", name)
end

function MM:FindQuest(qid)
  for i = 1, GetNumQuestLogEntries() do
    local title, _lvl, _grp, _hdr, _collapsed, complete, _freq, id = GetQuestLogTitle(i)
    MM:Debug("Q% title % id % complete % (full %)", i, title, id, complete, MM:Dump(GetQuestLogTitle(i)))
    if id == qid then
      MM:Debug("Found % (%) at index %", qid, title, i)
      return i, title, complete
    end
  end
  MM:Debug("% not found in questlog", qid)
  return nil, nil, nil
end

function MM:ExecuteAbandonQuestCommand(qid, from)
  local i, title, isComplete =  MM:FindQuest(qid)
  if not i then
    MM:PrintDefault("Mama: could not find quest to abandon % received from %", qid, from)
    return
  end
  if isComplete then
    MM:PrintDefault("Mama: not abandoning completed quest % % despite request from %", qid, title, from)
    return
  end
  SelectQuestLogEntry(i)
  MM:PrintDefault("Mama: AbandonQuest % received from %: found % at %", qid, from, title, i)
  SetAbandonQuest()
  MM.oAQ()
end

function MM:ExecuteGossipCommand(n, from)
  MM:PrintDefault("Mama: Selecting Gossip Option % received from %", n, from)
  MM.oSGO(n)
end

function MM:ExecuteQuestSelectCommand(n, from)
  MM:PrintDefault("Mama: Selecting quest number % received from %", n, from)
  MM.oSAQ(n)
end

function MM:SetLead(name)
  MM.lead = name
  MM:UpdateAssist()
end

function MM:GetLead()
  if MM.lead then
    return MM.lead
  end
  return "player"
end

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

function MM:AbandonQuestCommand(id)
  local payload =  "a" .. " " .. id
  DB:Debug(3, "Created abandon quest payload for %: %", id, payload)
  return payload
end

function MM:GossipCommand(id)
  local payload =  "G" .. " " .. id
  DB:Debug(3, "Created select gossip option payload for %: %", id, payload)
  return payload
end

function MM:SelectQuestCommand(id)
  local payload =  "Q" .. " " .. id
  DB:Debug(3, "Created select quest payload for %: %", id, payload)
  return payload
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
    if DB.isLegacy then
      -- legacy case
      local ret = DB:SendChannelMessage(secureMessage)
      MM:Debug("Legacy channel msg for %: % (mid %)", payload, ret, messageId)
    else
      -- retail
      local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "CHANNEL", DB.channelId)
      MM:Debug("Retail channel msg for %: % (mid %)", payload, ret, messageId)
    end
  else
    -- classic
    local ret = C_ChatInfo.SendAddonMessage(MM.chatPrefix, secureMessage, "SAY")
    MM:Debug("Classic Say msg for %: % (mid %)", payload, ret, messageId)
  end
end

function MM:FollowUnit(param)
  if MM.isLegacy then
    FollowUnit(param)
  else
    MM:PrintDefault("Mama: Follow is now protected in all Blizzard servers, use /click MamaFollow or its keybind instead")
  end
end
function MM:MakeMeLead()
  MM:SetLead("player")
  -- always (try to) set MAMA master
  MM:SendSecureCommand(MM:LeadCommand(DB.fullName), false)
  -- first check if we aren't already lead
  if UnitIsGroupLeader("Player") then
    MM:Debug("Already leader, skipping...")
    return
  end
  if not IsInGroup() then
    MM:Debug("Not in a group, skipping make me lead...")
    return
  end
  MM:PrintDefault("Mama: Requesting to be made lead")
  -- MM:SendSecureCommand(MM:LeadCommand(DB.fullName), true) -- party only
  MM:SetEMAMaster(DB.fullName)
end

function MM:ExecuteLeadCommand(fullName, msg)
  local shortName = DB:ShortName(fullName)
  MM:SetLead(shortName)
  if not UnitIsGroupLeader("Player") then
    MM:Debug("I'm not leader, skipping %", msg)
    if fullName == DB.fullName then
        -- Do ema stuff last as it tends to error out
        MM:SetEMAMaster(fullName)
    end
    return
  end
  MM:PrintDefault("Mama: Setting % (%) as leader", shortName, fullName)
  PromoteToLeader(shortName)
  if fullName == DB.fullName then
    MM:SetEMAMaster(fullName)
  end
end

function MM:ExecuteFollowCommand(fullName)
  local shortName = DB:ShortName(fullName)
  MM:PrintDefault("Mama: Following % (%)", shortName, fullName)
  MM:FollowUnit(shortName)
end

function MM:ExecuteMountCommand(onoff, from)
  if onoff == "true" or onoff == "mount" or onoff == "on" or onoff == "" or onoff == "up" then
    if DB.isClassic then
      MM:PrintDefault("Mama: Mounting requested from % - can't implement on classic. follow after mount is %", from,
                      MM.followAfterMount)
    else
      MM:PrintDefault("Mama: Mounting requested from %, follow after mount is %", from, MM.followAfterMount)
      if IsMounted() then
        MM:PrintDefault("Mama: Mounting requested from %, already mounted. Follow after mount is %", from, MM.followAfterMount)
      else
        MM:PrintDefault("Mama: Mounting requested from %, follow after mount is %", from, MM.followAfterMount)
        C_MountJournal.SummonByID(0)
      end
    end
    if MM.followAfterMount then
      MM:ExecuteFollowCommand(from)
    end
  else
    MM:PrintDefault("Mama: Dismount requested")
    Dismount()
  end
end

function MM:AcceptQuest()
  MM:Debug("Accepting quest")
  AcceptQuest()
end

-- TODO: maybe do it only once instead of keep attempting to share quests we just got shared
function MM:ShareQuest(index)
  MM:Debug("Request to share quest (index=%)", index)
  SelectQuestLogEntry(index)
  -- classic api doesn't actually take a parameter for GetQuestLogPushable but 9.x does...
  if (GetQuestLogPushable(index)) then
    MM:Debug("Attempting to share quest index=% with your group", index)
    QuestLogPushQuest()
    return
  end
  MM:Debug("Unable to share quest index=% with your group", index)
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
    MM:Debug("Received invalid (" .. msg .. ") message % from %: %", source, from, data)
    return
  end
  -- TODO: as the command list extends, use a table instead of if/else
  local cmd, fullName = msg:match("^([LFAMTaGQ]) ([^ ]*)") -- or strplit(" ", data)
  MM:Debug("on % from %, got % -> cmd=% fullname=%", source, from, msg, cmd, fullName)
  if cmd == "F" then
    -- Follow cmd...
    if fullName == "train" then
      fullName = DB.watched[((DB.watched.slot+DB.expectedCount-2)%DB.expectedCount)+1]
      MM:PrintDefault("Mama: follow train per request from %: following %", from, fullName)
    elseif fullName == "stop" then
      MM:PrintDefault("Mama: stopping follow per request from %", from)
      MM:FollowUnit("player")
      return
    end
    MM:ExecuteFollowCommand(fullName)
  elseif cmd == "L" then
    -- Lead cmd...
    MM:ExecuteLeadCommand(fullName, msg)
  elseif cmd == "A" then
    -- Follow+Lead cmd
    MM:ExecuteFollowCommand(fullName)
    MM:ExecuteLeadCommand(fullName, msg)
  elseif cmd == "M" then
    MM:ExecuteMountCommand(fullName, from)
  elseif cmd == "T" then
    MM:ExecuteTaxiCommand(string.sub(msg, 3), from)
  elseif cmd == "a" then
    MM:ExecuteAbandonQuestCommand(tonumber(fullName, 10), from)
  elseif cmd == "G" then
    MM:ExecuteGossipCommand(tonumber(fullName, 10), from)
  elseif cmd == "Q" then
    MM:ExecuteQuestSelectCommand(tonumber(fullName, 10), from)
  else
    MM:Warning("Unexpected command (%,%) in % (%) from %", cmd, fullName, msg, string.len(msg), from)
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
  local ret = C_ChatInfo.RegisterAddonMessagePrefix(MM.chatPrefix)
  DB:Debug("Prefix register success %", ret)
  MM:WipeFrame(MM.mmb) -- doesn't really wipe anymore, just hides
  if not MM.showMinimapIcon then
    MM:Debug("Not showing minimap icon per config")
    return
  end
  MM.minimapButtonAngle = 137 -- not overlap with PPA/default angle
  local b = MM:minimapButton(MM.buttonPos, nil, "Interface\\Addons\\Mama\\mama.blp")
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
  end,

  PLAYER_REGEN_ENABLED = function(_self, ...)
    MM:DebugEvCall(1, ...)
    MM:UpdateAssist()
  end,

  PARTY_LEADER_CHANGED = function()
    MM:LeaderChange()
  end,

  GROUP_ROSTER_UPDATE = function()
    if UnitIsGroupLeader("player") then
      local curLoot = GetLootMethod()
      local numInParty = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
      if numInParty == 1 then
        MM.ffaIssued = false
        MM.groupIssued = false
        return
      end
      MM:Debug("numInParty % expected % loot %", numInParty, DB.expectedCount, curLoot)
      if MM.ffa then
        if not MM.ffaIssued and numInParty == DB.expectedCount and curLoot ~= "freeforall" then
          MM:PrintDefault("Mama: Setting loot to ffa as configured, was %. expected team size %", curLoot, DB.expectedCount)
          SetLootMethod("freeforall")
          MM.ffaIssued = true
        elseif not MM.groupIssued and numInParty > DB.expectedCount and curLoot == "freeforall" then
          MM:PrintDefault("Mama: Extra people in party/r  (% vs %), switching to group loot", numInParty, DB.expectedCount)
          SetLootMethod("group")
          MM.groupIssued = true
        end
      end
    end
  end,

  QUEST_ACCEPT_CONFIRM = function(_self, ...)
    MM:DebugEvCall(1, ...)
    if MM.autoQuest then
      MM:AcceptQuest()
    end
  end,

  QUEST_DETAIL = function(_self, ...)
    MM:DebugEvCall(1, ...)
    if MM.autoQuest then
      MM:AcceptQuest()
    end
  end,

  QUEST_ACCEPTED = function(_self, ev, idx, id)
    MM:Debug("Ev % % %",ev, idx, id)
    if MM.autoQuest then
      MM:ShareQuest(idx)
    end
  end,

  QUEST_REMOVED = function(_self, ev, id)
    MM:Debug("Ev % %", ev, id)
  end
}

function MM:MacroButtons()
  local b = CreateFrame("Button", "MamaAssist", UIParent, "SecureActionButtonTemplate")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/assist " .. MM:GetLead())
  b:RegisterForClicks("AnyUp", "AnyDown")
  b = CreateFrame("Button", "MamaFollow", UIParent, "SecureActionButtonTemplate")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/follow " .. MM:GetLead())
  b:RegisterForClicks("AnyUp", "AnyDown")
end

MM:MacroButtons()

function MM:UpdateAssist()
  local l = MM:GetLead()
  MM:Debug("Updating assist and follow to %", l)
  if InCombatLockdown() then
    MM:Debug("Can't update in combat")
    return
  end
  if l == "player" then
    _G["MamaAssist"]:SetAttribute("macrotext", "")
    _G["MamaFollow"]:SetAttribute("macrotext", "")
  else
    _G["MamaAssist"]:SetAttribute("macrotext", "/assist " .. l)
    _G["MamaFollow"]:SetAttribute("macrotext", "/assist " .. l.."\n/follow " .. l)
  end
end

function MM:LeaderChange()
  if MM.lead then
    return -- we already have a lead configured
  end
  if UnitIsGroupLeader("player") then
    MM:SetLead("player")
    return
  end
  local sz = GetNumGroupMembers()
  for i = 1, sz do
    local x = GetRaidRosterInfo(i)
    if x and UnitIsGroupLeader(x) then
      MM:Debug("Found lead at index %: %", i, x)
      MM:SetLead(x)
      return
    end
  end
end

-- function MM:Assist()
--  MM:Debug("Assist called - lead is %", MM.lead)
--end

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
                    "/mama follow [stop||Name-Server||train] -- follow me (no arg)" ..
                    " or request stop follow or make a follow train.\n" ..
                    "/mama lead [Name-Server] -- make me lead or make optional Name-Server the lead.\n" ..
                    "/mama altogether -- both makemelead and followme in 1 combo command.\n" ..
                    "/mama mount on||off -- mount or dismount team.\n" ..
                    "/mama quest on||off -- automatically accept and share quests\n" ..
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
    if rest == "train" then
      if MM.isLegacy then
        MM:PrintDefault("Mama: Requesting follow train!", rest)
        MM:FollowUnit("player") -- implies stop follow for issuer
      else
        local fullName = DB:ShortName(DB.watched[((DB.watched.slot+DB.expectedCount-2)%DB.expectedCount)+1])
        MM:PrintDefault("Mama: train requested, following % (assuming this is coming from hw)", fullName)
        FollowUnit(fullName)
        return
      end
    elseif rest ~= "" then
      MM:PrintDefault("Mama: Requesting follow %", rest)
      local shortName = DB:ShortName(rest)
      if rest == "stop" then
        shortName = "player"
      end
      DB:Debug("calling local FollowUnit(%)", shortName)
      MM:FollowUnit(shortName)
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
      local shortName = DB:ShortName(rest)
      MM:SetLead(shortName)
      if UnitIsGroupLeader("Player") then
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
    MM:SetLead("player")
    MM:PrintDefault("Mama: Requesting to both be made lead and followed")
    MM:SendSecureCommand(MM:AltogetherCommand(DB.fullName))
    MM:SetEMAMaster(DB.fullName)
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
    DB.Slash("enable")
    MM:PrintDefault(
      "MAMA slot % set. After exchange token (hit return on s1 after copy, before pasting): /reload to save/confirm all is setup",
      sn)
  elseif cmd == "c" then
    MM:ShowConfigPanel(MM.optionsPanel)
  elseif MM:StartsWith(arg, "q") then
    if rest == "on" then
      MM:SetSaved("autoQuest", 1)
    elseif rest == "off" then
      MM:SetSaved("autoQuest", nil)
    end
    MM:PrintDefault("Mama autoQuest is " .. (MM.autoQuest and "on" or "off"))
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
    :Place(0, 14)

  -- TODO add some option

--  local teamSize = p:addSlider("Team size", "How many wow windows\n" ..
 --                                "or e.g |cFF99E5FF/mama teamsize 5|r for 5 windows", 2, 11,
 --                              1):Place(4,20)

  local slot = p:addSlider("This window's slot #", "This window's index in the team (must be unique)\n" ..
                               "or e.g |cFF99E5FF/mama slot 3|r for setting this to be window 3, 0 to revert to plain DynamicBoxer",
                               0, MM.maxSlot, 1):Place(4,22)

  local ffa = p:addCheckBox("Set loot to FFA after invite",
              "Automatically set the loot to Free For All when inviting"):Place(4,16)

  local autoQuest = p:addCheckBox("Automatically accept and share quests",
              "Enable/Disable automatically accepting and sharing quests"):Place(4,16)

  local autoAbandon = p:addCheckBox("Abandon Quests with team",
              "Automatically abandon quests with the team"):PlaceRight(32)

  local autoDialog = p:addCheckBox("Automatically select same dialog option",
    "Enable/disable automatically selecting the same option in NPC (quest, vendor) dialogs as current window"):Place(4,16)

  local autoFly = p:addCheckBox("Automatically take same Flight as leader",
    "Enable/Disable automatically taking the same flight path as leader"):PlaceRight(22)


  local followAfterMount = p:addCheckBox("Follow after mount",
      "Automatically follow in addition to mount up"):Place(4,16)

  local showMinimapIcon = p:addCheckBox("Show minimap icon",
      "Show/Hide the minimap button"):Place(4,16)

  local emaSetMaster = p:addCheckBox("Set EMA master based on leader",
      "Sets the EMA master when setting the group leader"):Place(4,16)
  p:addText(L["Use |cFF99E5FF/click MamaAssist|r in your macros for assisting the lead."]):Place(0,16)

  p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 32)

  p:addButton("Bug Report", L["Get Information to submit a bug."] .. "\n|cFF99E5FF/mama bug|r", "bug"):Place(4, 20)

  p:addButton(L["Reset minimap button"], L["Resets the minimap button to back to initial default location"], function()
    MM:SetSaved("buttonPos", nil)
    MM:SetupMenu()
  end):PlaceRight(20)

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
    showMinimapIcon:SetChecked(MM.showMinimapIcon)
    ffa:SetChecked(MM.ffa)
    autoQuest:SetChecked(MM.autoQuest)
    autoFly:SetChecked(MM.autoFly)
    autoAbandon:SetChecked(MM.autoAbandon)
    autoDialog:SetChecked(MM.autoDialog)
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
    MM:SetSaved("ffa", ffa:GetChecked())
    MM:SetSaved("autoQuest", autoQuest:GetChecked())
    MM:SetSaved("autoFly", autoFly:GetChecked())
    MM:SetSaved("autoAbandon", autoAbandon:GetChecked())
    MM:SetSaved("autoDialog", autoDialog:GetChecked())
    if MM:SetSaved("showMinimapIcon", showMinimapIcon:GetChecked()) then
      MM:SetupMenu()
    end
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
_G.BINDING_NAME_MM_FOLLOW_TRAIN = L["Follow train"] .. " |cFF99E5FF/mama follow train|r (or |cFF99E5FF/mama f train|r for short)"
_G.BINDING_NAME_MM_LEAD = L["Make me lead"] .. " |cFF99E5FF/mama lead|r (or |cFF99E5FF/mama l|r for short)"
_G.BINDING_NAME_MM_FL_COMBO = L["Combo make me lead and follow me"] ..
  " |cFF99E5FF/mama altogether|r (or |cFF99E5FF/mama a|r for short)"
_G.BINDING_NAME_MM_MOUNT_UP = L["Mount up"] .. " |cFF99E5FF/mama mount up|r (or |cFF99E5FF/mama m|r for short)"
_G.BINDING_NAME_MM_DISMOUNT = L["Dismount"] .. " |cFF99E5FF/mama mount dismount|r (or |cFF99E5FF/mama m d|r for short)"
_G["BINDING_NAME_CLICK MamaAssist:LeftButton"] = L["Assist"] .. " |cFF99E5FF/click MamaAssist|r " .. L["in macros"]
_G["BINDING_NAME_CLICK MamaFollow:LeftButton"] = L["Follow"] .. " |cFF99E5FF/click MamaFollow|r " .. L["in macros"]

-- MM.debug = 2
MM:Debug("mama main file loaded")
