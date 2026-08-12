-- RothShinyBuffs (Midnight 12.0) - Galaxy-style aura framing with SharedMedia + optional Masque
-- Goals:
--   * Keep aura layout under Blizzard Edit Mode (we don't move or resize aura containers).
--   * No BackdropTemplate / SetBackdrop (avoids secret width/height arithmetic).
--   * No OnUpdate loops.
--   * Minimal work on UNIT_AURA (throttled, only styles active aura buttons).
--
-- Author: Galaxy (Roth UI) - extracted & Midnight-sanitized

local ADDON_NAME = ...
if ADDON_NAME ~= "RothShinyBuffs" then return end

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------
RothShinyBuffsDB = RothShinyBuffsDB or {}
local DB = RothShinyBuffsDB

------------------------------------------------------------
-- LibSharedMedia (embedded) + Masque (optional)
------------------------------------------------------------
local LibStub = LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil

local MSQ, MSQ_Group

local function InitMasque()
  if MSQ_Group then return end
  if not LibStub then return end
  MSQ = LibStub("Masque", true)
  if not MSQ then return end
  MSQ_Group = MSQ:Group("RothShinyBuffs", "Auras")
end

------------------------------------------------------------
-- Defaults / Config cache
------------------------------------------------------------
local function CopyColor(c)
  return { c[1], c[2], c[3], c[4] }
end

local DEFAULTS = {
  configVersion = 40,
  enabled = true,

  -- Visual system:
  --   useMasque = true => Masque owns visuals (we do not draw our overlays).
  --   useMasque = false => we draw Galaxy-style overlays behind the icon.
  useMasque = false,

  showBorder = true,
  showBG = true,

  -- Modes:
  --   "galaxy_strip": 8-tile strip (5.tga) for corners+edges
  --   "full_border": single border texture stretched around the icon
  mode = "galaxy_strip",

  -- Icon crop when NOT using Masque
  iconCrop = 0.07,

  -- Geometry for our overlays
  edgeSize = 16,     -- strip tile size in px
  outset = 3,        -- how far border extends beyond icon
  bgOutset = 2,      -- background extends beyond icon

  bgColor = { 0.32, 0.32, 0.32, 1.00 },
  borderColor = { 0.50, 0.50, 0.50, 1.00 },

  -- SharedMedia names (no raw paths in settings)
  stripBorderName = "RothShinyBuffs: Galaxy Strip",
  borderName      = "RothShinyBuffs: Border64",
  bgName          = "RothShinyBuffs: Solid",
}

local cfg = {
  stripTex = nil,
  borderTex = nil,
  bgTex = nil,
  bgColor = CopyColor(DEFAULTS.bgColor),
  borderColor = CopyColor(DEFAULTS.borderColor),
  iconCrop = DEFAULTS.iconCrop,
  edgeSize = DEFAULTS.edgeSize,
  outset = DEFAULTS.outset,
  bgOutset = DEFAULTS.bgOutset,
}

local function EnsureDefaults()
  for k, v in pairs(DEFAULTS) do
    if DB[k] == nil then
      -- deep copy colors
      if type(v) == "table" then
        DB[k] = CopyColor(v)
      else
        DB[k] = v
      end
    end
  end
end

function RothShinyBuffs_EnsureDefaults()
  EnsureDefaults()
end

local function RegisterBuiltInMedia()
  if not LSM or not LSM.Register then return end
  local base = "Interface\\AddOns\\RothShinyBuffs\\media\\"
  LSM:Register("border",     "RothShinyBuffs: Galaxy Strip", base .. "5.tga")
  LSM:Register("border",     "RothShinyBuffs: Border64",     base .. "border64.tga")
  LSM:Register("border",     "RothShinyBuffs: Border",       base .. "border.tga")
  LSM:Register("background", "RothShinyBuffs: Solid",        base .. "Solid.tga")
end

local function ResolveMedia()
  EnsureDefaults()
  if not LSM then
    -- Absolute fallback (should not happen, LSM is embedded)
    cfg.stripTex  = "Interface\\AddOns\\RothShinyBuffs\\media\\5.tga"
    cfg.borderTex = "Interface\\AddOns\\RothShinyBuffs\\media\\border64.tga"
    cfg.bgTex     = "Interface\\AddOns\\RothShinyBuffs\\media\\Solid.tga"
  else
    cfg.stripTex  = LSM:Fetch("border",     DB.stripBorderName, true)
    cfg.borderTex = LSM:Fetch("border",     DB.borderName,      true)
    cfg.bgTex     = LSM:Fetch("background", DB.bgName,          true)
  end

  cfg.bgColor = DB.bgColor
  cfg.borderColor = DB.borderColor

  cfg.iconCrop = tonumber(DB.iconCrop) or DEFAULTS.iconCrop
  cfg.edgeSize = tonumber(DB.edgeSize) or DEFAULTS.edgeSize
  cfg.outset   = tonumber(DB.outset)   or DEFAULTS.outset
  cfg.bgOutset = tonumber(DB.bgOutset) or DEFAULTS.bgOutset
end

------------------------------------------------------------
-- Aura button helpers
------------------------------------------------------------
local function GetIcon(btn)
  if not btn then return nil end
  return btn.Icon or btn.icon or btn.IconTexture
end

local function HideDefaultBorders(btn)
  if not btn then return end
  local hide = {
    btn.Border, btn.border,
    btn.IconBorder, btn.DebuffBorder, btn.TempEnchantBorder,
    btn.BorderFrame,
  }
  for _, r in ipairs(hide) do
    if r and r.Hide then r:Hide() end
  end
end

local TILE_W = 1 / 8

local function SetStripTile(tex, stripTex, tileIndex)
  local u1 = tileIndex * TILE_W
  local u2 = (tileIndex + 1) * TILE_W
  tex:SetTexture(stripTex)
  tex:SetTexCoord(u1, u2, 0, 1)
end

local function EnsureOverlayFrame(btn)
  if btn.RSB_OverlayFrame then return btn.RSB_OverlayFrame end
  local f = CreateFrame("Frame", nil, btn)
  -- ensure our textures render behind the aura's icon
  local lvl = (btn.GetFrameLevel and btn:GetFrameLevel()) or 0
  if lvl > 0 then
    f:SetFrameLevel(lvl - 1)
  else
    f:SetFrameLevel(0)
  end
  btn.RSB_OverlayFrame = f
  return f
end

local function EnsureStrip(btn, icon)
  if btn.RSB_Strip then return end

  local f = EnsureOverlayFrame(btn)

  local bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  bg:SetTexture(cfg.bgTex)
  bg:SetVertexColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
  bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.bgOutset, cfg.bgOutset)
  bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.bgOutset, -cfg.bgOutset)

  local tl = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local t  = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local tr = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local r  = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local br = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local b  = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local bl = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  local l  = f:CreateTexture(nil, "BACKGROUND", nil, 1)

  local bc = cfg.borderColor
  for _, tex in ipairs({tl,t,tr,r,br,b,bl,l}) do
    tex:SetVertexColor(bc[1], bc[2], bc[3], bc[4])
  end

  local edge = cfg.edgeSize
  local outset = cfg.outset
  local stripTex = cfg.stripTex

  SetStripTile(tl, stripTex, 0); tl:SetSize(edge, edge); tl:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
  SetStripTile(tr, stripTex, 2); tr:SetSize(edge, edge); tr:SetPoint("TOPRIGHT", icon, "TOPRIGHT", outset, outset)
  SetStripTile(br, stripTex, 4); br:SetSize(edge, edge); br:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
  SetStripTile(bl, stripTex, 6); bl:SetSize(edge, edge); bl:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -outset, -outset)

  SetStripTile(t, stripTex, 1)
  t:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
  t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)

  SetStripTile(r, stripTex, 3)
  r:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
  r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)

  SetStripTile(b, stripTex, 5)
  b:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
  b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)

  SetStripTile(l, stripTex, 7)
  l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
  l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)

  btn.RSB_Strip = { bg=bg, tl=tl,t=t,tr=tr,r=r,br=br,b=b,bl=bl,l=l }
