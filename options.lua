-- RothShinyBuffs Settings canvas for Retail 12.1.
local ADDON_NAME = ...
if ADDON_NAME ~= "RothShinyBuffs" then return end

local LibStub = _G.LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil
local unpack = unpack or table.unpack
local controls = {}
local registered = false

local function EnsureDefaults()
  if type(_G.RothShinyBuffs_EnsureDefaults) == "function" then
    _G.RothShinyBuffs_EnsureDefaults()
  end
end

local function Apply()
  if type(_G.RothShinyBuffs_ApplySettings) == "function" then
    _G.RothShinyBuffs_ApplySettings()
  end
end

local function DB()
  EnsureDefaults()
  return RothShinyBuffsDB
end

local function CreateLabel(parent, text, fontObject)
  local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontNormal")
  label:SetText(text)
  label:SetJustifyH("LEFT")
  return label
end

local function CreateCheckbox(parent, label, tooltip, key)
  local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  local text = checkbox.Text or checkbox.text
  if text then
    text:SetText(label)
  else
    text = CreateLabel(checkbox, label, "GameFontHighlight")
    text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
  end
  checkbox.tooltipText = tooltip
  checkbox.refresh = function() checkbox:SetChecked(DB()[key] == true) end
  checkbox:SetScript("OnClick", function(self)
    DB()[key] = self:GetChecked() == true
    Apply()
  end)
  controls[#controls + 1] = checkbox
  return checkbox
end

local function CreateSlider(parent, label, key, minimum, maximum, step, formatter)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 48)
  local title = CreateLabel(holder, label)
  title:SetPoint("TOPLEFT", 0, 0)
  local valueLabel = CreateLabel(holder, "", "GameFontHighlightSmall")
  valueLabel:SetPoint("TOPRIGHT", 0, 0)

  local slider = CreateFrame("Slider", nil, holder, "UISliderTemplate")
  slider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  slider:SetWidth(280)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  local refreshing = false
  local function Format(value)
    if formatter then return formatter(value) end
    if step < 1 then return string.format("%.2f", value) end
    return tostring(math.floor(value + 0.5))
  end

  holder.refresh = function()
    refreshing = true
    local value = tonumber(DB()[key]) or minimum
    if value < minimum then value = minimum end
    if value > maximum then value = maximum end
    slider:SetValue(value)
    valueLabel:SetText(Format(value))
    refreshing = false
  end

  slider:SetScript("OnValueChanged", function(_, value)
    if refreshing then return end
    DB()[key] = value
    valueLabel:SetText(Format(value))
    Apply()
  end)

  controls[#controls + 1] = holder
  return holder
end

local function CreateDropdown(parent, label, itemsProvider, key)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 56)
  local title = CreateLabel(holder, label)
  title:SetPoint("TOPLEFT", 0, 0)

  local dropdown = CreateFrame("Frame", nil, holder, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -16, -6)

  UIDropDownMenu_Initialize(dropdown, function()
    local selected = DB()[key]
    for _, item in ipairs(itemsProvider()) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = item.text
      info.value = item.value
      info.checked = item.value == selected
      info.func = function()
        DB()[key] = item.value
        UIDropDownMenu_SetSelectedValue(dropdown, item.value)
        Apply()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)

  holder.refresh = function() UIDropDownMenu_SetSelectedValue(dropdown, DB()[key]) end
  controls[#controls + 1] = holder
  return holder
end

local function CreateColorSwatch(parent, label, key)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(520, 28)
  local title = CreateLabel(holder, label)
  title:SetPoint("LEFT", 0, 0)

  local button = CreateFrame("Button", nil, holder)
  button:SetSize(24, 20)
  button:SetPoint("RIGHT", 0, 0)
  local swatch = button:CreateTexture(nil, "ARTWORK")
  swatch:SetAllPoints(button)

  local function Refresh()
    local color = DB()[key]
    swatch:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  end

  button:SetScript("OnClick", function()
    local original = { unpack(DB()[key]) }
    local function Commit()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local alpha = 1
      if ColorPickerFrame.GetColorAlpha then
        alpha = ColorPickerFrame:GetColorAlpha()
      elseif OpacitySliderFrame and OpacitySliderFrame.GetValue then
        alpha = 1 - OpacitySliderFrame:GetValue()
      end
      DB()[key] = { r, g, b, alpha }
      Refresh()
      Apply()
    end

    local function Cancel(previous)
      local value = type(previous) == "table" and previous or original
      DB()[key] = { value[1], value[2], value[3], value[4] or 1 }
      Refresh()
      Apply()
    end

    local color = DB()[key]
    local info = {
      r = color[1],
      g = color[2],
      b = color[3],
      opacity = 1 - (color[4] or 1),
      hasOpacity = true,
      swatchFunc = Commit,
      opacityFunc = Commit,
      cancelFunc = Cancel,
      previousValues = original,
    }

    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
      ColorPickerFrame:SetupColorPickerAndShow(info)
    else
      ColorPickerFrame.func = Commit
      ColorPickerFrame.opacityFunc = Commit
      ColorPickerFrame.cancelFunc = Cancel
      ColorPickerFrame.hasOpacity = true
      ColorPickerFrame.opacity = info.opacity
      ColorPickerFrame.previousValues = original
      ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
      ColorPickerFrame:Show()
    end
  end)

  holder.refresh = Refresh
  controls[#controls + 1] = holder
  return holder
end

local function MediaItems(kind)
  local items = {}
  if LSM and type(LSM.List) == "function" then
    local list = LSM:List(kind) or {}
    table.sort(list)
    for _, name in ipairs(list) do items[#items + 1] = { text = name, value = name } end
  end
  return items
end

local function RefreshControls()
  EnsureDefaults()
  for _, control in ipairs(controls) do
    if type(control.refresh) == "function" then control.refresh() end
  end
end

local function BuildPanel(panel)
  if panel.__rsbBuilt then return end
  panel.__rsbBuilt = true
  EnsureDefaults()

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", -30, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 1)
  scroll:SetScrollChild(content)

  local y = -12
  local function Place(widget, height, x)
    widget:SetParent(content)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", x or 16, y)
    y = y - (height or widget:GetHeight() or 24) - 10
  end

  local title = CreateLabel(content, "RothShinyBuffs", "GameFontNormalLarge")
  Place(title, 28)
  local description = CreateLabel(
    content,
    "Styles only Blizzard's pre-created public BuffFrame and DebuffFrame slots. Aura assignment, visibility, pools and private anchors remain Blizzard-owned.",
    "GameFontHighlightSmall"
  )
  description:SetWidth(520)
  description:SetWordWrap(true)
  Place(description, 52)

  Place(CreateCheckbox(content, "Enabled", "Show addon-owned background and border art.", "enabled"), 24)
  Place(CreateCheckbox(content, "Show border", nil, "showBorder"), 24)
  Place(CreateCheckbox(content, "Show background", nil, "showBG"), 24)

  Place(CreateDropdown(content, "Mode", function()
    return {
      { text = "Galaxy Strip (8 tiles)", value = "galaxy_strip" },
      { text = "Full Border (single texture)", value = "full_border" },
    }
  end, "mode"), 56)

  Place(CreateSlider(content, "Icon crop", "iconCrop", 0, 0.20, 0.01, function(value) return string.format("%.2f", value) end), 48)
  Place(CreateSlider(content, "Strip tile size", "edgeSize", 4, 64, 1), 48)
  Place(CreateSlider(content, "Border outset", "outset", 0, 24, 1), 48)
  Place(CreateSlider(content, "Background outset", "bgOutset", 0, 24, 1), 48)

  local mediaHeader = CreateLabel(content, "LibSharedMedia", "GameFontNormalLarge")
  Place(mediaHeader, 28)
  Place(CreateDropdown(content, "Strip border", function() return MediaItems("border") end, "stripBorderName"), 56)
  Place(CreateDropdown(content, "Full border", function() return MediaItems("border") end, "borderName"), 56)
  Place(CreateDropdown(content, "Background", function() return MediaItems("background") end, "bgName"), 56)

  local colorHeader = CreateLabel(content, "Colors", "GameFontNormalLarge")
  Place(colorHeader, 28)
  Place(CreateColorSwatch(content, "Border color", "borderColor"), 28)
  Place(CreateColorSwatch(content, "Background color", "bgColor"), 28)

  local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  reset:SetSize(160, 24)
  reset:SetText("Reset to defaults")
  reset:SetScript("OnClick", function()
    if type(_G.RothShinyBuffs_ResetDefaults) == "function" then _G.RothShinyBuffs_ResetDefaults() end
    Apply()
    RefreshControls()
  end)
  Place(reset, 24)

  content:SetHeight(math.max(1, -y + 20))
  panel:SetScript("OnShow", RefreshControls)
  RefreshControls()
end

local function RegisterSettings()
  if registered or not Settings or not Settings.RegisterCanvasLayoutCategory then return false end
  registered = true

  local panel = CreateFrame("Frame")
  panel:SetScript("OnShow", function(self)
    BuildPanel(self)
    RefreshControls()
  end)

  local category = Settings.RegisterCanvasLayoutCategory(panel, "RothShinyBuffs")
  Settings.RegisterAddOnCategory(category)
  _G.RothShinyBuffs_SettingsCategoryID = category:GetID()
  return true
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, RegisterSettings)
else
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function(self)
    if RegisterSettings() then self:UnregisterAllEvents() end
  end)
end
