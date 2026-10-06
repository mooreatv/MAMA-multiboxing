-- Comm: one-time pairing of our own windows (slot + shared token) and the signed addon-message protocol.
--
-- Setup, once per window:  /mama s 1  (first window: shows a token to copy)
--                          /mama s 2  (second window: paste the token, Enter), etc.
-- The token is "teamId:secret:MasterName" + 1 checksum character. Every message is signed with the secret
-- and carries a timestamp so strangers can't spoof us and old messages can't be replayed.
-- Messages are whispered to the master (slot 1) by full name (works ungrouped and across home realms)
-- and sent on the party/raid channel once grouped. The master relays who is on the team.
local _, MF = ...

local PREFIX = "MAMAFOREVER"
MF.maxSlot = 40
MF.online = {} -- names we've heard from directly this session

local ALNUM = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local HEX = "0123456789ABCDEF"
local MOD = 4294967296
local FUTURE_LIMIT, PAST_LIMIT = -5, 120 -- seconds a message may be from the future / past

local function now() return GetServerTime() end

local function randomId(n)
  local t = {}
  for i = 1, n do
    local k = math.random(#ALNUM)
    t[i] = ALNUM:sub(k, k)
  end
  return table.concat(t)
end

-- Two 32 bit non cryptographic hashes (djb2 and sdbm style) in plain arithmetic, so no bit library is needed.
local function hashes(str)
  local h1, h2 = 5381, 0
  for i = 1, #str do
    local c = str:byte(i)
    h1 = (h1 * 33 + c) % MOD
    h2 = (c + h2 * 65599) % MOD
  end
  return h1, h2
end

local function toHex(n)
  local r = {}
  for i = 8, 1, -1 do
    local v = n % 16
    n = (n - v) / 16
    r[i] = HEX:sub(v + 1, v + 1)
  end
  return table.concat(r)
end

local function checkChar(str)
  local a, b = hashes(str)
  local k = (a + b) % #ALNUM
  return ALNUM:sub(k + 1, k + 1)
end

function MF:Sign(str, secret)
  local a, b = hashes(str .. secret)
  return toHex(a) .. toHex(b)
end

function MF:MakeToken(master)
  local body = randomId(6) .. ":" .. randomId(12) .. ":" .. master .. ":"
  return body .. checkChar(body)
end

-- Returns {team, secret, master} or nil when the text isn't a valid token (typo, truncated paste...).
function MF:ParseToken(text)
  if type(text) ~= "string" then return nil end
  text = text:match("^%s*(.-)%s*$")
  local body, check = text:match("^(.+:)(%w)$")
  if not body or checkChar(body) ~= check then return nil end
  local team, secret, master = body:match("^(%w+):(%w+):(.+):$")
  if not team then return nil end
  return {team = team, secret = secret, master = master}
end

function MF:Token() return self.db.token and self:ParseToken(self.db.token) or nil end

-- One account wide token; the per faction part is the slot map and candidate history (no cross faction grouping).
-- tokenFaction remembers which faction the token's master character belongs to.
function MF:SetToken(text)
  self.db.token = text
  self.db.tokenFaction = text and self.faction or nil
end

function MF:TokenText() return self.db.token or "" end

-- Slot 1 of each faction is that faction's master: it is the one invited by / inviting the other slots.
function MF:IsMaster() return self:Token() ~= nil and self.db.slot == 1 end

-- Full name to whisper as our master: the slot 1 we know in this faction, else the token's master if same faction.
function MF:MasterTarget()
  local m = self.db.slots[1]
  if m and m ~= self.myName then return m end
  local tok = self:Token()
  if tok and tok.master ~= self.myName and self.db.tokenFaction == self.faction then return tok.master end
end

function MF:SecureMessage(payload, tok)
  local base = ("%s:%s:%s:%d:"):format(tok.team, payload, randomId(4), now())
  return base .. self:Sign(base, tok.secret)
end

-- Returns true, payload for a valid message of our team; false, reason otherwise.
function MF:VerifyMessage(msg, tok)
  local base, team, payload, ts, sig = msg:match("^(([^:]+):(.-):%w%w%w%w:(%d+):)(%x+)$")
  if not base then return false, "malformed" end
  if team ~= tok.team then return false, "other team" end
  if self:Sign(base, tok.secret) ~= sig then return false, "bad signature" end
  local delta = now() - tonumber(ts)
  if delta < FUTURE_LIMIT then return false, "from the future" end
  if delta > PAST_LIMIT then return false, "too old" end
  return true, payload
end

-- Addon messages are throttled: space our sends out a bit.
local nextSend = 0
local function schedule(fn)
  local t = GetTime()
  local at = math.max(t, nextSend)
  nextSend = at + 0.25
  if at <= t then
    fn()
  else
    C_Timer.After(at - t, fn)
  end
end

function MF:SendWhisper(to, payload)
  local tok = self:Token()
  if not tok or to == self.myName then return end
  local msg = self:SecureMessage(payload, tok)
  schedule(function()
    self:Debug("whisper to %s: %s", to, payload)
    C_ChatInfo.SendAddonMessage(PREFIX, msg, "WHISPER", to)
  end)
end

function MF:SendGroup(payload)
  local tok = self:Token()
  if not tok or not IsInGroup() then return end
  local msg = self:SecureMessage(payload, tok)
  schedule(function()
    self:Debug("group msg: %s", payload)
    C_ChatInfo.SendAddonMessage(PREFIX, msg, IsInRaid() and "RAID" or "PARTY")
  end)
end

local function infoPayload(slot, name, flag) return ("I;%d;%s;%d"):format(slot, name, flag) end

-- flag 1 means "please tell me about yourself too", flag 0 is a plain information message.
function MF:SendInfo(to, flag) self:SendWhisper(to, infoPayload(self.db.slot, self.myName, flag)) end

local MAX_PER_SLOT = 3 -- most recent characters of this faction to try per slot

-- Everyone who might be our teammate: current slot owners plus the recent holders of each slot (newest first).
function MF:Candidates()
  local seen, list = {}, {}
  local function add(name)
    if name and name ~= self.myName and not seen[name] then
      seen[name] = true
      list[#list + 1] = name
    end
  end
  for s, name in pairs(self.db.slots) do if s ~= self.db.slot then add(name) end end
  for s, names in pairs(self.db.history[self.faction] or {}) do
    if s ~= self.db.slot then for i = 1, math.min(#names, MAX_PER_SLOT) do add(names[i]) end end
  end
  return list
end

-- Guild addon messages are the only broadcast channel left (say/yell addon messages don't exist in Forever).
function MF:Broadcast(payload)
  local tok = self:Token()
  if not tok or not IsInGuild() then return end
  local msg = self:SecureMessage(payload, tok)
  schedule(function()
    self:Debug("broadcast on GUILD: %s", payload)
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
  end)
end

function MF:AnnounceDirect()
  local tok = self:Token()
  if not tok then return end
  local sent = {}
  local master = self:MasterTarget()
  if master then
    self:SendInfo(master, 1)
    sent[master] = true
  end
  for _, name in ipairs(self:Candidates()) do
    if not sent[name] and not self.roster[name] then self:SendInfo(name, 1) end
  end
  self:Broadcast(infoPayload(self.db.slot, self.myName, 1))
end

function MF:Announce()
  local tok = self:Token()
  if self.db.slot == 0 or not tok then return end
  self:AnnounceDirect()
  self:SendGroup(infoPayload(self.db.slot, self.myName, 1))
  self:KeepAnnouncing()
end

-- Whispers to offline characters are silently lost, so keep announcing until we hear from someone directly.
local retryRunning
function MF:KeepAnnouncing()
  if retryRunning then return end
  retryRunning = true
  local function tick()
    if next(self.online) or self.db.slot == 0 or not self:Token() then
      retryRunning = false
      return
    end
    C_Timer.After(20, function()
      if next(self.online) or self.db.slot == 0 or not self:Token() then
        retryRunning = false
        return
      end
      self:Debug("nobody heard from yet, announcing again")
      self:AnnounceDirect()
      tick()
    end)
  end
  tick()
end

function MF:SlotOf(name) for s, n in pairs(self.db.slots) do if n == name then return s end end end

function MF:SetOwnSlot()
  local slots = self.db.slots
  for s, n in pairs(slots) do if n == self.myName or s == self.db.slot then slots[s] = nil end end
  if self.db.slot > 0 then slots[self.db.slot] = self.myName end
end

function MF:RecordMember(slot, name)
  if name == self.myName then return end
  if slot < 1 or slot > self.maxSlot then return end
  if slot == self.db.slot then
    self:Print("|cFFFF0000warning:|r %s also claims our slot %d, each window needs its own slot", name, slot)
    return
  end
  local slots = self.db.slots
  local changed = slots[slot] ~= name
  for s, n in pairs(slots) do
    if n == name and s ~= slot then
      slots[s] = nil -- the character moved to another slot
      changed = true
    end
  end
  slots[slot] = name
  self.db.team[name] = true -- verified team member: auto-accept their invites
  local hist = self.db.history[self.faction]
  hist[slot] = hist[slot] or {}
  for i = #hist[slot], 1, -1 do if hist[slot][i] == name then table.remove(hist[slot], i) end end
  table.insert(hist[slot], 1, name)
  while #hist[slot] > 5 do table.remove(hist[slot]) end
  if changed then
    self:Print("slot %d is %s", slot, name)
    self:Fire("TEAM_CHANGED")
  end
end

function MF:HandleInfo(sender, slot, name, flag)
  local direct = sender == name -- otherwise it's relayed by the master
  self:RecordMember(slot, name)
  if direct and not self.online[name] then
    self.online[name] = true
    self:Fire('TEAM_CHANGED')
  end
  if flag == 1 and direct then self:SendInfo(name, 0) end
  if direct then
    self:Debug("invite check for %s: autoInvite=%s master=%s grouped=%s", name, tostring(self.db.autoInvite),
               tostring(self:IsMaster()), tostring(self.roster[name] ~= nil))
  end
  if direct and self.db.autoInvite and self:IsMaster() and not self.roster[name] then self:ScheduleInvites() end
  if direct and self:IsMaster() then
    for s, n in pairs(self.db.slots) do
      if n ~= name and n ~= self.myName then
        if self.online[n] then self:SendWhisper(n, infoPayload(slot, name, 0)) end -- tell them about the newcomer
        self:SendWhisper(name, infoPayload(s, n, 0)) -- tell the newcomer about them
      end
    end
  end
end

MF:On("CHAT_MSG_ADDON", function(self, prefix, text, channel, sender)
  if prefix ~= PREFIX then return end
  self:Debug("received addon msg on %s from %s", tostring(channel), tostring(sender))
  if sender == self.myName then return end
  local tok = self:Token()
  if not tok then
    self:Debug("ignoring message from %s: we have no token", tostring(sender))
    return
  end
  local ok, payload = self:VerifyMessage(text, tok)
  if not ok then
    self:Debug("ignoring message from %s: %s", tostring(sender), payload)
    return
  end
  self:Debug("valid message from %s: %s", tostring(sender), payload)
  local kind, rest = payload:match("^(%a);(.*)$")
  local handler = kind and self.messageHandlers[kind]
  if handler then handler(self, sender, rest) end
end)

-- kind letter -> function(MF, sender, rest of payload) lives in MF.messageHandlers (defined in Core.lua).
MF.messageHandlers.I = function(self, sender, rest)
  local slot, name, flag = rest:match("^(%d+);([^;]+);(%d)$")
  if slot then self:HandleInfo(sender, tonumber(slot), name, tonumber(flag)) end
end

-- Send to every other team member we know: one group message for those grouped with us, whispers for the rest.
function MF:SendTeam(payload)
  local anyGrouped = false
  for _, name in pairs(self.db.slots) do
    if name ~= self.myName then
      if self.roster[name] then
        anyGrouped = true
      else
        self:SendWhisper(name, payload)
      end
    end
  end
  if anyGrouped then self:SendGroup(payload) end
end

MF:Listen("LOGIN", function(self)
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  self:SetOwnSlot()
  C_Timer.After(5, function() self:Announce() end)
end)

MF:On("GROUP_ROSTER_UPDATE", function(self)
  if self.announcePending or self.db.slot == 0 then return end
  self.announcePending = true
  C_Timer.After(2, function() -- debounce: rosters change several times in a row when inviting
    self.announcePending = nil
    if IsInGroup() and self:Token() then self:SendGroup(infoPayload(self.db.slot, self.myName, 1)) end
  end)
end)

function MF:AcceptToken(text)
  local tok = self:ParseToken(text)
  if not tok then return false, "that is not a valid token (typo or truncated copy?)" end
  if tok.master == self.myName and self.db.slot ~= 1 then
    return false, "this token was created by this very character; copy it from slot 1 into the other windows"
  end
  self:SetToken(text:match("^%s*(.-)%s*$"))
  self:Print("token accepted, team master is %s", tok.master)
  self:Announce()
  return true
end

function MF:SetSlot(n)
  self.db.slot = n
  if n == 0 then
    self:SetOwnSlot()
    self:Print("slot cleared, team features are off in this window")
    return
  end
  local tok = self:Token()
  self:SetOwnSlot()
  self:Fire("TEAM_CHANGED")
  if n == 1 then
    if not tok then self:SetToken(self:MakeToken(self.myName)) end
    self:SetOwnSlot()
    self:Print(
      "this window is slot 1 (team master). Copy the token (Ctrl-C), then paste it in the other windows after /mama s N")
    self:ShowTokenDialog("copy")
    self:Announce()
  else
    if tok and tok.master == self.myName then
      self:SetToken(nil) -- we were the master before; need the new master's token
      tok = nil
    end
    self:Print("this window is slot %d", n)
    self:Fire('TEAM_CHANGED')
    if tok then
      self:Announce()
    else
      self:ShowTokenDialog("paste")
    end
  end
end

MF:AddCommand("s", function(self, rest)
  local n = tonumber(rest)
  if not n or n < 0 or n > self.maxSlot or n ~= math.floor(n) then
    self:Print("use /mama s N with N from 0 to %d (0 turns it off); %q is not valid", self.maxSlot, rest)
    return
  end
  self:SetSlot(n)
end, "s N - set this window's slot (once per window: 1 = master window shows the token, others paste it)")

MF:AddCommand("token", function(self, rest)
  if rest == "new" and self.db.slot == 1 then
    self:SetToken(self:MakeToken(self.myName))
    wipe(self.db.slots)
    self:SetOwnSlot()
    self:ShowTokenDialog("copy")
  elseif rest ~= "" then
    local ok, err = self:AcceptToken(rest)
    if not ok then self:Print("%s", err) end
  elseif self.db.slot == 1 and self:Token() then
    local tok = self:Token()
    if tok.master ~= self.myName then
      -- keep team id and secret, just point the master at this character
      local body = ("%s:%s:%s:"):format(tok.team, tok.secret, self.myName)
      self:SetToken(body .. checkChar(body))
      self:Print("token refreshed: team master is now %s", self.myName)
    end
    self:ShowTokenDialog("copy")
  else
    self:ShowTokenDialog("paste")
  end
end, "token [new|<token>] - show the token (slot 1), paste one (other slots), or make a new one (slot 1)")