end

local function ApplyStrip(btn, icon)
  EnsureStrip(btn, icon)
  local s = btn.RSB_Strip
  if not s then return end

  -- background
  s.bg:SetTexture(cfg.bgTex)
  s.bg:SetVertexColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
  s.bg:ClearAllPoints()
  s.bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.bgOutset, cfg.bgOutset)
  s.bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.bgOutset, -cfg.bgOutset)

  local bc = cfg.borderColor
  local edge = cfg.edgeSize
  local outset = cfg.outset
  local stripTex = cfg.stripTex

  for _,k in ipairs({"tl","t","tr","r","br","b","bl","l"}) do
    local tex = s[k]
    tex:SetTexture(stripTex)
    tex:SetVertexColor(bc[1], bc[2], bc[3], bc[4])
  end

  -- corners
  SetStripTile(s.tl, stripTex, 0); s.tl:SetSize(edge, edge); s.tl:ClearAllPoints(); s.tl:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
  SetStripTile(s.tr, stripTex, 2); s.tr:SetSize(edge, edge); s.tr:ClearAllPoints(); s.tr:SetPoint("TOPRIGHT", icon, "TOPRIGHT", outset, outset)
  SetStripTile(s.br, stripTex, 4); s.br:SetSize(edge, edge); s.br:ClearAllPoints(); s.br:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
  SetStripTile(s.bl, stripTex, 6); s.bl:SetSize(edge, edge); s.bl:ClearAllPoints(); s.bl:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -outset, -outset)

  -- edges
  SetStripTile(s.t, stripTex, 1)
  s.t:ClearAllPoints()
  s.t:SetPoint("TOPLEFT", s.tl, "TOPRIGHT", 0, 0)
  s.t:SetPoint("BOTTOMRIGHT", s.tr, "BOTTOMLEFT", 0, 0)

  SetStripTile(s.r, stripTex, 3)
  s.r:ClearAllPoints()
  s.r:SetPoint("TOPLEFT", s.tr, "BOTTOMLEFT", 0, 0)
  s.r:SetPoint("BOTTOMRIGHT", s.br, "TOPRIGHT", 0, 0)

  SetStripTile(s.b, stripTex, 5)
  s.b:ClearAllPoints()
  s.b:SetPoint("TOPLEFT", s.bl, "TOPRIGHT", 0, 0)
  s.b:SetPoint("BOTTOMRIGHT", s.br, "BOTTOMLEFT", 0, 0)

  SetStripTile(s.l, stripTex, 7)
  s.l:ClearAllPoints()
  s.l:SetPoint("TOPLEFT", s.tl, "BOTTOMLEFT", 0, 0)
  s.l:SetPoint("BOTTOMRIGHT", s.bl, "TOPRIGHT", 0, 0)

  SetOverlayVisibility(btn)
