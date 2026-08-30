-- RothShinyBuffs runtime owner for Retail 12.1.
-- Blizzard owns aura assignment, visibility, layout, duration, and restricted
-- state. This addon styles only source-confirmed, pre-created public slots.

local ADDON_NAME = ...
if ADDON_NAME ~= "RothShinyBuffs" then return end

local unpack = table.unpack or unpack
local BUFF_SLOT_COUNT = 32
local DEBUFF_SLOT_COUNT = 16
local TILE_WIDTH = 1 / 8

local FALLBACK_MEDIA = {
  strip = "Interface\\AddOns\\RothShinyBuffs\\media\\5.tga",
  border = "Interface\\AddOns\\RothShinyBuffs\\media\\border64.tga",
  background = "Interface\\AddOns\\RothShinyBuffs\\media\\Solid.tga",
}

local DEFAULTS = {
  configVersion = 50,
  enabled = true,
  showBorder = true,
  showBG = true,
  mode = "galaxy_strip",
  iconCrop = 0.07,
  edgeSize = 16,
  outset = 3,
  bgOutset = 2,
  bgColor = { 0.32, 0.32, 0.32, 1.00 },
  borderColor = { 0.50, 0.50, 0.50, 1.00 },
  stripBorderName = "RothShinyBuffs: Galaxy Strip",
  borderName = "RothShinyBuffs: Border64",
  bgName = "RothShinyBuffs: Solid",
}

local DB
local config = {}
local initialized = false
local pendingApply = false
local styledSlots = setmetatable({}, { __mode = "k" })

local function CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end

local function SafeBoolean(value)
  if not CanAccess(value) or type(value) ~= "boolean" then return nil end
  return value
end

local function SafeNumber(value)
  if not CanAccess(value) or type(value) ~= "number" or value ~= value then return nil end
  return value
end

local function SafeString(value)
  if not CanAccess(value) or type(value) ~= "string" then return nil end
  return value
end

local function SafeTable(value)
  if not CanAccess(value) or type(value) ~= "table" then return nil end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret == true then return nil end
  end
  return value
end

local function SafeField(object, key)
  if not CanAccess(object) then return nil end
  local objectType = type(object)
  if objectType ~= "table" and objectType ~= "userdata" then return nil end
  local ok, value = pcall(function() return object[key] end)
  if not ok or not CanAccess(value) then return nil end
  return value
end

local function CanUseObject(object)
  if object == nil or not CanAccess(object) then return false end
  local objectType = type(object)
  if objectType ~= "table" and objectType ~= "userdata" then return false end

  local accessMethod = SafeField(object, "CanBeAccessedInContext")
  if type(accessMethod) == "function" then
    local ok, accessible = pcall(accessMethod, object)
    if not ok or SafeBoolean(accessible) ~= true then return false end
  end

  local forbiddenMethod = SafeField(object, "IsForbidden")
  if type(forbiddenMethod) == "function" then
    local ok, forbidden = pcall(forbiddenMethod, object)
    if not ok or SafeBoolean(forbidden) ~= false then return false end
  end
  return true
end

local function Method(object, methodName)
  if not CanUseObject(object) then return nil end
  local method = SafeField(object, methodName)
  return type(method) == "function" and method or nil
end

local function SafeCall(object, methodName, ...)
  local method = Method(object, methodName)
  if not method then return false end
  return pcall(method, object, ...)
end

local function SafeGet(object, methodName, ...)
  local method = Method(object, methodName)
  if not method then return nil end
  local values = { pcall(method, object, ...) }
  if not values[1] then return nil end
  table.remove(values, 1)
  for index = 1, #values do
    if not CanAccess(values[index]) then return nil end
  end
  return unpack(values)
end

local function InCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, value = pcall(InCombatLockdown)
  return ok and SafeBoolean(value) == true
end

local function ReadDBField(tableValue, key)
  local tableObject = SafeTable(tableValue)
  if not tableObject then return nil end
  local ok, value = pcall(function() return tableObject[key] end)
  if not ok or not CanAccess(value) then return nil end
  return value
