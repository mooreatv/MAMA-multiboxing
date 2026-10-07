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
      {"autoQuest", "Auto accept quests", "Accept quests shared by your other windows (and quest dialogs) while grouped."},
      {"autoShare", "Auto share quests", "Share every quest you accept with the group so your other windows get it too."}
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
      {"macro", "Maintain the MAMA macro", "Keep the account-wide MAMA follow + assist macro pointing at the current lead."},
      {
        "autoTrade", "Auto fill trades with mats",
        "When trading with a team member, put in the mats their professions use (cloth to the tailor, ore to the " ..
          "miner...). See /mama trade list."
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

local checkboxes = {}

local function Refresh() for key, cb in pairs(checkboxes) do cb:SetChecked(MF.db[key]) end end

MF:Listen("LOGIN", function(self)
  local panel = CreateFrame("Frame")
  panel.name = "Mama-forever"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Mama-forever")
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText("Team setup: |cFF99E5FF/mama s N|r in each window. All commands: |cFF99E5FF/mama help|r")
  local function checkbox(o, ...) -- ...: SetPoint arguments
    local key, label, tip = o[1], o[2], o[3]
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint(...)
    cb.Text:SetText(label)
    cb:SetScript("OnClick", function(b)
      self.db[key] = b:GetChecked() and true or false
      self:Fire("OPTION_CHANGED", key)
    end)
    cb:SetScript("OnEnter", function(b)
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:SetText(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    checkboxes[key] = cb
    return cb
  end
  local prev = sub -- left checkbox of the previous row (or section header)
  for _, section in ipairs(SECTIONS) do
    local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -16)
    header:SetText(section[1])
    prev = header
    for i = 2, #section do
      local row = section[i]
      local left = checkbox(row[1], "TOPLEFT", prev, "BOTTOMLEFT", 0, prev == header and -4 or -2)
      if row[2] then checkbox(row[2], "TOPLEFT", left, "TOPLEFT", COLUMN, 0) end
      prev = left
    end
  end
  panel:SetScript("OnShow", Refresh)
  self.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(self.category)
end)

MF:Listen("OPTION_CHANGED", function(self, key)
  if key == "macro" or key == "showStatus" then
    self:RefreshActions()
    self:RefreshStatus()
  end
end)

MF:AddCommand("options", function(self) Settings.OpenToCategory(self.category:GetID()) end,
              "options - open the options panel")