end

local function EnsureFullBorder(btn, icon)
  if btn.RSB_Full then return end
  local f = EnsureOverlayFrame(btn)

  local bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  bg:SetTexture(cfg.bgTex)
  bg:SetVertexColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
  bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.bgOutset, cfg.bgOutset)
  bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.bgOutset, -cfg.bgOutset)

  local b = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  b:SetTexture(cfg.borderTex)
  b:SetVertexColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
  b:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.outset, cfg.outset)
  b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.outset, -cfg.outset)

  btn.RSB_Full = { bg=bg, border=b }
end

local function ApplyFullBorder(btn, icon)
  EnsureFullBorder(btn, icon)
  local f = btn.RSB_Full
  if not f then return end

  f.bg:SetTexture(cfg.bgTex)
  f.bg:SetVertexColor(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
  f.bg:ClearAllPoints()
  f.bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.bgOutset, cfg.bgOutset)
  f.bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.bgOutset, -cfg.bgOutset)

  f.border:SetTexture(cfg.borderTex)
  f.border:SetVertexColor(cfg.borderColor[1], cfg.borderColor[2], cfg.borderColor[3], cfg.borderColor[4])
  f.border:ClearAllPoints()
  f.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -cfg.outset, cfg.outset)
  f.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", cfg.outset, -cfg.outset)

  SetOverlayVisibility(btn)