end

local function CopyColor(color, fallback)
  local source = SafeTable(color) or fallback
  return {
    SafeNumber(ReadDBField(source, 1)) or fallback[1],
    SafeNumber(ReadDBField(source, 2)) or fallback[2],
    SafeNumber(ReadDBField(source, 3)) or fallback[3],
    SafeNumber(ReadDBField(source, 4)) or fallback[4],
  }
end

local function Clamp(value, fallback, minimum, maximum)
  value = SafeNumber(value)
  if value == nil then return fallback end
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

local function EnsureDefaults()
  local root = SafeTable(_G.RothShinyBuffsDB) or {}
  _G.RothShinyBuffsDB = root
  DB = root

  DB.configVersion = 50
  DB.enabled = SafeBoolean(ReadDBField(DB, "enabled")) ~= false
  DB.showBorder = SafeBoolean(ReadDBField(DB, "showBorder")) ~= false
  DB.showBG = SafeBoolean(ReadDBField(DB, "showBG")) ~= false
  DB.mode = SafeString(ReadDBField(DB, "mode")) == "full_border" and "full_border" or "galaxy_strip"
  DB.iconCrop = Clamp(ReadDBField(DB, "iconCrop"), DEFAULTS.iconCrop, 0, 0.20)
  DB.edgeSize = Clamp(ReadDBField(DB, "edgeSize"), DEFAULTS.edgeSize, 4, 64)
  DB.outset = Clamp(ReadDBField(DB, "outset"), DEFAULTS.outset, 0, 24)
  DB.bgOutset = Clamp(ReadDBField(DB, "bgOutset"), DEFAULTS.bgOutset, 0, 24)
  DB.bgColor = CopyColor(ReadDBField(DB, "bgColor"), DEFAULTS.bgColor)
  DB.borderColor = CopyColor(ReadDBField(DB, "borderColor"), DEFAULTS.borderColor)
  DB.stripBorderName = SafeString(ReadDBField(DB, "stripBorderName")) or DEFAULTS.stripBorderName
  DB.borderName = SafeString(ReadDBField(DB, "borderName")) or DEFAULTS.borderName
  DB.bgName = SafeString(ReadDBField(DB, "bgName")) or DEFAULTS.bgName
  DB.useMasque = nil
  return DB
end

local function ResetDefaults()
  _G.RothShinyBuffsDB = {}
  return EnsureDefaults()
end

local function GetLSM()
  local libStub = _G.LibStub
  if type(libStub) ~= "function" then return nil end
  local ok, library = pcall(libStub, "LibSharedMedia-3.0", true)
  return ok and SafeTable(library) or nil
end

local function RegisterBuiltInMedia()
  local LSM = GetLSM()
  if not LSM or type(LSM.Register) ~= "function" then return end
  pcall(LSM.Register, LSM, "border", "RothShinyBuffs: Galaxy Strip", FALLBACK_MEDIA.strip)
  pcall(LSM.Register, LSM, "border", "RothShinyBuffs: Border64", FALLBACK_MEDIA.border)
  pcall(LSM.Register, LSM, "border", "RothShinyBuffs: Border", "Interface\\AddOns\\RothShinyBuffs\\media\\border.tga")
  pcall(LSM.Register, LSM, "background", "RothShinyBuffs: Solid", FALLBACK_MEDIA.background)
end

local function FetchMedia(kind, name, fallback)
  local LSM = GetLSM()
  if LSM and type(LSM.Fetch) == "function" and SafeString(name) then
    local ok, path = pcall(LSM.Fetch, LSM, kind, name, true)
    path = ok and SafeString(path) or nil
    if path and path ~= "" then return path end
  end
  return fallback
end

