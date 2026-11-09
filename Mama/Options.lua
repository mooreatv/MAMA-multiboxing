--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Options panel (Game Menu > Options > AddOns > Mama-forever), also reachable with /mama options.
local _, MF = ...

-- "Set team loot (FFA or master)", the one it sets (master loot auto distribution on or off) in blue.
local function teamLootLabel()
  local on = "|cFF99E5FF%s|r"
  local master = MF.db and MF.db.masterLoot
  return ("Set team loot (%s or %s)"):format(master and "FFA" or on:format("FFA"),
                                             master and on:format("master") or "master")
end

-- Sections of {key, label (text or function), tooltip} rows; each row is laid out on one line, two checkboxes side by
-- side.
local SECTIONS = {
  {
    "Group", {
      {"autoAccept", "Auto accept team invites", "Accept group invites from characters of your own team."}, {
        "autoInvite", "Auto invite team",
        "Slot 1 (when split in groups: each group's first slot) automatically invites team members as they come " ..
          "online."
      }
    }, {
      {
        "autoRaid", "Auto convert to raid",
        "Slot 1 invites the whole team, converting to a raid above 5. Off: the team is split in groups of the size " ..
          "on the right by slot (with 3: 1-3, 4-6...), each invited by its first slot. Either way, merge the groups " ..
          "into a raid or split them again for the session: Shift+Left click on the status window (or its " ..
          "raid/split button), or the key binding pressed on all windows (quicker)."
      }
    }, {
      {
        "autoFFA", teamLootLabel,
        "When you lead a full team group, set loot to free for all, or to master loot by the lead when master loot " ..
          "auto distribution is on (back to group loot if outsiders join). Off: the loot method is left alone."
      }, {
        "masterLoot", "Master loot auto distribution",
        "Master loot for the full team (with \"Set team loot\"), or when you pick master looter in the group menu: " ..
          "threshold down to greys (once, raise it again if you want), and the master looter gives each item to " ..
          "the team member who uses it (mats to the profession, armor to the class that wears it, quest items " ..
          "to whoever needs them, junk to the most bag space). " ..
          "Soulbound items wait for a click, the suggestion first. Hold Shift, Ctrl or Alt while opening the " ..
          "loot to give it by hand."
      }
    }
  }, {
    "Quests and dialogs", {
      {
        "autoQuest", "Auto accept quests",
        "Accept quests shared by your other windows (and quest dialogs) while grouped."
      },
      {
        "autoShare", "Auto share quests",
        "Share every quest you accept with the group so your other windows get it too."
      }
    }, {
      {
        "autoAbandon", "Abandon quests everywhere",
        "When you abandon a quest on one window, abandon it on the other windows (never completed quests)."
      }, {
        "autoDialog", "Mirror the lead's dialog choices",
        "When the lead picks a gossip option, quest or flight path, or clicks a popup button (spirit healer, " ..
          "resurrect, summon...), do the same if your window offers it."
      }
    }, {
      {
        "autoGossip", "Skip single option dialogs",
        "When an NPC offers only one option and no quest (most vendors and trainers), pick it: straight to the " ..
          "vendor. Same for an NPC offering only one quest to pick up, or only one completed quest to turn in. " ..
          "Hold Shift, Ctrl or Alt while opening the NPC to see the dialog."
      }
    }
  }, {
    "Follow, trade and merchants", {
      {
        "macro", "Maintain the MAMA macro",
        "Create a per character MAMA macro (a starter for your class) and keep its /follow and /assist lines " ..
          "pointing at the current lead. The rest of the macro is yours to edit."
      }, {
        "autoTrade", "Auto fill trades with mats",
        "When trading with a team member, put in the mats their professions use (cloth to the tailor, ore to the " ..
          "miner...). Which mats: the Trade page below this one."
      }
    }, {
      {
        "autoRepair", "Auto repair at merchants",
        "Repair all your gear when you open a merchant that can repair (after selling your sell list, /mama " ..
          "vendor). Off by default: early on, the money is better spent on training."
      }
    }
  }, {
    "Alerts to the lead", {
      {
        "followWarn", "Warn when follow breaks",
        "Out of combat, when this window stops following and the lead gets away (stuck behind something), or a " ..
          "follow key or macro doesn't start following, warn the lead's window."
      }, {
        "forwardWhispers", "Forward whispers to the lead",
        "Whispers from players outside the team are shown in the lead's window too."
      }
    }
  }, {
    "Display", {
      {"showStatus", "Show team status window", "Small window listing the team: click to target or invite."},
      {"identifyOnLogin", "Show slot on login", "Briefly show a big slot number, class and name at login."}
    }, {
      {
        "compact", "Compact status window",
        "Status window as a single line of slot numbers (colored like the rows); hover it for gold and bags. " ..
          "Also Shift+Right click on the window."
      }
    }
  }
}
local COLUMN = 300 -- x offset of the second checkbox of a row

