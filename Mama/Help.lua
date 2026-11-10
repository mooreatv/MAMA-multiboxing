--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Help window (/mama, /mama help, "?" or Alt+Middle on the status window, Help on the options page): the status
-- window's mouse shortcuts, Mama's key bindings with their current keys, then every /mama command by topic, with
-- buttons to the options, the key bindings and the log.
local _, MF = ...

local KEY = "|cFF99E5FF%s|r"

-- Mouse shortcuts grid: one line per mouse button, one column per modifier.
local CLICK_COLUMNS = {"", "Plain", "Shift", "Ctrl", "Alt"}
local CLICK_ROWS = {
  {
    "Left", "Invite the team (our group when split)", "Merge groups into a raid / split again (or party / raid)",
    "Auto invite on/off", "Resend our info to the team"
  },
  {"Right", "Options", "Compact view", "Show / paste the team token", "Team complete (forget slots that aren't here)"},
  {
    "Middle", "Disband (leader uninvites the team, others leave)", "Big slot number", "Mama off/on for this character",
    "This help"
  }
}
local CLICK_NOTES = {
  ("On a member row: %s targets it (invites it when not grouped), %s its unit menu, %s away/back (no invites, " ..
    "follow alerts, quest or dialog sync). Other clicks: same as the title."):format(KEY:format("Left"),
                                                                                     KEY:format("Right"),
                                                                                     KEY:format("Alt+Left")),
  ("%s the title to move the window, %s to resize it. Hover the bottom line (the title in compact view) for every " ..
    "character's gold and free bag slots."):format(KEY:format("Drag"), KEY:format("Mouse wheel"))
}

-- Commands by topic, in this order; a registered command missing here (a new one) goes under "Other".
local TOPICS = {
  {"Team setup", {"s", "token", "team", "complete", "away", "back", "status"}},
  {"Group and lead", {"invite", "autoinvite", "disband", "raid", "merge", "split", "groups", "lead"}},
  {"Follow, quests and dialogs", {"macro", "quest", "dialog", "gossip", "setup"}},
  {"Loot, trade and merchants", {"loot", "trade", "vendor", "profs"}},
  {"Display", {"ui", "identify", "options", "help", "clicks"}},
  {"This character, problems", {"enable", "disable", "bug", "clearlog", "debug"}}
}

local WIDTH, PAD, TOP, BAR = 640, 14, 58, 34 -- TOP: title and buttons above the scroll area; BAR: scroll bar room
local SYNTAX_W = 210 -- command column

-- A literal "|" before r, n, c... is an escape sequence in font strings ("off|reset" shows as "offeset").
local function esc(s) return (s:gsub("|", "||")) end

local helpFrame
local bindingKeys = {} -- {font string, binding action}

local function openBindings()
  if Settings.KEYBINDINGS_CATEGORY_ID then
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_MAMAFOREVER)
  else
    MF:Error("no key bindings page found: Game Menu > Options > Key bindings")
  end
end