end

local function SetOverlayVisibility(btn)
  if btn.RSB_Strip then
    btn.RSB_Strip.bg:SetShown(DB.showBG)
    for _,k in ipairs({"tl","t","tr","r","br","b","bl","l"}) do
      btn.RSB_Strip[k]:SetShown(DB.showBorder)
    end
  end
  if btn.RSB_Full then
    btn.RSB_Full.bg:SetShown(DB.showBG)
    btn.RSB_Full.border:SetShown(DB.showBorder)
  end
end

local function HideUnusedMode(btn)
  if DB.mode == "galaxy_strip" then
    if btn.RSB_Full then
      btn.RSB_Full.bg:Hide()
      btn.RSB_Full.border:Hide()
    end
  else
    if btn.RSB_Strip then
      btn.RSB_Strip.bg:Hide()
      for _,k in ipairs({"tl","t","tr","r","br","b","bl","l"}) do
        btn.RSB_Strip[k]:Hide()
      end
    end
  end
end

------------------------------------------------------------
-- Masque integration (non-destructive)
-- We never let Masque touch Blizzard's aura button directly.
-- Instead, we create an overlay Frame and feed that to Masque.
------------------------------------------------------------
local function EnsureMasqueFrame(btn, icon)
  if btn.RSB_MSQFrame then return btn.RSB_MSQFrame end

  local f = CreateFrame("Frame", nil, btn)
  f:SetAllPoints(icon) -- stays in sync with Blizzard sizing/layout
  f:SetFrameStrata(btn:GetFrameStrata())
  f:SetFrameLevel((btn:GetFrameLevel() or 0) + 5) -- above icon

  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(f)
  f.Icon = t

  btn.RSB_MSQFrame = f
  return f
end

local function MasqueAdd(btn, icon)
  if not MSQ_Group then return end

  local mf = EnsureMasqueFrame(btn, icon)
  -- keep the overlay icon in sync
  mf.Icon:SetTexture(icon:GetTexture())
  if mf.Icon.SetTexCoord then
    mf.Icon:SetTexCoord(0, 1, 0, 1)
  end

  -- Hide the original icon so Masque shapes/masks don't fight the default square icon.
  if icon.SetAlpha then icon:SetAlpha(0) end
  if icon.SetTexCoord then icon:SetTexCoord(0, 1, 0, 1) end

  if not mf.RSB_MSQAdded then
    -- Strict=true is implied for Frame objects, but we still pass Type="Aura" to use aura regions.
    MSQ_Group:AddButton(mf, { Icon = mf.Icon }, "Aura", true)
    mf.RSB_MSQAdded = true
  end

  -- Hide our custom overlays (if any)
  if btn.RSB_Strip then
    btn.RSB_Strip.bg:Hide()
    for _,k in ipairs({"tl","t","tr","r","br","b","bl","l"}) do
      btn.RSB_Strip[k]:Hide()
    end
  end
  if btn.RSB_Full then
    btn.RSB_Full.bg:Hide()
    btn.RSB_Full.border:Hide()
  end

  -- Hide Blizzard borders to avoid double-frames
  HideDefaultBorders(btn)
end

local function MasqueSetVisible(btn, visible)
  if not btn or not btn.RSB_MSQFrame then return end
  btn.RSB_MSQFrame:SetShown(visible)
end

------------------------------------------------------------
-- Styling
------------------------------------------------------------
local styleRevision = 0
local function BumpRevision()
  styleRevision = styleRevision + 1
end

