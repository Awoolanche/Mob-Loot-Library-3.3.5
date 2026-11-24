local addonName, ns = ...
local C, f = ns.C, ns.frame
local floor, format = math.floor, string.format
local SCALE_MIN, SCALE_MAX = C.SCALE_MIN, C.SCALE_MAX

local panel = CreateFrame("Frame", "MobLootOptionsPanel", UIParent)
panel.name = "Mob Loot Library"

local pTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
pTitle:SetPoint("TOPLEFT", 16, -16)
pTitle:SetText("Mob Loot Library")
local pSub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
pSub:SetPoint("TOPLEFT", pTitle, "BOTTOMLEFT", 0, -8)
pSub:SetWidth(420); pSub:SetJustifyH("LEFT")
pSub:SetText("Window settings. You can also resize the window by dragging the triangle in its bottom right corner.")

local scaleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleLabel:SetPoint("TOPLEFT", pSub, "BOTTOMLEFT", 0, -28)

local slider = CreateFrame("Slider", "MobLootScaleSlider", panel, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 4, -14)
slider:SetWidth(260)
slider:SetMinMaxValues(SCALE_MIN, SCALE_MAX)
slider:SetValueStep(0.05)
getglobal("MobLootScaleSliderLow"):SetText(format("%d%%", SCALE_MIN * 100))
getglobal("MobLootScaleSliderHigh"):SetText(format("%d%%", SCALE_MAX * 100))
getglobal("MobLootScaleSliderText"):SetText("")

local syncing = false
local function ShowScale(v)
    scaleLabel:SetText(format("Window scale: %d%%", floor(v * 100 + 0.5)))
end
slider:SetScript("OnValueChanged", function(self, value)
    if syncing then return end
    ShowScale(ns.SetWindowScale(value))
end)

local function SyncPanel()
    local sc = f:GetScale()
    syncing = true
    slider:SetValue(sc)
    syncing = false
    ShowScale(sc)
end
panel:SetScript("OnShow", SyncPanel)

local function MakeOptButton(text, w, anchorTo, x, y, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetText(text)
    b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
    b:SetScript("OnClick", onClick)
    return b
end
local bScale = MakeOptButton("Reset Scale", 130, slider, -4, -28, function() ns.ResetScale(); SyncPanel() end)
local bPos = MakeOptButton("Reset Position", 130, bScale, 0, -10, function() ns.ResetPosition() end)
local bSize = MakeOptButton("Reset Window Size", 130, bPos, 0, -10, function() ns.ResetSize() end)
local bShow = MakeOptButton("Show Window", 130, bSize, 0, -26, function()
    f:Show(); ns.Refresh(true)
end)

panel.okay = function() end
panel.cancel = function() end
panel.default = function() ns.ResetScale(); ns.ResetPosition(); ns.ResetSize(); SyncPanel() end
panel.refresh = SyncPanel
InterfaceOptions_AddCategory(panel)

-- opened by the gear button in the library window
function ns.OpenSettings()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)   -- first call only opens the frame on some clients
    if InterfaceOptionsFrame and InterfaceOptionsFrame.Raise then InterfaceOptionsFrame:Raise() end
end
