-- TEMPORARY: logs dialog events, frame visibility and every call of the dialog functions. Remove with its Mama.toc line.
-- Always on after /reload; "/mama dprobe" dumps what the currently open dialog offers.

local _, MF = ...

local MAX_LINES = 300 -- about 30 dialog interactions

-- Also appended to MamaForeverSaved.probe, which is written to the saved variables file on /reload or logout.
local function p(...)
  if MF.db and MF.db.debug then print("|cFFFFA500DP:|r", ...) end
  if not MamaForeverSaved then return end
  local log = MamaForeverSaved.probe
  if not log then
    log = {}
    MamaForeverSaved.probe = log
  end
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  log[#log + 1] = ("%s %s %s"):format(date("%H:%M:%S"), GetUnitName("player") or "?", table.concat(t, " "))
  if #log > MAX_LINES then table.remove(log, 1) end
end

local function args(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  return table.concat(t, ", ")
end

local FRAMES = {"GossipFrame", "QuestFrame", "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel",
                "QuestFrameRewardPanel", "TaxiFrame"}

local function frames()
  local t = {}
  for _, n in ipairs(FRAMES) do
    local f = _G[n]
    if f and f:IsShown() then t[#t + 1] = n end
  end
  return #t > 0 and table.concat(t, " ") or "(none)"
end

local function call(fn, ...)
  if type(fn) ~= "function" then return "n/a" end
  local ok, a, b, c = pcall(fn, ...)
  return ok and args(a, b, c) or ("err " .. tostring(a))
end

local function dumpTable(label, t)
  for i, v in ipairs(t or {}) do
    local parts = {}
    for k, val in pairs(v) do parts[#parts + 1] = k .. "=" .. tostring(val) end
    table.sort(parts)
    p(label, i, table.concat(parts, " "))
  end
end

local function state(tag)
  p(tag, "frames:", frames(), "| npc guid:", call(UnitGUID, "npc"), "| questID:", call(GetQuestID))
end

local function dump()
  state("dump")
  if C_GossipInfo then
    dumpTable("gossip option", call(C_GossipInfo.GetOptions) == "n/a" and {} or C_GossipInfo.GetOptions())
    dumpTable("gossip available", C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests())
    dumpTable("gossip active", C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests())
  end
  p("greeting counts (active, available):", call(GetNumActiveQuests), call(GetNumAvailableQuests))
  for i = 1, tonumber((call(GetNumActiveQuests))) or 0 do p("greeting active", i, call(GetActiveTitle, i)) end
  for i = 1, tonumber((call(GetNumAvailableQuests))) or 0 do p("greeting available", i, call(GetAvailableTitle, i)) end
  p("completable:", call(IsQuestCompletable), "| num choices:", call(GetNumQuestChoices))
  for i = 1, tonumber((call(GetNumQuestChoices))) or 0 do p("reward choice", i, call(GetQuestItemLink, "choice", i)) end
  if TaxiFrame and TaxiFrame:IsShown() then
    for i = 1, NumTaxiNodes() do p("taxi", i, TaxiNodeName(i), TaxiNodeGetType(i)) end
  end
end

local EVENTS = {"GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_CONFIRM", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
                "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "TAXIMAP_OPENED", "TAXIMAP_CLOSED"}
for _, ev in ipairs(EVENTS) do
  MF:On(ev, function(_, ...)
    state("EVENT " .. ev .. " (" .. args(...) .. ")")
    C_Timer.After(0, function() state("  ...next frame after " .. ev) end)
  end)
end

local FUNCS = {"SelectGossipOption", "SelectAvailableQuest", "SelectActiveQuest", "CompleteQuest", "GetQuestReward", "AcceptQuest",
               "DeclineQuest", "TakeTaxiNode", "CloseGossip", "CloseQuest", "CloseTaxiMap"}

MF:Listen("LOGIN", function()
  for _, n in ipairs(FUNCS) do
    if type(_G[n]) == "function" then
      hooksecurefunc(n, function(...)
        p("CALL " .. n .. "(" .. args(...) .. ")", "frames:", frames(), "| questID:", call(GetQuestID), "| taxi1:",
          call(TaxiNodeName, 1))
      end)
    end
  end
  for k, f in pairs(C_GossipInfo or {}) do
    if type(f) == "function" and (k:find("^Select") or k:find("^Close")) then
      hooksecurefunc(C_GossipInfo, k, function(...)
        p("CALL C_GossipInfo." .. k .. "(" .. args(...) .. ")", "frames:", frames())
      end)
    end
  end
  for k, f in pairs(C_TaxiMap or {}) do
    if type(f) == "function" and (k:find("^Take") or k:find("^Select") or k:find("^Close")) then
      hooksecurefunc(C_TaxiMap, k, function(...) p("CALL C_TaxiMap." .. k .. "(" .. args(...) .. ")", "frames:", frames()) end)
    end
  end
  local tf = {}
  for k, v in pairs(_G) do
    if type(k) == "string" and (k:find("Taxi") or k:find("Flight")) and type(v) == "table" and v.IsShown then tf[#tf + 1] = k end
  end
  table.sort(tf)
  p("taxi/flight frames:", table.concat(tf, " "))
  local present = {}
  for _, n in ipairs({"SelectGossipOption", "SelectAvailableQuest", "SelectActiveQuest", "GetActiveTitle", "GetAvailableTitle",
                      "CompleteQuest", "GetQuestReward", "TakeTaxiNode", "TaxiNodeGetType", "GetGossipOptions"}) do
    present[#present + 1] = n .. "=" .. type(_G[n])
  end
  p("globals:", table.concat(present, " "))
  local c = {}
  for k in pairs(C_GossipInfo or {}) do c[#c + 1] = k end
  table.sort(c)
  p("C_GossipInfo:", table.concat(c, " "))
end)

MF:AddCommand("dprobe", function(self, rest)
  if rest == "clear" then
    MamaForeverSaved.probe = {}
    self:Print("probe log cleared")
    return
  end
  if rest ~= "" then
    p("NOTE", rest) -- label what you're about to do, e.g. /mama dprobe now returning quest
    return
  end
  dump()
end, "dprobe [clear|note text] - TEMPORARY: dump what the open dialog offers / clear or annotate the probe log")
