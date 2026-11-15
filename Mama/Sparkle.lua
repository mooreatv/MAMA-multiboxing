--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Sparkles on quest items lying in the world (WoW Forever): the client draws its loot sparkle on them instead of the
-- (hard to see) outline when the hidden outlineModeShowLootEffectWhenDisabled cvar is on and the outline mode is
-- disabled. Graphics presets set both back, so they are checked again after a graphics change. The cvars are saved
-- by the game per PC: what we changed is kept (db.sparkleSaved) and put back when the option is turned off.
local _, MF = ...

local EFFECT = "outlineModeShowLootEffectWhenDisabled"
local OUTLINES = {"graphicsOutlineMode", "raidGraphicsOutlineMode"} -- the raid one: a team above 5 is a raid
local WATCHED = {graphicsquality = true, raidgraphicsquality = true, [EFFECT:lower()] = true}
for _, cvar in ipairs(OUTLINES) do WATCHED[cvar:lower()] = true end

local function set(self, cvar, value, why)
  local current = C_CVar.GetCVar(cvar)
  if current == nil or current == value then return false end
  self:Debug("sparkles: setting %s from %s to %s (%s)", cvar, current, value, why)
  C_CVar.SetCVar(cvar, value)
  return true
end

local pending -- reason of the change waiting for the end of combat
local told

function MF:ApplySparkles(why)
  if WOW_PROJECT_ID == 1 or C_CVar.GetCVar(EFFECT) == nil then return end
  if InCombatLockdown() then
    pending = why
    return
  end
  local db = self.db
  if db.questSparkle then
    db.sparkleSaved = db.sparkleSaved or {}
    local outlines
    for _, cvar in ipairs(OUTLINES) do
      local current = C_CVar.GetCVar(cvar)
      if set(self, cvar, "0", why) then
        db.sparkleSaved[cvar] = current
        outlines = true
      end
    end
    set(self, EFFECT, "1", why)
    if outlines and not told then
      told = true -- once per session, whatever sets the outlines back
      self:Print("quest item sparkles: outline graphics turned off on this PC (/mama sparkle off puts them back)")
    end
  elseif db.sparkleSaved then
    set(self, EFFECT, "0", why)
    for _, cvar in ipairs(OUTLINES) do if db.sparkleSaved[cvar] then set(self, cvar, db.sparkleSaved[cvar], why) end end
    db.sparkleSaved = nil
    self:Print("quest item sparkles off, outline graphics back as they were: turn it off on your other accounts' " ..
                 "windows too (or Send settings to team), then restart the game (a /reload isn't enough)")
  end
end

MF:Listen("LOGIN", function(self) self:ApplySparkles("login") end)

MF:Listen("OPTION_CHANGED", function(self, key) if key == "questSparkle" then self:ApplySparkles("option") end end)

MF:On("PLAYER_REGEN_ENABLED", function(self)
  if not pending then return end
  local why = pending
  pending = nil
  self:ApplySparkles(why)
end)

-- A graphics preset (or the raid settings) turning the outlines back on: our own changes end up here too, as no change.
local scheduled
MF:On("CVAR_UPDATE", function(self, cvar)
  if scheduled or type(cvar) ~= "string" or not WATCHED[cvar:lower()] or not self.db.questSparkle then return end
  scheduled = true
  self:After(1, function()
    scheduled = nil
    self:ApplySparkles("graphics change")
  end)
end)

MF:AddCommand("sparkle", function(self, rest)
  self:SetOption("questSparkle", self:ParseOnOff(rest, self.db.questSparkle))
  self:Print("sparkles on quest items are now %s", tostring(self.db.questSparkle))
end, "sparkle [on|off] - sparkles on quest items to pick up (WoW Forever; turns the outline graphics off)")