local function topButton(f, label, tip, x, fn)
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetSize(110, 22)
  b:SetPoint("TOPLEFT", x, -28)
  b:SetText(label)
  b:SetScript("OnClick", function()
    f:Hide() -- would cover what it opens
    MF:Call(fn)
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(tip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
end

local function Build()
  local f = CreateFrame("Frame", "MamaForeverHelp", UIParent, "BasicFrameTemplateWithInset")
  f:Hide() -- new frames start shown: the first toggle would hide it
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetPoint("CENTER", 0, 50)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, f:GetName()) -- Escape closes it
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -5)
  title:SetText(("Mama-forever %s: help"):format(MF.version or ""))
  topButton(f, "Options", "Mama's options (/mama options)", PAD, function() MF.commands.options.fn(MF) end)
  topButton(f, "Key bindings", "The game's key bindings, Mama-forever section", PAD + 120, openBindings)
  topButton(f, "Log", "Copyable log for a bug report (/mama bug)", PAD + 240, function() MF:ShowBug() end)

  local scroll = CreateFrame("ScrollFrame", "MamaForeverHelpScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", PAD, -TOP)
  scroll:SetPoint("BOTTOMRIGHT", -BAR, 10)
  local c = CreateFrame("Frame", nil, scroll)
  local cw = WIDTH - PAD - BAR
  c:SetWidth(cw)
  scroll:SetScrollChild(c)

  local y = 0
  local function text(s, font, x, w)
    local fs = c:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    fs:SetText(s)
    return fs
  end
  local function heading(s)
    y = y - 8
    local fs = text(s, "GameFontNormalLarge", 0, cw)
    y = y - fs:GetStringHeight() - 6
  end
  local function para(s)
    local fs = text(s, "GameFontHighlightSmall", 0, cw)
    y = y - fs:GetStringHeight() - 6
  end
  -- one line of columns {text, width}; first column in the label font
  local function row(cells, header)
    local h, x = 0, 0
    for i, cell in ipairs(cells) do
      local font = (header or i == 1) and "GameFontNormalSmall" or "GameFontHighlightSmall"
      local fs = text(cell[1], font, x, cell[2] - 8)
      h = math.max(h, fs:GetStringHeight())
      x = x + cell[2]
    end
    y = y - h - 6
  end

  heading("Status window: mouse shortcuts")
  local first = 60
  local col = math.floor((cw - first) / (#CLICK_COLUMNS - 1))
  local function gridRow(cells, header)
    local r = {}
    for i, s in ipairs(cells) do r[i] = {s, i == 1 and first or col} end
    row(r, header)
  end
  gridRow(CLICK_COLUMNS, true)
  for _, cells in ipairs(CLICK_ROWS) do gridRow(cells) end
  for _, note in ipairs(CLICK_NOTES) do para(note) end

  heading("Key bindings")
  para("Set them with the Key bindings button above (Mama-forever section); they are account wide.")
  for i = 1, GetNumBindings() do
    local action, cat = GetBinding(i)
    if cat == "BINDING_HEADER_MAMAFOREVER" then
      local label = text(_G["BINDING_NAME_" .. action] or action, "GameFontHighlightSmall", 0, cw - 160)
      bindingKeys[#bindingKeys + 1] = {text("", "GameFontNormalSmall", cw - 150, 150), action}
      y = y - label:GetStringHeight() - 4
    end
  end

  heading("Commands")
  para(("Type %s in chat; [ ] parts are optional, a bare [on||off] toggles."):format(KEY:format("/mama <command>")))
  local listed = {}
  local function command(name)
    local cmd = MF.commands[name]
    if not cmd or listed[name] then return end
    listed[name] = true
    local syntax, desc = cmd.help:match("^(.-) %- (.*)$")
    if not syntax then syntax, desc = cmd.help, "" end
    row({{KEY:format("/mama " .. esc(syntax)), SYNTAX_W}, {esc(desc), cw - SYNTAX_W}})
  end
  for _, topic in ipairs(TOPICS) do
    y = y - 4
    local fs = text(topic[1], "GameFontNormal", 0, cw)
    y = y - fs:GetStringHeight() - 4
    for _, name in ipairs(topic[2]) do command(name) end
  end
  local others = {}
  for _, name in ipairs(MF.commandOrder) do if not listed[name] then others[#others + 1] = name end end
  if #others > 0 then
    y = y - 4
    local fs = text("Other", "GameFontNormal", 0, cw)
    y = y - fs:GetStringHeight() - 4
    for _, name in ipairs(others) do command(name) end
  end

  c:SetHeight(-y + 4)
  f:SetSize(WIDTH, math.min(TOP + 10 - y + 8, UIParent:GetHeight() * 0.85))
  return f
end

local function refreshKeys()
  for _, b in ipairs(bindingKeys) do
    local k1, k2 = GetBindingKey(b[2])
    if k1 then
      b[1]:SetText(GetBindingText(k1) .. (k2 and (", " .. GetBindingText(k2)) or ""))
    else
      b[1]:SetText("|cFF808080not bound|r")
    end
  end
end

-- Shows the help window (with a chat line); toggle (status window clicks): hides it instead when it's already shown.
function MF:ShowHelp(toggle)
  self:Call(function()
    helpFrame = helpFrame or Build()
    if helpFrame:IsShown() then
      if toggle then
        helpFrame:Hide()
      else
        self:Print("see the open help window")
        helpFrame:Raise()
      end
      return
    end
    self:Print("opening the help window")
    refreshKeys() -- keys may have changed since
    helpFrame:Show()
    helpFrame:Raise()
  end)
end

MF:AddCommand("clicks", function(self) self:ShowHelp() end, "clicks - same as help")
