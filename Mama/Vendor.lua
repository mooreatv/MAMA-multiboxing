--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Vendor: opening a merchant sells the items on the sell list, and every grey item when that box is ticked (hold
-- Shift, Ctrl or Alt while opening it to sell nothing). The list is edited in the /mama vendor window (also the
-- "Mama: sell list" button above the merchant window): drop items on it, Ctrl+Right click them in the bags while it
-- is shown, or type a name / ID in its box.
-- Each change goes to the team: "V;+;id" added, "V;-;id" removed, "V;g;0|1" greys. "Send list to team" sends the
-- whole list as "V;=;i/n;greys;id,id,..." chunks, which replace the receivers' list once every chunk arrived.
local _, MF = ...

local CHUNK = 20 -- item IDs per "V;=" message (addon messages are limited to 255 bytes, signature included)
local SELL_EVERY = 0.15 -- seconds between two sales: the merchant refuses items sold too fast
local POOR = 0 -- grey item quality
local ROW_H = 22

local frame -- the window, built on first use
local rows = {}
local merchantOpen = false

local function refreshWindow() if frame and frame:IsShown() then frame:Refresh() end end

-- db.vendor = {items = {[itemID] = true}, greys = sell every grey item}
function MF:VendorList()
  local v = self.db.vendor or {items = {}, greys = false}
  self.db.vendor = v
  return v
end

local function linkText(id)
  local name, link = C_Item.GetItemInfo(id)
  if not name then C_Item.RequestLoadItemDataByID(id) end
  return link or ("item " .. id)
end

-- Listed item IDs by name (not cached yet: by ID, after the named ones).
local function sortedIDs(self)
  local ids = {}
  for id in pairs(self:VendorList().items) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    local na, nb = C_Item.GetItemInfo(a) or "~", C_Item.GetItemInfo(b) or "~"
    if na ~= nb then return na < nb end
    return a < b
  end)
  return ids
end

local function parseIDs(text)
  local ids = {}
  for id in text:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
  return ids
end

-- Item ID, item link, or the name of an item the client knows (e.g. one in the bags).
local function toItemID(text)
  text = (text or ""):match("^%s*(.-)%s*$")
  if text == "" then return nil end
  local id = text:match("item:(%d+)") or text:match("^%d+$")
  return (C_Item.GetItemInfoInstant(id and tonumber(id) or text))
end

