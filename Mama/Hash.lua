--[[
   Mama by MooreaTV moorea@ymail.com (c) 2019-2026 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Mama: MooreaTv's/minimal yet Awesome Multiboxing Assistant (name inspired by Jamba)

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/MAMA-multiboxing

   Releases detail/changes are on https://github.com/mooreatv/MAMA-multiboxing/releases
   ]] --
-- Hash: HMAC-SHA256 in plain Lua with the client's `bit` library, used to sign the team's addon messages.
-- Values are kept as unsigned 32 bit numbers (results of bit.* are normalized with % 2^32 whatever their sign).
-- The inner/outer key blocks are hashed once per secret, so signing a message costs ~2-3 compressions.
local _, MF = ...

local band, bor, bxor, bnot, rshift, lshift = bit.band, bit.bor, bit.bxor, bit.bnot, bit.rshift, bit.lshift
local floor, char = math.floor, string.char
local MOD = 4294967296

local K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98,
  0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8,
  0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819,
  0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}
local IV = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}

local function rrot(x, n) return bor(rshift(x, n), lshift(x, 32 - n)) % MOD end

local w = {} -- message schedule, reused
-- Processes the 64 byte block of `s` starting at `pos` into the state H (in place).
local function compress(H, s, pos)
  for i = 1, 16 do
    local a, b, c, d = s:byte(pos + i * 4 - 4, pos + i * 4 - 1)
    w[i] = ((a * 256 + b) * 256 + c) * 256 + d
  end
  for i = 17, 64 do
    local x, y = w[i - 15], w[i - 2]
    local s0 = bxor(bxor(rrot(x, 7), rrot(x, 18)), rshift(x, 3))
    local s1 = bxor(bxor(rrot(y, 17), rrot(y, 19)), rshift(y, 10))
    w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
  end
  local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
  for i = 1, 64 do
    local S1 = bxor(bxor(rrot(e, 6), rrot(e, 11)), rrot(e, 25))
    local ch = bxor(band(e, f), band(bnot(e), g))
    local t1 = h + S1 + ch + K[i] + w[i]
    local S0 = bxor(bxor(rrot(a, 2), rrot(a, 13)), rrot(a, 22))
    local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
    h, g, f, e, d, c, b, a = g, f, e, (d + t1) % MOD, c, b, a, (t1 + S0 + maj) % MOD
  end
  H[1], H[2], H[3], H[4] = (H[1] + a) % MOD, (H[2] + b) % MOD, (H[3] + c) % MOD, (H[4] + d) % MOD
  H[5], H[6], H[7], H[8] = (H[5] + e) % MOD, (H[6] + f) % MOD, (H[7] + g) % MOD, (H[8] + h) % MOD
end

local function be32(n) return char(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256) end

-- Hash of (already processed `done` bytes, giving `state`) .. msg, as 8 words.
local function finish(state, done, msg)
  local H = {unpack(state)}
  local len = done + #msg
  msg = msg .. "\128" .. ("\0"):rep((55 - #msg) % 64) .. "\0\0\0\0" .. be32(len * 8)
  for pos = 1, #msg, 64 do compress(H, msg, pos) end
  return H
end

local function toBytes(H)
  local t = {}
  for i = 1, #H do t[i] = be32(H[i]) end
  return table.concat(t)
end

local function toHex(H, words)
  local t = {}
  for i = 1, words do t[i] = ("%08x"):format(H[i]) end
  return table.concat(t)
end

local function keyState(key, pad)
  local t = {}
  for i = 1, 64 do t[i] = char(bxor(key:byte(i) or 0, pad)) end
  local H = {unpack(IV)}
  compress(H, table.concat(t), 1)
  return H
end

local cached = {} -- secret -> {inner, outer} states
local function hmac(key, msg)
  local c = cached[key]
  if not c then
    local k = #key > 64 and toBytes(finish(IV, 0, key)) or key
    c = {keyState(k, 0x36), keyState(k, 0x5c)}
    cached[key] = c
  end
  return finish(c[2], 64, toBytes(finish(c[1], 64, msg)))
end

-- First `words` 32 bit words (default all 8) of HMAC-SHA256(key, msg), in hex.
function MF:Hmac(key, msg, words) return toHex(hmac(key, msg), words or 8) end

function MF:Sha256(msg) return toHex(finish(IV, 0, msg), 8) end

-- Known answers (FIPS 180-2 and RFC 4231 test 2): if the client's bit library behaves differently, say so loudly.
function MF:HashSelfTest()
  local ok = self:Sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" and
               self:Sha256(("a"):rep(1000)) == "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3" and
               self:Hmac("Jefe", "what do ya want for nothing?") ==
               "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
  if not ok then
    self:Print("|cFFFF0000error:|r SHA-256 self test failed, team messages won't verify (/mama bug)")
    return false
  end
  -- only run timing loop if debug is on:
  if not (self.db and self.db.debug) then return end
  local start = debugprofilestop()
  for i = 1, 100 do self:Hmac("abcdefghijkl", "abcdef:I;12;Firstname Lastname;1:Ab3d:" .. (1759780000 + i) .. ":", 2) end
  self:Debug("message signing: HMAC-SHA256 self test ok, %.3f ms per message", (debugprofilestop() - start) / 100)
  return true
end