local function StyleButton(btn)
  if not btn or btn.isExample or btn.hasValidInfo == false then return end

  local icon = GetIcon(btn)
  if not icon or not icon.GetTexture then return end
  local tex = icon:GetTexture()
  if not tex then return end

  -- de-dup on frequent UNIT_AURA
  if btn.RSB_Rev == styleRevision then
    -- if Masque is enabled we still need to keep the overlay icon texture in sync
    if DB.useMasque and btn.RSB_MSQFrame and btn.RSB_MSQFrame.Icon then
      btn.RSB_MSQFrame.Icon:SetTexture(tex)
    end
    return
  end

  if DB.useMasque then
    InitMasque()
    if MSQ_Group then
      MasqueAdd(btn, icon)
      MasqueSetVisible(btn, true)
      btn.RSB_Rev = styleRevision
      return
    end
    -- Masque requested but not present => fall back to our overlays
  end

  -- Not using Masque: ensure Masque overlay is hidden
  MasqueSetVisible(btn, false)

  -- Crop icon (classic Roth look)
  if icon.SetAlpha then icon:SetAlpha(1) end
  local c = cfg.iconCrop
  if icon.SetTexCoord then
    icon:SetTexCoord(c, 1 - c, c, 1 - c)
  end

  HideDefaultBorders(btn)
  HideUnusedMode(btn)

  if DB.mode == "galaxy_strip" then
    ApplyStrip(btn, icon)
  else
    ApplyFullBorder(btn, icon)
  end

  btn.RSB_Rev = styleRevision
end

------------------------------------------------------------
-- Scanning (only active aura buttons, throttled)
------------------------------------------------------------
local function IteratePool(pool)
  if not pool or not pool.EnumerateActive then return end
  for btn in pool:EnumerateActive() do
    StyleButton(btn)
  end
end

local function ScanContainer(container)
  if not container then return end
  -- Most modern aura containers use pools
  IteratePool(container.buttonPool)
  IteratePool(container.auraButtonPool)
  IteratePool(container.auraPool)
  IteratePool(container.buffPool)
  IteratePool(container.debuffPool)

  -- Fallback: common tables
  local t = container.auraFrames or container.auraButtons or container.buttons
  if type(t) == "table" then
    for _, btn in pairs(t) do
      StyleButton(btn)
    end
  end
end

local function GetAuraContainers()
  local list = {}
  local function add(f) if f then list[#list+1] = f end end

  -- Retail aura frames
  if _G.BuffFrame then
    add(_G.BuffFrame.AuraContainer)
    add(_G.BuffFrame.buffContainer)
    add(_G.BuffFrame.debuffContainer)
  end
  if _G.DebuffFrame then
    add(_G.DebuffFrame.AuraContainer)
    add(_G.DebuffFrame.buffContainer)
    add(_G.DebuffFrame.debuffContainer)
  end

  return list
end

local lastReq = 0
local pending = false
local MIN_REQ_INTERVAL = 0.30

local function DoUpdate()
  pending = false
  if DB.enabled == false then return end
  ResolveMedia()

  local containers = GetAuraContainers()
  for i = 1, #containers do
    ScanContainer(containers[i])
  end
end

local function RequestUpdate()
  local now = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
  if (now - lastReq) < MIN_REQ_INTERVAL then return end
  lastReq = now
  if pending then return end
  pending = true
  C_Timer.After(0.05, DoUpdate)
end

function RothShinyBuffs_ApplySettings()
  EnsureDefaults()
  ResolveMedia()
  BumpRevision()
  if DB.useMasque then
    InitMasque()
    if MSQ_Group and MSQ_Group.ReSkin then
      MSQ_Group:ReSkin()
    end
  end
  RequestUpdate()
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
EnsureDefaults()
RegisterBuiltInMedia()
ResolveMedia()

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("ADDON_LOADED")

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "UNIT_AURA" then
    if arg1 == "player" then
      RequestUpdate()
    end
    return
  end

  if event == "ADDON_LOADED" then
    -- Ensure we rescan once BuffFrame is available.
    if arg1 == "Blizzard_BuffFrame" then
      RequestUpdate()
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    -- Multiple delayed passes to catch late-created aura buttons.
    C_Timer.After(0, DoUpdate)
    C_Timer.After(0.25, DoUpdate)
    C_Timer.After(1.0, DoUpdate)
    return
  end

  RequestUpdate()
end)
