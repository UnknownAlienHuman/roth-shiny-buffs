local combat = false
local createdTextures = 0
local geometryMutations = 0
local eventFrame
local events = {}
local calls = { getTexture = 0, isShown = 0, enumerate = 0 }

local SECRET = setmetatable({}, {
  __index = function() error("secret indexed") end,
  __tostring = function() error("secret stringified") end,
  __eq = function() error("secret compared") end,
})

local function assertEq(actual, expected, message)
  if actual ~= expected then error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function newTexture(parent)
  local texture = { parent = parent, shown = true, texCoord = { 0, 1, 0, 1 } }
  function texture:CanBeAccessedInContext() return true end
  function texture:IsForbidden() return false end
  function texture:GetObjectType() return "Texture" end
  function texture:GetParent() return self.parent end
  function texture:SetTexture(value) self.texture = value end
  function texture:GetTexture() calls.getTexture = calls.getTexture + 1; return self.texture end
  function texture:SetTexCoord(...) self.texCoord = { ... } end
  function texture:GetTexCoord() return unpack(self.texCoord) end
  function texture:SetVertexColor(...) self.color = { ... } end
  function texture:ClearAllPoints() geometryMutations = geometryMutations + 1; self.points = {} end
  function texture:SetPoint(...) geometryMutations = geometryMutations + 1; self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
  function texture:SetSize(width, height) geometryMutations = geometryMutations + 1; self.width, self.height = width, height end
  function texture:SetShown(value) self.shown = value end
  function texture:IsShown() calls.isShown = calls.isShown + 1; return self.shown end
  return texture
end

local function newButton(hasIcon)
  local button = {}
  function button:CanBeAccessedInContext() return true end
  function button:IsForbidden() return false end
  function button:CreateTexture(_, layer, _, subLevel)
    createdTextures = createdTextures + 1
    local texture = newTexture(self)
    texture.layer, texture.subLevel = layer, subLevel
    return texture
  end
  if hasIcon ~= false then button.Icon = newTexture(button) end
  return button
end

local function makeSlots(count)
  local slots = {}
  for index = 1, count do slots[index] = newButton(true) end
  return slots
end

function canaccessvalue(value) return not rawequal(value, SECRET) end
function issecretvalue(value) return rawequal(value, SECRET) end
function issecrettable(value) return rawequal(value, SECRET) end
function InCombatLockdown() return combat end

SlashCmdList = {}
Settings = nil
EventUtil = nil
DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local media = {}
LibStub = function(name)
  if name ~= "LibSharedMedia-3.0" then return nil end
  return {
    Register = function(_, kind, key, path) media[kind .. ":" .. key] = path end,
    Fetch = function(_, kind, key) return media[kind .. ":" .. key] end,
  }
end

BuffFrame = { auraFrames = makeSlots(32) }
DebuffFrame = { auraFrames = makeSlots(22) }
for index = 17, 22 do
  DebuffFrame.auraFrames[index] = newButton(false)
  DebuffFrame.auraFrames[index].isAuraAnchor = true
end
DeadlyDebuffFrame = { Debuff = newButton(true) }
BuffFrame.AuraContainer = { activePool = { EnumerateActive = function() calls.enumerate = calls.enumerate + 1; return function() end end } }

function CreateFrame()
  local frame = { scripts = {}, registered = {} }
  function frame:RegisterEvent(event) self.registered[event] = true; events[event] = true end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  if not eventFrame then eventFrame = frame end
  return frame
end

local chunk = assert(loadfile("core.lua"))
chunk("RothShinyBuffs")
local onEvent = assert(eventFrame.scripts.OnEvent)
local secretEventOK, secretEventError = pcall(onEvent, eventFrame, "ADDON_LOADED", SECRET)
assertEq(secretEventOK, true, "secret addon argument escaped: " .. tostring(secretEventError))
onEvent(eventFrame, "ADDON_LOADED", "RothShinyBuffs")

combat = true
local beforeTextures, beforeGeometry = createdTextures, geometryMutations
onEvent(eventFrame, "PLAYER_LOGIN")
assertEq(createdTextures, beforeTextures, "textures created in combat")
assertEq(geometryMutations, beforeGeometry, "geometry mutated in combat")
assertEq(_G.RothShinyBuffs_Runtime.IsPending(), true, "combat apply was not deferred")

combat = false
onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assertEq(_G.RothShinyBuffs_Runtime.IsPending(), false, "pending apply did not clear")
assertEq(_G.RothShinyBuffs_Runtime.GetStyledCount(), 49, "source-confirmed slot count")
assert(createdTextures > 0, "no addon textures were created out of combat")
assertEq(events.UNIT_AURA, nil, "UNIT_AURA must not be registered")
assertEq(calls.enumerate, 0, "active aura pool was enumerated")
assertEq(calls.getTexture, 0, "live icon texture was read")
assertEq(calls.isShown, 0, "button visibility was queried")
assertEq(DebuffFrame.auraFrames[17].Icon, nil, "private anchor fixture changed")

local firstIcon = BuffFrame.auraFrames[1].Icon
assertEq(firstIcon.texCoord[1], 0.07, "default crop was not applied")
RothShinyBuffsDB.iconCrop = 0.12
combat = true
_G.RothShinyBuffs_ApplySettings()
assertEq(firstIcon.texCoord[1], 0.07, "crop changed in combat")
combat = false
onEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assertEq(firstIcon.texCoord[1], 0.12, "deferred crop did not apply")

local savedIcon = BuffFrame.auraFrames[2].Icon
BuffFrame.auraFrames[2].Icon = SECRET
local iconOK, iconError = pcall(_G.RothShinyBuffs_ApplySettings)
assertEq(iconOK, true, "secret icon escaped boundary: " .. tostring(iconError))
BuffFrame.auraFrames[2].Icon = savedIcon
local savedDebuffSlots = DebuffFrame.auraFrames
DebuffFrame.auraFrames = SECRET
local tableOK, tableError = pcall(_G.RothShinyBuffs_ApplySettings)
assertEq(tableOK, true, "secret auraFrames escaped boundary: " .. tostring(tableError))
DebuffFrame.auraFrames = savedDebuffSlots

RothShinyBuffsDB.enabled = false
_G.RothShinyBuffs_ApplySettings()
assertEq(firstIcon.texCoord[1], 0, "original icon crop was not restored")

local function read(path)
  local file = assert(io.open(path, "rb"))
  local content = file:read("*a")
  file:close()
  return content
end
local toc = read("RothShinyBuffs.toc")
assert(toc:find("libs\\LibStub", 1, true), "TOC does not match lowercase repository path")
assert(not toc:find("Libs\\", 1, true), "TOC retains wrong directory case")
local runtime = read("core.lua"):gsub("DB%.useMasque%s*=%s*nil", "")
for _, forbidden in ipairs({ "UNIT_AURA", "EnumerateActive", "GetChildren", "GetNumChildren", "hasValidInfo", "isAuraAnchor", "GetTexture()", "IsShown()", "C_UnitAuras", "AuraUtil.ForEachAura", "Masque", "C_Timer" }) do
  assert(not runtime:find(forbidden, 1, true), "forbidden runtime token: " .. forbidden)
end

print("PASS: fixed public slots only; access-first objects/tables; exact TOC paths; combat deferral and crop restoration")
