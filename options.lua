-- RothShinyBuffs Options (Settings UI, Midnight 12.0)
-- Notes:
--   * No file path inputs. All textures are selected via LibSharedMedia.
--   * Scrollable panel.
--   * Masque toggle disables non-Masque visual settings (Masque owns visuals).

local ADDON_NAME = ...
if ADDON_NAME ~= "RothShinyBuffs" then return end

RothShinyBuffsDB = RothShinyBuffsDB or {}
local DB = RothShinyBuffsDB

local LibStub = LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil
local Masque = LibStub and LibStub("Masque", true) or nil

local function EnsureDefaults()
  if type(RothShinyBuffs_EnsureDefaults) == "function" then
    RothShinyBuffs_EnsureDefaults()
  end
end

local function Apply()
  if type(RothShinyBuffs_ApplySettings) == "function" then
    RothShinyBuffs_ApplySettings()
  end
end

------------------------------------------------------------
-- UI helpers
------------------------------------------------------------
local function CreateHeader(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  return fs
end

local function CreateSubHeader(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  return fs
end

local function CreateText(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetText(text)
  fs:SetJustifyH("LEFT")
  fs:SetWidth(520)
  fs:SetWordWrap(true)
  return fs
end

local function CreateCheckbox(parent, label, tooltip, getter, setter)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  local text = cb.Text or cb.text
  if text then
    text:SetText(label)
  else
    text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    text:SetText(label)
  end
  if tooltip then
    cb.tooltipText = tooltip
  end

  cb.refresh = function()
    cb:SetChecked(getter() and true or false)
  end

  cb:SetScript("OnClick", function(self)
    setter(self:GetChecked() and true or false)
    cb.refresh()
  end)

  cb:HookScript("OnShow", function() cb.refresh() end)
  return cb
end

local function CreateDropdown(parent, label, items, getter, setter)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 56)

  local t = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  t:SetPoint("TOPLEFT", 0, 0)
  t:SetText(label)

  local dd = CreateFrame("Frame", nil, holder, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", t, "BOTTOMLEFT", -16, -6)

  local function init()
    local selected = getter()
    for _, it in ipairs(items) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = it.text
      info.value = it.value
      info.func = function()
        UIDropDownMenu_SetSelectedValue(dd, it.value)
        setter(it.value)
      end
      info.checked = (it.value == selected)
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(dd, init)

  holder.refresh = function()
    UIDropDownMenu_SetSelectedValue(dd, getter())
  end

  holder.dropdown = dd
  holder:HookScript("OnShow", function() holder.refresh() end)
  return holder
end

local function CreateSlider(parent, label, minV, maxV, step, getter, setter, fmt)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 48)

  local lab = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  lab:SetPoint("TOPLEFT", 0, 0)
  lab:SetText(label)

  local val = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  val:SetPoint("TOPRIGHT", 0, 0)

  local s = CreateFrame("Slider", nil, holder, "UISliderTemplate")
  s:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -8)
  s:SetWidth(260)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)

  local isSetting = false
  local function formatValue(v)
    if fmt then return fmt(v) end
    if step < 1 then
      return string.format("%.2f", v)
    end
    return tostring(math.floor(v + 0.5))
  end

  holder.refresh = function()
    isSetting = true
    local v = tonumber(getter()) or minV
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    s:SetValue(v)
    val:SetText(formatValue(v))
    isSetting = false
  end

  s:SetScript("OnValueChanged", function(_, v)
    if isSetting then return end
    val:SetText(formatValue(v))
    setter(v)
  end)

  holder.slider = s
  holder:HookScript("OnShow", function() holder.refresh() end)
  holder.refresh()
  return holder
end

local function CreateColorSwatch(parent, label, getter, setter)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 28)

  local t = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  t:SetPoint("LEFT", 0, 0)
  t:SetText(label)

  local btn = CreateFrame("Button", nil, holder)
  btn:SetSize(20, 20)
  btn:SetPoint("RIGHT", 0, 0)

  local tex = btn:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(btn)
  btn.tex = tex

  local function update()
    local c = getter()
    tex:SetColorTexture(c[1], c[2], c[3], 1)
  end

  btn:SetScript("OnClick", function()
    local c = getter()
    local function onChanged()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
      setter({ r, g, b, a })
      update()
    end
    ColorPickerFrame.func = onChanged
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacityFunc = onChanged
    ColorPickerFrame.cancelFunc = function(prev)
      if prev then
        setter(prev)
        update()
      end
    end
    ColorPickerFrame.previousValues = { c[1], c[2], c[3], c[4] }
    ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
    if OpacitySliderFrame then
      OpacitySliderFrame:SetValue(1 - (c[4] or 1))
    end
    ColorPickerFrame:Show()
  end)

  holder.refresh = update
  holder:HookScript("OnShow", update)
  update()
  return holder