-- Options sent by "Send settings to team" (all of the above).
local SYNCED = {}
for _, section in ipairs(SECTIONS) do
  for i = 2, #section do for _, o in ipairs(section[i]) do SYNCED[#SYNCED + 1] = o[1] end end
end

local checkboxes = {} -- {cb, get} for every checkbox of every panel

local function textOf(label) return type(label) == "function" and label() or label end

local groupSlider

local function Refresh()
  for _, c in ipairs(checkboxes) do
    c.cb:SetChecked(c.get())
    c.cb.Text:SetText(textOf(c.label))
  end
  if groupSlider then groupSlider:SetValue(MF.db.groupSize) end
end

-- "Group size" slider (2-5), right of `anchor` (the auto raid checkbox).
local function groupSizeSlider(panel, anchor)
  local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("LEFT", anchor, "LEFT", COLUMN + 6, 0)
  label:SetText("Group size")
  local s = CreateFrame("Frame", nil, panel, "MinimalSliderWithSteppersTemplate")
  s:SetSize(150, 20)
  s:SetPoint("LEFT", label, "RIGHT", 4, 0)
  local function round(v) return math.floor(v + 0.5) end
  s:Init(MF.db.groupSize, 2, 5, 3,
         {[MinimalSliderWithSteppersMixin.Label.Right] = function(v) return tostring(round(v)) end})
  s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged,
                     function(_, v) if round(v) ~= MF.db.groupSize then MF:SetOption("groupSize", round(v)) end end, s)
  s.Slider:HookScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText("Group size")
    GameTooltip:AddLine("Size of the groups the team splits in, by slot (with 3: 1-3, 4-6...): auto raid off, or " ..
                          "split for the session (Shift+Left click on the status window). Also " ..
                          "|cFF99E5FF/mama groups N|r.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  s.Slider:HookScript("OnLeave", GameTooltip_Hide)
  groupSlider = s
end

-- o: {label (text or function, for one that depends on other options), tooltip, get(), set(value)}; ...: SetPoint
-- arguments.
local function checkbox(panel, o, ...)
  local label, tip, get, set = o[1], o[2], o[3], o[4]
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetPoint(...)
  cb.Text:SetText(textOf(label))
  cb:SetScript("OnClick", function(b) set(b:GetChecked() and true or false) end)
  cb:SetScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(textOf(label))
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", GameTooltip_Hide)
  checkboxes[#checkboxes + 1] = {cb = cb, get = get, label = label}
  if o.key then checkboxes[o.key] = cb end
  return cb
end

-- Lays out {header, row, row...} sections below anchor, two checkboxes per row; returns the last row's left checkbox.
local function layout(panel, anchor, sections)
  local prev = anchor
  for _, section in ipairs(sections) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
    header:SetText(section[1])
    prev = header
    for i = 2, #section do
      local row = section[i]
      -- rows touch: the 32px checkbox art has its own padding (the main page must fit the ~600px Settings area,
      -- about one row left; split options into another page like Trade when it doesn't)
      local left = checkbox(panel, row[1], "TOPLEFT", prev, "BOTTOMLEFT", 0, prev == header and -2 or 0)
      if row[2] then checkbox(panel, row[2], "TOPLEFT", left, "TOPLEFT", COLUMN, 0) end
      prev = left
    end
  end
  return prev
end

local function newPanel(name, title, subtitle)
  local panel = CreateFrame("Frame")
  panel:Hide() -- new frames start shown: OnShow (values refresh) wouldn't fire the first time Settings shows it
  panel.name = name
  local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText(title)
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
  sub:SetText(subtitle)
  panel:SetScript("OnShow", Refresh)
  return panel, sub
end

local function sendButton(panel, anchor)
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(180, 24)
  b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  b:SetText("Send settings to team")
  b:SetScript("OnClick", function() MF:SendSettings() end)
  b:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Send settings to team")
    GameTooltip:AddLine("Copy this window's options, trade categories and status window position and size to the " ..
                          "other windows of the team (grouped or heard from).", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end

-- Turns SECTIONS' {key, label, tooltip} into checkbox specs on MF.db[key].
local function optionSections()
  local sections = {}
  for _, section in ipairs(SECTIONS) do
    local s = {section[1]}
    for i = 2, #section do
      local row = {}
      for j, o in ipairs(section[i]) do
        local key = o[1]
        row[j] = {
          o[2],
          o[3],
          function() return MF.db[key] end,
          function(v)
            MF.db[key] = v
            MF:Fire("OPTION_CHANGED", key)
          end,
          key = key
        }
      end
      s[i] = row
    end
    sections[#sections + 1] = s
  end
  return sections
end

-- One checkbox per trade category (Trade.lua), two per row.
local function tradeSections()
  local s = {"Mats given to team members"}
  local row
  for _, c in ipairs(MF.tradeCategories) do
    local key, label, default = c[1], c[2], c[3]
    local spec = {
      label:sub(1, 1):upper() .. label:sub(2),
      "Put " .. label .. " in trades with a team member whose professions use them (/mama trade " .. key .. ").",
      function() return MF:TradeCategoryOn(key, default) end, function(v)
        MF.db.tradeCats = MF.db.tradeCats or {}
        MF.db.tradeCats[key] = v
      end
    }
    if row and #row == 1 then
      row[2] = spec
    else
      row = {spec}
      s[#s + 1] = row
    end
  end
  return {s}
end

MF:Listen("LOGIN", function(self)
  local panel, sub = newPanel("Mama-forever", "Mama-forever (" .. self.version .. ")",
                              "Team setup: |cFF99E5FF/mama s N|r in each window. All commands: |cFF99E5FF/mama help|r")
  sendButton(panel, layout(panel, sub, optionSections()))
  groupSizeSlider(panel, checkboxes.autoRaid)
  self.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(self.category)

  local trade, tsub = newPanel("Trade", "Mama-forever: trade",
                               "When you trade with a team member, which mats go in (if they use them and you don't).")
  sendButton(trade, layout(trade, tsub, tradeSections()))
  if Settings.RegisterCanvasLayoutSubcategory then
    Settings.RegisterCanvasLayoutSubcategory(self.category, trade, trade.name)
  else
    self:Debug("no Settings.RegisterCanvasLayoutSubcategory: no trade options page")
  end
end)

-- Settings sync, to the group and the team members we heard from (whispering offline slots would only produce "no
-- player named" errors; split in groups, the others aren't in ours): "O;<options><group size>;<trade
-- categories>;<status window layout>", one 0/1 character per setting in SYNCED / MF.tradeCategories order, the group
-- size digit, then MF:StatusLayout(). All windows run the same addon version; a length mismatch (different versions)
-- is reported and ignored.
function MF:SendSettings()
  if not IsInGroup() and not next(self.online) then
    self:Error("settings are sent to the group and the team members heard from: none yet")
    return
  end
  local o, c = {}, {}
  for i, key in ipairs(SYNCED) do o[i] = self.db[key] and "1" or "0" end
  for i, cat in ipairs(self.tradeCategories) do c[i] = self:TradeCategoryOn(cat[1], cat[3]) and "1" or "0" end
  self:SendTeam("O;" .. table.concat(o) .. self.db.groupSize .. ";" .. table.concat(c) .. ";" .. self:StatusLayout(),
                true)
  self:Print("sent this window's settings to the team")
end

MF.messageHandlers.O = function(self, sender, rest)
  local o, size, c, window = rest:match("^([01]*)([2-5]?);([01]*);?(.*)$")
  if not o or #o ~= #SYNCED or #c ~= #self.tradeCategories then
    self:Error("ignoring settings from %s: not the same Mama version as this window", sender)
    return
  end
  local changed = {}
  for i, key in ipairs(SYNCED) do
    local value = o:sub(i, i) == "1"
    if self.db[key] ~= value then
      self.db[key] = value
      self:Fire("OPTION_CHANGED", key)
      changed[#changed + 1] = key .. (value and " on" or " off")
    end
  end
  size = tonumber(size)
  if size and size ~= self.db.groupSize then
    self:SetOption("groupSize", size)
    changed[#changed + 1] = "group size " .. size
  end
  for i, cat in ipairs(self.tradeCategories) do
    local value = c:sub(i, i) == "1"
    if self:TradeCategoryOn(cat[1], cat[3]) ~= value then
      self.db.tradeCats = self.db.tradeCats or {}
      self.db.tradeCats[cat[1]] = value
      changed[#changed + 1] = "trade " .. cat[1] .. (value and " on" or " off")
    end
  end
  if window ~= "" then
    local moved, err = self:SetStatusLayout(window)
    if moved then
      changed[#changed + 1] = "status window position"
    elseif err then
      changed[#changed + 1] = "status window position not applied (" .. err .. ")"
    end
  end
  self:Print("%s sent their settings: %s", sender, #changed > 0 and table.concat(changed, ", ") or "nothing changed")
  Refresh()
end

MF:Listen("OPTION_CHANGED", function(self, key)
  Refresh() -- also when changed by a command while the page is open
  if key == "macro" or key == "showStatus" then
    self:RefreshActions()
    self:RefreshStatus()
  elseif key == "compact" or key == "groupSize" or key == "autoRaid" then
    self:RefreshStatus()
  end
end)

MF:AddCommand("options", function(self) Settings.OpenToCategory(self.category:GetID()) end,
              "options - open the options panel")