-- Adds (on) or removes item IDs. by: the team member who did it; nil when it's us, then the team is told.
function MF:ChangeVendorList(ids, on, by)
  local items, changed, links = self:VendorList().items, {}, {}
  for _, id in ipairs(ids) do
    if (items[id] or false) ~= on then
      items[id] = on or nil
      changed[#changed + 1] = id
      links[#links + 1] = linkText(id)
    end
  end
  if #changed == 0 then return end
  self:Print("%s%s %s the sell list", by and (by .. ": ") or "", table.concat(links, ", "),
             on and "added to" or "removed from")
  refreshWindow()
  if not by then self:SendTeam(("V;%s;%s"):format(on and "+" or "-", table.concat(changed, ",")), true) end
end

function MF:AddVendorItem(id)
  local name, link, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(id)
  if name and price == 0 then -- not cached yet: added anyway
    self:Print("%s can't be sold to a vendor", link)
    return
  end
  self:ChangeVendorList({id}, true)
end

function MF:SetVendorGreys(on, by)
  local v = self:VendorList()
  if v.greys == on then return end
  v.greys = on
  self:Print("%sgrey items are %s", by and (by .. ": ") or "", on and "sold at vendors" or "no longer sold at vendors")
  refreshWindow()
  if not by then self:SendTeam("V;g;" .. (on and "1" or "0"), true) end
end

function MF:SendVendorList()
  local v, ids = self:VendorList(), sortedIDs(self)
  local n = math.max(1, math.ceil(#ids / CHUNK))
  for i = 1, n do
    local part = {}
    for j = (i - 1) * CHUNK + 1, math.min(i * CHUNK, #ids) do part[#part + 1] = ids[j] end
    self:SendTeam(("V;=;%d/%d;%d;%s"):format(i, n, v.greys and 1 or 0, table.concat(part, ",")), true)
  end
  self:Print("sent the sell list (%d items%s) to the team members online", #ids, v.greys and ", greys" or "")
end

local incoming = {} -- sender -> {n = chunks, got = chunks received, parts = {[i] = ids}, at = GetTime()}

local function receiveChunk(self, sender, i, n, greys, ids)
  local s = incoming[sender]
  if not s or s.n ~= n or GetTime() - s.at > 60 then -- a new list (or the rest of an older one never came)
    s = {n = n, got = 0, parts = {}}
    incoming[sender] = s
  end
  s.at = GetTime()
  if not s.parts[i] then s.got = s.got + 1 end
  s.parts[i] = ids
  if s.got < n then return end
  incoming[sender] = nil
  local v = self:VendorList()
  wipe(v.items)
  local count = 0
  for _, part in pairs(s.parts) do
    for _, id in ipairs(part) do
      v.items[id] = true
      count = count + 1
    end
  end
  v.greys = greys
  self:Print("%s sent their sell list: %d items, greys %s", sender, count, greys and "sold" or "kept")
  refreshWindow()
end

MF.messageHandlers.V = function(self, sender, rest)
  local kind, args = rest:match("^(.);(.*)$")
  if kind == "+" or kind == "-" then
    self:ChangeVendorList(parseIDs(args), kind == "+", sender)
  elseif kind == "g" then
    self:SetVendorGreys(args == "1", sender)
  elseif kind == "=" then
    local i, n, greys, ids = args:match("^(%d+)/(%d+);([01]);([%d,]*)$")
    if not i then return end
    i, n = tonumber(i), tonumber(n)
    if i >= 1 and i <= n then receiveChunk(self, sender, i, n, greys == "1", parseIDs(ids)) end
  end
end

-- Selling

local sale -- sale in progress: {ticker = C_Timer ticker, sold = items, value = copper}

local function endSale(self)
  if not sale then return end
  sale.ticker:Cancel()
  if sale.sold > 0 then self:Print("sold %d items for %s", sale.sold, self:MoneyText(sale.value)) end
  sale = nil
end

-- Bag stacks to sell: {bag, slot, id} of the listed and grey items the merchant pays for.
local function toSell(self)
  local v, list = self:VendorList(), {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and not info.isLocked and not info.hasNoValue and
        (v.items[info.itemID] or (v.greys and info.quality == POOR)) then
        list[#list + 1] = {bag = bag, slot = slot, id = info.itemID}
      end
    end
  end
  return list
end

-- done: called once everything is sold (or there was nothing to sell), unless the merchant was closed first.
function MF:SellItems(manual, done)
  endSale(self)
  if not merchantOpen then
    if manual then self:Print("talk to a merchant first") end
    return
  end
  local list = toSell(self)
  if #list == 0 then
    if manual then self:Print("nothing to sell") end
    if done then done() end
    return
  end
  local i = 0
  sale = {sold = 0, value = 0}
  sale.ticker = C_Timer.NewTicker(SELL_EVERY, function()
    i = i + 1
    local it = list[i]
    -- done, or the merchant is gone: using an item then would equip or eat it
    if not it or not merchantOpen then
      endSale(self)
      if not it and done then C_Timer.After(0.5, done) end -- the money of the last sales arrives first
      return
    end
    local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
    if info and info.itemID == it.id and not info.isLocked then -- not moved or sold by hand meanwhile
      local price = select(11, C_Item.GetItemInfo(it.id)) or 0
      C_Container.UseContainerItem(it.bag, it.slot)
      sale.sold = sale.sold + info.stackCount
      sale.value = sale.value + price * info.stackCount
    end
  end)
end

-- Option autoRepair (off by default: early on, repairing gear that gets replaced soon wastes the money training needs).
function MF:Repair()
  if not (self.db.autoRepair and merchantOpen and CanMerchantRepair()) then return end
  local cost, needed = GetRepairAllCost()
  if not needed or cost == 0 then return end
  if cost > GetMoney() then
    self:Print("not enough money to repair everything (%s)", self:MoneyText(cost))
    return
  end
  RepairAllItems()
  self:Print("repaired for %s", self:MoneyText(cost))
end

MF:On("MERCHANT_SHOW", function(self)
  merchantOpen = true
  refreshWindow()
  if self:Disabled() or IsModifierKeyDown() then return end
  -- let the merchant window settle; repair after selling, with that money too
  C_Timer.After(0.3, function() self:SellItems(false, function() self:Repair() end) end)
end)

MF:On("MERCHANT_CLOSED", function(self)
  merchantOpen = false
  endSale(self)
  refreshWindow()
end)

-- Window

-- An item held on the cursor (picked up from the bags) goes on the list, and back to its bag slot.
local function dropCursor()
  local kind, id = GetCursorInfo()
  if kind ~= "item" then return false end
  ClearCursor()
  MF:AddVendorItem(id)
  return true
end

local function button(parent, text, width, tip, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text)
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, frame.child)
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ROW_H - 4, ROW_H - 4)
  r.icon:SetPoint("LEFT", 2, 0)
  r.remove = CreateFrame("Button", nil, r, "UIPanelCloseButton")
  r.remove:SetSize(ROW_H, ROW_H)
  r.remove:SetPoint("RIGHT")
  r.remove:SetScript("OnClick", function() MF:ChangeVendorList({r.id}, false) end)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetPoint("RIGHT", r.remove, "LEFT", -4, 0)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.1)
  r:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.id)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:SetScript("OnReceiveDrag", dropCursor)
  r:SetScript("OnClick", dropCursor)
  rows[i] = r
  return r
end

local function refreshRows()
  local ids = sortedIDs(MF)
  for i, id in ipairs(ids) do
    local r = getRow(i)
    r.id = id
    local name, _, quality = C_Item.GetItemInfo(id)
    if not name then C_Item.RequestLoadItemDataByID(id) end
    r.icon:SetTexture(C_Item.GetItemIconByID(id))
    r.name:SetText(name or ("item " .. id))
    if quality then
      local cr, cg, cb = C_Item.GetItemQualityColor(quality) -- 4th value is the hex string, not an alpha
      r.name:SetTextColor(cr, cg, cb)
    else
      r.name:SetTextColor(1, 1, 1)
    end
    r:Show()
  end
  for i = #ids + 1, #rows do rows[i]:Hide() end
  frame.child:SetHeight(math.max(1, #ids * ROW_H))
  frame.empty:SetShown(#ids == 0)
  frame.greys:SetChecked(MF:VendorList().greys)
  frame.sell:SetEnabled(merchantOpen)
end

local function build()
  local f = CreateFrame("Frame", "MamaForeverVendor", UIParent, "BackdropTemplate")
  frame = f
  f:Hide()
  f:SetSize(340, 440)
  f:SetPoint("CENTER", 200, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {left = 11, right = 11, top = 11, bottom = 11}
  })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() if not GetCursorInfo() then f:StartMoving() end end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  f:SetScript("OnReceiveDrag", dropCursor)
  f:SetScript("OnMouseUp", dropCursor)
  tinsert(UISpecialFrames, "MamaForeverVendor") -- Escape closes it

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", 0, -16)
  title:SetText("Mama: sold at every vendor")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local greys = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  greys:SetPoint("TOPLEFT", 16, -34)
  greys.Text:SetText("Also sell every grey item")
  greys:SetScript("OnClick", function(b) MF:SetVendorGreys(b:GetChecked() and true or false) end)
  f.greys = greys

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 20, -66)
  hint:SetPoint("RIGHT", -20, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Drop items from your bags on this window, Ctrl+Right click them in your bags, or type an item's " ..
                 "name or ID in this box:")

  local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  edit:SetSize(200, 20)
  edit:SetPoint("TOPLEFT", 26, -94)
  edit:SetAutoFocus(false)
  local function add()
    local text = edit:GetText()
    local id = toItemID(text)
    if id then
      MF:AddVendorItem(id)
      edit:SetText("")
      edit:ClearFocus()
    elseif text ~= "" then
      MF:Print("unknown item %q: type its ID, or drop the item on this window", text)
    end
  end
  edit:SetScript("OnEnterPressed", add)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local addButton = button(f, "Add", 70, "Add the item in the box (name or ID).", add)
  addButton:SetPoint("LEFT", edit, "RIGHT", 8, 0)

  local inset = CreateFrame("Frame", nil, f, "BackdropTemplate")
  inset:SetPoint("TOPLEFT", 16, -122)
  inset:SetPoint("BOTTOMRIGHT", -16, 46)
  inset:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
  inset:SetBackdropColor(0, 0, 0, 0.4)
  inset:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  f.empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  f.empty:SetPoint("CENTER")
  f.empty:SetText("Drop items here")

  local scroll = CreateFrame("ScrollFrame", "MamaForeverVendorScroll", inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(270, 1)
  scroll:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
  scroll:SetScrollChild(child)
  f.child = child

  f.sell = button(f, "Sell now", 100, "Sell the listed (and grey) items to the merchant you are talking to.",
                  function() MF:SellItems(true) end)
  f.sell:SetPoint("BOTTOMLEFT", 16, 16)
  local send = button(f, "Send list to team", 150,
                      "Replace the sell list of the team members online with this one (adding or removing an " ..
                        "item already tells them).", function() MF:SendVendorList() end)
  send:SetPoint("BOTTOMRIGHT", -16, 16)

  f.Refresh = refreshRows
  f:SetScript("OnShow", refreshRows)
end

function MF:ToggleVendorWindow()
  if not frame then build() end
  frame:SetShown(not frame:IsShown())
end

-- Names and icons of items not cached yet arrive later.
local refreshPending
MF:On("GET_ITEM_INFO_RECEIVED", function()
  if refreshPending or not (frame and frame:IsShown()) then return end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = nil
    refreshWindow()
  end)
end)

MF:Listen("LOGIN", function(self)
  -- Ctrl+Right click on a bag item while the window is shown adds it. Modified bag clicks never use (sell) the item,
  -- they go through HandleModifiedItemClick (Ctrl alone also previews gear in the dressing room).
  hooksecurefunc("HandleModifiedItemClick", function(link)
    if not (frame and frame:IsShown() and IsControlKeyDown() and GetMouseButtonClicked() == "RightButton") then
      return
    end
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then self:AddVendorItem(id) end
  end)
  if not MerchantFrame then return end
  local b = button(MerchantFrame, "Mama: sell list", 120,
                   "Items sold every time you open a merchant (and greys, if ticked), synced with the team.",
                   function() self:ToggleVendorWindow() end)
  b:SetPoint("BOTTOMRIGHT", MerchantFrame, "TOPRIGHT", 0, 2)
end)

MF:AddCommand("vendor", function(self, rest)
  local cmd, arg = rest:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "" then
    self:ToggleVendorWindow()
  elseif cmd == "add" or cmd == "remove" then
    local id = toItemID(arg)
    if not id then
      self:Print("unknown item %q: use its ID or shift-click it", arg)
    elseif cmd == "add" then
      self:AddVendorItem(id)
    else
      self:ChangeVendorList({id}, false)
    end
  elseif cmd == "greys" or cmd == "grays" then
    self:SetVendorGreys(self:ParseOnOff(arg, self:VendorList().greys))
  elseif cmd == "list" then
    local links = {}
    for i, id in ipairs(sortedIDs(self)) do links[i] = linkText(id) end
    self:Print("sell list: %s; greys %s", #links > 0 and table.concat(links, ", ") or "(empty)",
               self:VendorList().greys and "sold" or "kept")
  elseif cmd == "sync" then
    self:SendVendorList()
  elseif cmd == "sell" then
    self:SellItems(true)
  else
    self:Print("usage: /mama vendor [add|remove <item>|greys [on|off]|list|sync|sell]")
  end
end, "vendor [add|remove <item>|greys [on|off]|list|sync|sell] - items sold when opening a merchant, synced " ..
                "with the team (no argument: the window)")