end

local function DisableControl(ctrl, disabled)
  if not ctrl then return end
  local en = not disabled
  if ctrl.SetEnabled then ctrl:SetEnabled(en) end
  if ctrl.slider and ctrl.slider.SetEnabled then ctrl.slider:SetEnabled(en) end
  if ctrl.dropdown then
    if en then
      UIDropDownMenu_EnableDropDown(ctrl.dropdown)
    else
      UIDropDownMenu_DisableDropDown(ctrl.dropdown)
    end
  end
  -- Checkbox template has .Text
  if ctrl.Text and ctrl.Text.SetFontObject then
    ctrl.Text:SetFontObject(en and GameFontHighlight or GameFontDisable)
  end
end

------------------------------------------------------------
-- Build LSM lists
------------------------------------------------------------
local function LSMItems(kind, prefixFirst)
  local items = {}
  if prefixFirst then
    items[#items+1] = { text = prefixFirst, value = "" }
  end
  if not LSM or not LSM.List then return items end
  local list = LSM:List(kind) or {}
  table.sort(list)
  for _, name in ipairs(list) do
    items[#items+1] = { text = name, value = name }
  end
  return items
end

------------------------------------------------------------
-- Panel
------------------------------------------------------------
local controls = {}

local function Refresh(panel)
  EnsureDefaults()
  for _, c in ipairs(controls) do
    if c.refresh then c.refresh() end
  end

  local useMasque = (DB.useMasque == true) and (Masque ~= nil)
  -- Disable non-Masque visuals if Masque is active.
  for _, c in ipairs(controls) do
    if c._rsbNonMasque then
      DisableControl(c, useMasque)
    end
  end

  if panel._masqueNote then
    if DB.useMasque and not Masque then
      panel._masqueNote:SetText("Masque is not loaded. Install/enable Masque to use this option.")
    else
      panel._masqueNote:SetText("")
    end
  end
end

local function Build(panel)
  if panel._built then return end
  panel._built = true
  EnsureDefaults()

  -- Scroll container
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", -30, 8)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 1)
  scroll:SetScrollChild(content)

  panel._scroll = scroll
  panel._content = content

  local y = -12
  local function place(widget, h, x)
    x = x or 16
    widget:SetParent(content)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", x, y)
    y = y - (h or widget:GetHeight() or 24) - 10
  end

  local title = CreateHeader(content, "RothShinyBuffs")
  place(title, 28, 16)

  local desc = CreateText(content, "Skins Blizzard aura icons (Buffs/Debuffs) without touching their layout (Edit Mode). Uses LibSharedMedia for borders/backgrounds. Optional Masque integration.")
  place(desc, 42, 16)

  local enabled = CreateCheckbox(content, "Enabled",
    nil,
    function() return DB.enabled ~= false end,
    function(v) DB.enabled = v; Apply() end)
  place(enabled, 24, 16)
  controls[#controls+1] = enabled

  local useMasque = CreateCheckbox(content, "Use Masque (if installed)",
    "When enabled, Masque controls icon visuals. RothShinyBuffs border/background options are disabled.",
    function() return DB.useMasque == true end,
    function(v) DB.useMasque = v; Apply(); Refresh(panel) end)
  place(useMasque, 24, 16)
  controls[#controls+1] = useMasque

  panel._masqueNote = CreateText(content, "")
  place(panel._masqueNote, 20, 36)

  local mode = CreateDropdown(content, "Mode", {
      { text = "Galaxy Strip (8 tiles)", value = "galaxy_strip" },
      { text = "Full Border (single texture)", value = "full_border" },
    },
    function() return DB.mode or "galaxy_strip" end,
    function(v) DB.mode = v; Apply() end)
  mode._rsbNonMasque = true
  place(mode, 56, 16)
  controls[#controls+1] = mode

  local showBorder = CreateCheckbox(content, "Show Border", nil,
    function() return DB.showBorder ~= false end,
    function(v) DB.showBorder = v; Apply() end)
  showBorder._rsbNonMasque = true
  place(showBorder, 24, 16)
  controls[#controls+1] = showBorder

  local showBG = CreateCheckbox(content, "Show Background", nil,
    function() return DB.showBG ~= false end,
    function(v) DB.showBG = v; Apply() end)
  showBG._rsbNonMasque = true
  place(showBG, 24, 16)
  controls[#controls+1] = showBG

  local sub = CreateSubHeader(content, "Geometry")
  place(sub, 20, 16)

  local edgeSize = CreateSlider(content, "Strip tile size (px)", 8, 32, 1,
    function() return DB.edgeSize or 16 end,
    function(v) DB.edgeSize = v; Apply() end)
  edgeSize._rsbNonMasque = true
  place(edgeSize, 48, 16)
  controls[#controls+1] = edgeSize

  local outset = CreateSlider(content, "Border outset (px)", 0, 16, 1,
    function() return DB.outset or 3 end,
    function(v) DB.outset = v; Apply() end)
  outset._rsbNonMasque = true
  place(outset, 48, 16)
  controls[#controls+1] = outset

  local bgOutset = CreateSlider(content, "Background outset (px)", 0, 16, 1,
    function() return DB.bgOutset or 2 end,
    function(v) DB.bgOutset = v; Apply() end)
  bgOutset._rsbNonMasque = true
  place(bgOutset, 48, 16)
  controls[#controls+1] = bgOutset

  local crop = CreateSlider(content, "Icon crop", 0.00, 0.15, 0.01,
    function() return DB.iconCrop or 0.07 end,
    function(v) DB.iconCrop = v; Apply() end,
    function(v) return string.format("%.2f", v) end)
  crop._rsbNonMasque = true
  place(crop, 48, 16)
  controls[#controls+1] = crop

  local sub2 = CreateSubHeader(content, "Textures (LibSharedMedia)")
  place(sub2, 20, 16)

  local stripBorder = CreateDropdown(content, "Border (Strip mode)", LSMItems("border"),
    function() return DB.stripBorderName or "RothShinyBuffs: Galaxy Strip" end,
    function(v) DB.stripBorderName = v; Apply() end)
  stripBorder._rsbNonMasque = true
  place(stripBorder, 56, 16)
  controls[#controls+1] = stripBorder

  local border = CreateDropdown(content, "Border (Full mode)", LSMItems("border"),
    function() return DB.borderName or "RothShinyBuffs: Border64" end,
    function(v) DB.borderName = v; Apply() end)
  border._rsbNonMasque = true
  place(border, 56, 16)
  controls[#controls+1] = border

  local bg = CreateDropdown(content, "Background", LSMItems("background"),
    function() return DB.bgName or "RothShinyBuffs: Solid" end,
    function(v) DB.bgName = v; Apply() end)
  bg._rsbNonMasque = true
  place(bg, 56, 16)
  controls[#controls+1] = bg

  local sub3 = CreateSubHeader(content, "Colors")
  place(sub3, 20, 16)

  local borderColor = CreateColorSwatch(content, "Border color", function() return DB.borderColor end, function(c) DB.borderColor = c; Apply() end)
  borderColor._rsbNonMasque = true
  place(borderColor, 28, 16)
  controls[#controls+1] = borderColor

  local bgColor = CreateColorSwatch(content, "Background color", function() return DB.bgColor end, function(c) DB.bgColor = c; Apply() end)
  bgColor._rsbNonMasque = true
  place(bgColor, 28, 16)
  controls[#controls+1] = bgColor

  local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  reset:SetText("Reset to defaults")
  reset:SetSize(160, 24)
  reset:SetScript("OnClick", function()
    for k in pairs(DB) do DB[k] = nil end
    EnsureDefaults()
    Apply()
    Refresh(panel)
  end)
  place(reset, 24, 16)

  -- Ensure content height is large enough for scrolling
  content:SetHeight(math.abs(y) + 80)

  Refresh(panel)
end

local function RegisterPanel()
  local panel = CreateFrame("Frame")
  panel.name = "RothShinyBuffs"
  panel:SetScript("OnShow", function(self)
    Build(self)
    Refresh(self)
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
  else
    InterfaceOptions_AddCategory(panel)
  end
end

RegisterPanel()