local function ResolveConfig()
  EnsureDefaults()
  config.stripTexture = FetchMedia("border", DB.stripBorderName, FALLBACK_MEDIA.strip)
  config.borderTexture = FetchMedia("border", DB.borderName, FALLBACK_MEDIA.border)
  config.backgroundTexture = FetchMedia("background", DB.bgName, FALLBACK_MEDIA.background)
  config.bgColor = CopyColor(DB.bgColor, DEFAULTS.bgColor)
  config.borderColor = CopyColor(DB.borderColor, DEFAULTS.borderColor)
  config.iconCrop = DB.iconCrop
  config.edgeSize = DB.edgeSize
  config.outset = DB.outset
  config.bgOutset = DB.bgOutset
end

local function IsPublicAuraIcon(icon)
  if not CanUseObject(icon) or not Method(icon, "SetTexCoord") then return false end
  return SafeString(SafeGet(icon, "GetObjectType")) == "Texture"
end

local function GetPublicIcon(button)
  if not CanUseObject(button) then return nil end
  local icon = SafeField(button, "Icon")
  return IsPublicAuraIcon(icon) and icon or nil
end

local function CaptureTexCoord(icon)
  local method = Method(icon, "GetTexCoord")
  if not method then return { 0, 1, 0, 1 } end
  local values = { pcall(method, icon) }
  if not values[1] then return { 0, 1, 0, 1 } end
  table.remove(values, 1)
  local ordinary = {}
  for index = 1, math.min(8, #values) do
    local number = SafeNumber(values[index])
    if number == nil then break end
    ordinary[#ordinary + 1] = number
  end
  if #ordinary >= 8 then return ordinary end
  if #ordinary >= 4 then return { ordinary[1], ordinary[2], ordinary[3], ordinary[4] } end
  return { 0, 1, 0, 1 }
end

local function CreateTexture(button, layer, subLevel)
  local method = Method(button, "CreateTexture")
  if not method then return nil end
  local ok, texture = pcall(method, button, nil, layer, nil, subLevel)
  return ok and CanUseObject(texture) and texture or nil
end

local function SetColor(texture, color)
  SafeCall(texture, "SetVertexColor", color[1], color[2], color[3], color[4])
end

local function SetShown(texture, shown)
  SafeCall(texture, "SetShown", shown == true)
end

local function SetStripTile(texture, tileIndex)
  local left = tileIndex * TILE_WIDTH
  SafeCall(texture, "SetTexture", config.stripTexture)
  SafeCall(texture, "SetTexCoord", left, left + TILE_WIDTH, 0, 1)
end

local function CreateState(button, icon)
  local state = {
    icon = icon,
    originalTexCoord = CaptureTexCoord(icon),
    background = CreateTexture(button, "BACKGROUND", -8),
    fullBorder = nil,
    strip = nil,
    cropApplied = false,
  }
  styledSlots[button] = state
  return state
end

local function EnsureBackground(button, state)
  if not state.background then state.background = CreateTexture(button, "BACKGROUND", -8) end
  return state.background
end

local function EnsureFullBorder(button, state)
  if not state.fullBorder then state.fullBorder = CreateTexture(button, "OVERLAY", 7) end
  return state.fullBorder
end

local function EnsureStrip(button, state)
  if state.strip then return state.strip end
  local strip = {}
  for index = 1, 8 do
    strip[index] = CreateTexture(button, "OVERLAY", 7)
    if not strip[index] then return nil end
  end
  state.strip = strip
  return strip
end

local function HideState(state)
  if not state then return end
  SetShown(state.background, false)
  SetShown(state.fullBorder, false)
  if state.strip then for index = 1, 8 do SetShown(state.strip[index], false) end end
  if state.cropApplied and IsPublicAuraIcon(state.icon) then
    SafeCall(state.icon, "SetTexCoord", unpack(state.originalTexCoord))
    state.cropApplied = false
  end
end

local function ApplyBackground(button, state)
  local texture = EnsureBackground(button, state)
  if not texture then return end
  SafeCall(texture, "SetTexture", config.backgroundTexture)
  SetColor(texture, config.bgColor)
  SafeCall(texture, "ClearAllPoints")
  SafeCall(texture, "SetPoint", "TOPLEFT", state.icon, "TOPLEFT", -config.bgOutset, config.bgOutset)
  SafeCall(texture, "SetPoint", "BOTTOMRIGHT", state.icon, "BOTTOMRIGHT", config.bgOutset, -config.bgOutset)
  SetShown(texture, DB.enabled and DB.showBG)
end

local function ApplyFullBorder(button, state)
  local border = EnsureFullBorder(button, state)
  if not border then return end
  SafeCall(border, "SetTexture", config.borderTexture)
  SetColor(border, config.borderColor)
  SafeCall(border, "ClearAllPoints")
  SafeCall(border, "SetPoint", "TOPLEFT", state.icon, "TOPLEFT", -config.outset, config.outset)
  SafeCall(border, "SetPoint", "BOTTOMRIGHT", state.icon, "BOTTOMRIGHT", config.outset, -config.outset)
  SetShown(border, DB.enabled and DB.showBorder and DB.mode == "full_border")
  if state.strip then for index = 1, 8 do SetShown(state.strip[index], false) end end
end

local function ApplyStrip(button, state)
  local strip = EnsureStrip(button, state)
  if not strip then return end
  local tl, top, tr, right, br, bottom, bl, left = unpack(strip)
  local edge, outset = config.edgeSize, config.outset

  for index = 1, 8 do
    SetStripTile(strip[index], index - 1)
    SetColor(strip[index], config.borderColor)
    SetShown(strip[index], DB.enabled and DB.showBorder and DB.mode == "galaxy_strip")
  end

  SafeCall(tl, "ClearAllPoints"); SafeCall(tl, "SetSize", edge, edge); SafeCall(tl, "SetPoint", "TOPLEFT", state.icon, "TOPLEFT", -outset, outset)
  SafeCall(tr, "ClearAllPoints"); SafeCall(tr, "SetSize", edge, edge); SafeCall(tr, "SetPoint", "TOPRIGHT", state.icon, "TOPRIGHT", outset, outset)
  SafeCall(br, "ClearAllPoints"); SafeCall(br, "SetSize", edge, edge); SafeCall(br, "SetPoint", "BOTTOMRIGHT", state.icon, "BOTTOMRIGHT", outset, -outset)
  SafeCall(bl, "ClearAllPoints"); SafeCall(bl, "SetSize", edge, edge); SafeCall(bl, "SetPoint", "BOTTOMLEFT", state.icon, "BOTTOMLEFT", -outset, -outset)
  SafeCall(top, "ClearAllPoints"); SafeCall(top, "SetPoint", "TOPLEFT", tl, "TOPRIGHT", 0, 0); SafeCall(top, "SetPoint", "BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
  SafeCall(right, "ClearAllPoints"); SafeCall(right, "SetPoint", "TOPLEFT", tr, "BOTTOMLEFT", 0, 0); SafeCall(right, "SetPoint", "BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
  SafeCall(bottom, "ClearAllPoints"); SafeCall(bottom, "SetPoint", "TOPLEFT", bl, "TOPRIGHT", 0, 0); SafeCall(bottom, "SetPoint", "BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
  SafeCall(left, "ClearAllPoints"); SafeCall(left, "SetPoint", "TOPLEFT", tl, "BOTTOMLEFT", 0, 0); SafeCall(left, "SetPoint", "BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)
  SetShown(state.fullBorder, false)
end

local function StyleSlot(button)
  local icon = GetPublicIcon(button)
  if not icon then return false end
  local state = styledSlots[button]
  if not state or state.icon ~= icon then state = CreateState(button, icon) end

  if not DB.enabled then HideState(state); return true end
  SafeCall(icon, "SetTexCoord", config.iconCrop, 1 - config.iconCrop, config.iconCrop, 1 - config.iconCrop)
  state.cropApplied = true
  ApplyBackground(button, state)
  if DB.mode == "full_border" then ApplyFullBorder(button, state) else ApplyStrip(button, state) end
  return true
end

local function StyleArray(frame, count)
  if not CanUseObject(frame) then return 0 end
  local auraFrames = SafeTable(SafeField(frame, "auraFrames"))
  if not auraFrames then return 0 end
  local styled = 0
  for index = 1, count do
    local ok, button = pcall(function() return auraFrames[index] end)
    if ok and CanAccess(button) and StyleSlot(button) then styled = styled + 1 end
  end
  return styled
end

local function StyleSourceConfirmedSlots()
  local count = StyleArray(_G.BuffFrame, BUFF_SLOT_COUNT) + StyleArray(_G.DebuffFrame, DEBUFF_SLOT_COUNT)
  local deadlyFrame = CanAccess(_G.DeadlyDebuffFrame) and _G.DeadlyDebuffFrame or nil
  local deadly = SafeField(deadlyFrame, "Debuff")
  if StyleSlot(deadly) then count = count + 1 end
  return count
end

local function ApplySettings()
  EnsureDefaults()
  if InCombat() then pendingApply = true; return false end
  ResolveConfig()
  pendingApply = false
  StyleSourceConfirmedSlots()
  for button, state in pairs(styledSlots) do
    if CanUseObject(button) and state then StyleSlot(button) end
  end
  return true
end

local function GetStyledCount()
  local count = 0
  for button, state in pairs(styledSlots) do
    if CanUseObject(button) and state then count = count + 1 end
  end
  return count
end

local function Print(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(message) elseif print then print(message) end
end

local function RegisterSlash()
  SLASH_ROTHSHINYBUFFS1 = "/rsb"
  SlashCmdList.ROTHSHINYBUFFS = function(message)
    message = SafeString(message)
    message = message and message:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if message == "toggle" then
      DB.enabled = not DB.enabled
      ApplySettings()
      Print("|cff00ff00RothShinyBuffs|r " .. (DB.enabled and "enabled" or "disabled"))
    elseif message == "reset" then
      ResetDefaults()
      ApplySettings()
      Print("|cff00ff00RothShinyBuffs|r settings reset.")
    elseif message == "config" and _G.RothShinyBuffs_SettingsCategoryID and Settings then
      Settings.OpenToCategory(_G.RothShinyBuffs_SettingsCategoryID)
    else
      Print("|cff00ff00RothShinyBuffs|r: /rsb toggle | reset | config")
      Print(string.format("Static public slots styled: %d; pending: %s", GetStyledCount(), pendingApply and "yes" or "no"))
    end
  end
end

local EventFrame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
  EventFrame:RegisterEvent(event)
end
EventFrame:SetScript("OnEvent", function(_, event, argument)
  if event == "ADDON_LOADED" then
    local name = SafeString(argument)
    if name == ADDON_NAME then
      EnsureDefaults()
      RegisterBuiltInMedia()
    elseif name == "Blizzard_BuffFrame" and initialized then
      ApplySettings()
    end
  elseif event == "PLAYER_LOGIN" then
    EnsureDefaults()
    RegisterBuiltInMedia()
    RegisterSlash()
    initialized = true
    ApplySettings()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if initialized then ApplySettings() end
  elseif event == "PLAYER_REGEN_ENABLED" and pendingApply then
    ApplySettings()
  end
end)

_G.RothShinyBuffs_EnsureDefaults = EnsureDefaults
_G.RothShinyBuffs_ResetDefaults = ResetDefaults
_G.RothShinyBuffs_ApplySettings = ApplySettings
_G.RothShinyBuffs_Runtime = {
  Apply = ApplySettings,
  GetStyledCount = GetStyledCount,
  IsPending = function() return pendingApply end,
  GetBuffSlotLimit = function() return BUFF_SLOT_COUNT end,
  GetDebuffSlotLimit = function() return DEBUFF_SLOT_COUNT end,
}
