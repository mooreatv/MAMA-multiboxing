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

-- Sections of {key, label, tooltip} rows; each row is laid out on one line, two checkboxes side by side.
local SECTIONS = {
  {
    "Group", {
      {"autoAccept", "Auto accept team invites", "Accept group invites from characters of your own team."},
      {"autoInvite", "Auto invite team (slot 1)", "Slot 1 automatically invites team members as they come online."}
    }, {
      {"autoRaid", "Auto convert to raid", "Convert the group to a raid when inviting more than 5 characters."}, {
        "autoFFA", "Free for all loot",
        "When you lead a full team group, set loot to free for all (back to group loot if outsiders join)."
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
        "When the lead picks a gossip option, quest or flight path, pick the same one if your dialog offers it."
      }
    }
  }, {
    "Follow and trade", {
      {
        "macro", "Maintain the MAMA macro",
        "Keep the account-wide MAMA follow + assist macro pointing at the current lead."
      }, {
        "autoTrade", "Auto fill trades with mats",
        "When trading with a team member, put in the mats their professions use (cloth to the tailor, ore to the " ..
          "miner...). Which mats: the Trade page below this one."
      }
    }
  }, {
    "Display", {
      {"showStatus", "Show team status window", "Small window listing the team: click to target or invite."},
      {"identifyOnLogin", "Show slot on login", "Briefly show a big slot number, class and name at login."}
    }, {{"debug", "Debug output", "Print detailed messages to the chat window."}}
  }
}
local COLUMN = 300 -- x offset of the second checkbox of a row

-- Options sent by "Send settings to team" (all of the above).
local SYNCED = {}
for _, section in ipairs(SECTIONS) do
  for i = 2, #section do for _, o in ipairs(section[i]) do SYNCED[#SYNCED + 1] = o[1] end end
end

local checkboxes = {} -- {cb, get} for every checkbox of every panel

local function Refresh() for _, c in ipairs(checkboxes) do c.cb:SetChecked(c.get()) end end

-- o: {label, tooltip, get(), set(value)}; ...: SetPoint arguments.
local function checkbox(panel, o, ...)
  local label, tip, get, set = o[1], o[2], o[3], o[4]
  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetPoint(...)
  cb.Text:SetText(label)
  cb:SetScript("OnClick", function(b) set(b:GetChecked() and true or false) end)
  cb:SetScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(label)
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", GameTooltip_Hide)
  checkboxes[#checkboxes + 1] = {cb = cb, get = get}
  return cb
end

-- Lays out {header, row, row...} sections below anchor, two checkboxes per row; returns the last row's left checkbox.
local function layout(panel, anchor, sections)
  local prev = anchor
  for _, section in ipairs(sections) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -16)
    header:SetText(section[1])
    prev = header
    for i = 2, #section do
      local row = section[i]
      local left = checkbox(panel, row[1], "TOPLEFT", prev, "BOTTOMLEFT", 0, prev == header and -4 or -2)
      if row[2] then checkbox(panel, row[2], "TOPLEFT", left, "TOPLEFT", COLUMN, 0) end
      prev = left
    end
  end
  return prev
end

local function newPanel(name, title, subtitle)
  local panel = CreateFrame("Frame")
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
  b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  b:SetText("Send settings to team")
  b:SetScript("OnClick", function() MF:SendSettings() end)
  b:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText("Send settings to team")
    GameTooltip:AddLine("Copy this window's options and trade categories to the other windows of the " .. "group.", 1,
                        1, 1, true)
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
          o[2], o[3], function() return MF.db[key] end, function(v)
            MF.db[key] = v
            MF:Fire("OPTION_CHANGED", key)
          end
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
  local panel, sub = newPanel("Mama-forever", "Mama-forever",
                              "Team setup: |cFF99E5FF/mama s N|r in each window. All commands: |cFF99E5FF/mama help|r")
  sendButton(panel, layout(panel, sub, optionSections()))
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

-- Settings sync, to the group only (whispering offline slots would only produce "no player named" errors):
-- "O;<options>;<trade categories>", one 0/1 character per setting in SYNCED / MF.tradeCategories order. All windows
-- run the same addon version; a length mismatch (different versions) is reported and ignored.
function MF:SendSettings()
  if not IsInGroup() then
    self:Print("settings are sent to the group: invite the team first")
    return
  end
  local o, c = {}, {}
  for i, key in ipairs(SYNCED) do o[i] = self.db[key] and "1" or "0" end
  for i, cat in ipairs(self.tradeCategories) do c[i] = self:TradeCategoryOn(cat[1], cat[3]) and "1" or "0" end
  self:SendGroup("O;" .. table.concat(o) .. ";" .. table.concat(c))
  self:Print("sent this window's settings to the group")
end

MF.messageHandlers.O = function(self, sender, rest)
  local o, c = rest:match("^([01]*);([01]*)$")
  if not o or #o ~= #SYNCED or #c ~= #self.tradeCategories then
    self:Print("ignoring settings from %s: not the same Mama version as this window", sender)
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
  for i, cat in ipairs(self.tradeCategories) do
    local value = c:sub(i, i) == "1"
    if self:TradeCategoryOn(cat[1], cat[3]) ~= value then
      self.db.tradeCats = self.db.tradeCats or {}
      self.db.tradeCats[cat[1]] = value
      changed[#changed + 1] = "trade " .. cat[1] .. (value and " on" or " off")
    end
  end
  self:Print("%s sent their settings: %s", sender, #changed > 0 and table.concat(changed, ", ") or "nothing changed")
  Refresh()
end

MF:Listen("OPTION_CHANGED", function(self, key)
  if key == "macro" or key == "showStatus" then
    self:RefreshActions()
    self:RefreshStatus()
  end
end)

MF:AddCommand("options", function(self) Settings.OpenToCategory(self.category:GetID()) end,
              "options - open the options panel")
