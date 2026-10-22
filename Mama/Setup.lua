-- New character setup: at a level 1 character's first login, sets up what a new character always needs (action
-- bars 2-5, A/D turn and Q/E strafe, Mama keys, autoloot, the MAMA macro on button 1, Classic Edit Mode layout). Each step only
-- changes a setting still at its new character default, so nothing the user customized is undone.
local _, MF = ...

local BAR2_FIRST = 61 -- bar 2 (bottom left, action page 6): its first button sits right above button 1
local LAST_SLOT = 180 -- bars 6-8 use action pages 13-15

-- Bars 2-5 that are off are turned on (through the Settings proxies, so the options panel stays in sync).
local function showBars(done)
  local count = 0
  for n = 2, 5 do
    local setting = Settings.GetSetting("PROXY_SHOW_ACTIONBAR_" .. n)
    local shown = setting and setting:GetValue()
    MF:Debug("setup: action bar %d shown=%s", n, tostring(shown))
    if setting and not shown then
      setting:SetValue(true)
      count = count + 1
    end
  end
  if count > 0 then done[#done + 1] = ("%d more action bars"):format(count) end
end

-- For the debug log: an unbound key's action is "", a command without a key has nil.
local function orNone(s) return (s == nil or s == "") and "(none)" or s end

-- The modern default (A/D strafe, Q/E turn) is swapped; any other binding of these keys is left alone.
-- Bindings are account wide (and saved by the server), so this is a no-op once done on any character.
local SWAP = {
  A = {"STRAFELEFT", "TURNLEFT"},
  D = {"STRAFERIGHT", "TURNRIGHT"},
  Q = {"TURNLEFT", "STRAFELEFT"},
  E = {"TURNRIGHT", "STRAFERIGHT"}
}

local function swapKeys(done)
  local default = true
  for key, actions in pairs(SWAP) do
    local current = GetBindingAction(key)
    MF:Debug("setup: key %s is %s", key, orNone(current))
    if current ~= actions[1] then default = false end
  end
  if not default then return end
  for key, actions in pairs(SWAP) do SetBinding(key, actions[2]) end
  SaveBindings(GetCurrentBindingSet())
  done[#done + 1] = "A/D turn and Q/E strafe"
end

-- Bindings.xml defaults are ignored (https://github.com/Stanzilla/WoWUIBugs/issues/12), so they are set here: each
-- only when the key is free and the binding has no key yet. Same for "." = interact with target.
local MAMA_KEYS = {
  {"ALT-F", "CLICK MamaFollow:LeftButton", "Alt-F follow"}, {"ALT-T", "CLICK MamaTrain:LeftButton", "Alt-T train"},
  {"ALT-L", "MAMA_LEAD", "Alt-L lead"}, {".", "INTERACTTARGET", ". interact"}
}

local function mamaKeys(done)
  local set = {}
  for _, k in ipairs(MAMA_KEYS) do
    local key, command, label = k[1], k[2], k[3]
    local current, bound = GetBindingAction(key), GetBindingKey(command)
    MF:Debug("setup: key %s is %s, %s is on %s", key, orNone(current), command, orNone(bound))
    if (current or "") == "" and not bound then
      SetBinding(key, command)
      set[#set + 1] = label
    end
  end
  if #set == 0 then return end
  SaveBindings(GetCurrentBindingSet())
  done[#done + 1] = "keys (" .. table.concat(set, ", ") .. ")"
end

local function autoloot(done)
  if C_CVar.GetCVarBool("autoLootDefault") then return end
  C_CVar.SetCVar("autoLootDefault", "1")
  done[#done + 1] = "autoloot"
end

-- By name: for a macro showing a spell (#showtooltip), GetActionInfo's id is that spell's ID, not the macro index.
local function onBars(macro)
  local name = GetMacroInfo(macro)
  for slot = 1, LAST_SLOT do if GetActionInfo(slot) == "macro" and GetActionText(slot) == name then return slot end end
end

-- Puts the MAMA macro on button 1 (the slot it uses now: a warrior's stance page), moving what was there to the
-- first free button of bar 2. Returns false when the macro doesn't exist yet (try again at the next login).
local function placeMacro(done)
  if not MF.db.macro then return true end
  local macro = MF:MamaMacroIndex()
  if not macro then
    MF:Debug("setup: no MAMA macro yet")
    return false
  end
  local slot = onBars(macro)
  if slot then
    MF:Debug("setup: MAMA macro already on action slot %d", slot)
    return true
  end
  local main = ActionButton1 and ActionButton1.action or 1
  local free
  if HasAction(main) then
    for s = BAR2_FIRST, BAR2_FIRST + 11 do
      if not HasAction(s) then
        free = s
        break
      end
    end
    if not free then
      MF:Debug("setup: bar 2 is full, MAMA macro not placed")
      return true
    end
    PickupAction(main)
    PlaceAction(free)
  end
  PickupMacro(macro)
  PlaceAction(main)
  ClearCursor()
  MF:Debug("setup: MAMA macro on action slot %d, its action moved to %s", main, tostring(free))
  done[#done + 1] = free and "MAMA macro on 1 (what was there moved above it)" or "MAMA macro on 1"
  return true
end

-- Only from the Modern preset: a custom layout (or Classic already) is left alone. activeLayout indexes the preset
-- layouts first, then the saved ones (see Blizzard_EditMode's UpdateLayoutInfo).
local function classicLayout(done)
  local presets = EditModePresetLayoutManager and EditModePresetLayoutManager.presetLayoutInfo
  if not presets then return end
  local modern, classic
  for i, layout in ipairs(presets) do
    if layout.layoutIndex == Enum.EditModePresetLayouts.Modern then
      modern = i
    elseif layout.layoutIndex == Enum.EditModePresetLayouts.Classic then
      classic = i
    end
  end
  local active = C_EditMode.GetLayouts().activeLayout
  MF:Debug("setup: edit mode layout %s (modern %s, classic %s)", tostring(active), tostring(modern), tostring(classic))
  if not (modern and classic and active == modern) then return end
  C_EditMode.SetActiveLayout(classic)
  done[#done + 1] = "Classic layout"
end

-- force: run (again) whatever the level and whether it was already done; prints even when nothing changed.
function MF:NewCharSetup(force)
  if InCombatLockdown() then
    if force then self:Error("can't change action bars in combat") end
    return
  end
  local done = {}
  showBars(done)
  swapKeys(done)
  mamaKeys(done)
  autoloot(done)
  local placed = placeMacro(done)
  classicLayout(done)
  if placed then self.db.chars[self.myName].setup = true end
  if #done > 0 then
    self:Print("new character setup: %s (/mama setup off: not for the next ones)", table.concat(done, ", "))
  elseif force then
    self:Print("new character setup: nothing to change")
  end
end

MF:Listen("LOGIN", function(self)
  if self.db.chars[self.myName].setup or not self.db.autoSetup or UnitLevel("player") ~= 1 then return end
  -- after Actions.lua's second macro check (3s), so the MAMA macro exists
  C_Timer.After(4, function() if not self:Disabled() then self:NewCharSetup() end end)
end)

MF:AddCommand("setup", function(self, rest)
  local arg = rest:lower()
  if arg == "now" then
    self:NewCharSetup(true)
    return
  end
  if arg == "on" or arg == "off" then self:SetOption("autoSetup", arg == "on") end
  self:Print("new character setup (at a level 1 character's first login) is now %s", tostring(self.db.autoSetup))
end, "setup [on|off|now] - show or set whether a level 1 character's first login turns on bars 2-5, swaps A/D " ..
                "(turn) and Q/E (strafe), binds Alt-F/T/L (follow, train, lead) and . (interact), autoloot, puts the MAMA macro " ..
                "on 1 and picks the Classic layout, each only if still at its default; now does it on this character")
