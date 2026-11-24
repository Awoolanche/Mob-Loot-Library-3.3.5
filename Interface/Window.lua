local addonName, ns = ...
local C, S = ns.C, ns.state
local WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H = C.WIN_MIN_W, C.WIN_MIN_H, C.WIN_MAX_W, C.WIN_MAX_H

local f = CreateFrame("Frame", "MobLootFrame", UIParent)
f:SetSize(C.DEF_W, C.DEF_H)
f:SetPoint("CENTER", 200, 0)
f:SetFrameStrata("DIALOG")
f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
f:SetResizable(true)
f:SetMinResize(WIN_MIN_W, WIN_MIN_H); f:SetMaxResize(WIN_MAX_W, WIN_MAX_H)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); ns.SavePos() end)
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:Hide()
tinsert(UISpecialFrames, "MobLootFrame")   -- ESC closes it

local winTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
winTitle:SetPoint("TOP", 0, -13)
winTitle:SetText("MobLoot Library")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

-- settings button (gear), left of the close button
local settingsBtn = CreateFrame("Button", "MobLootSettingsButton", f)
settingsBtn:SetSize(20, 20)
settingsBtn:SetPoint("TOPRIGHT", -38, -12)
settingsBtn:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
settingsBtn:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
settingsBtn:SetPushedTexture("Interface\\Icons\\Trade_Engineering")
settingsBtn:GetPushedTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
settingsBtn:GetPushedTexture():SetVertexColor(0.6, 0.6, 0.6)
settingsBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
settingsBtn:GetHighlightTexture():SetBlendMode("ADD")
settingsBtn:SetScript("OnClick", function() ns.OpenSettings() end)
settingsBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Settings", 1, 1, 1)
    GameTooltip:Show()
end)
settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- tabs
local function MakeTab(text, x, w, key)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, -34); b:SetText(text)
    b:SetScript("OnClick", function() ns.SetTab(key) end)
    return b
end
local tabMobs    = MakeTab("Creatures", 18, 78, "mobs")
local tabItems   = MakeTab("Items", 98, 58, "items")
local tabRecipes = MakeTab("Recipes", 158, 68, "recipes")
local TABBTN = { mobs = tabMobs, items = tabItems, recipes = tabRecipes }

-- search box
local search = CreateFrame("EditBox", "MobLootSearch", f, "InputBoxTemplate")
search:SetSize(170, 20)
search:SetPoint("TOPRIGHT", -46, -35)   -- stays pinned next to the close button
search:SetAutoFocus(false)
search:SetMaxLetters(40)
local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
hint:SetPoint("LEFT", 2, 0)
hint:SetText("name or ID...")

search:SetScript("OnTextChanged", function(self, user)
    if self:GetText() == "" then hint:Show() else hint:Hide() end
    if user then S.searchTimer = 0.25 end
end)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); S.searchTimer = 0.01 end)

-- header
local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
backBtn:SetSize(60, 22); backBtn:SetPoint("TOPLEFT", 18, -64); backBtn:SetText("< Back")
backBtn:SetScript("OnClick", function() ns.Back() end)

local hBtn = CreateFrame("Button", nil, f)
hBtn:SetSize(340, 18)
local hTitle = hBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hTitle:SetPoint("LEFT", 0, 0); hTitle:SetWidth(340); hTitle:SetHeight(18); hTitle:SetJustifyH("LEFT")
hBtn:SetScript("OnEnter", function(self)
    if S.view.mode == "item" or S.view.mode == "recipe" then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink((S.view.mode == "item" and "item:" or "spell:") .. S.view.id)
        GameTooltip:Show()
    end
end)
hBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
hBtn:SetScript("OnClick", function()
    if S.view.mode == "item" and IsModifiedClick() then
        local _, link = GetItemInfo(S.view.id)
        if link then HandleModifiedItemClick(link) end
    end
end)

local hSub1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hSub1:SetPoint("TOPLEFT", 20, -88); hSub1:SetWidth(408); hSub1:SetHeight(14); hSub1:SetJustifyH("LEFT")
local hSub2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hSub2:SetPoint("TOPLEFT", 20, -103); hSub2:SetWidth(408); hSub2:SetHeight(28)
hSub2:SetJustifyH("LEFT"); hSub2:SetJustifyV("TOP")


ns.frame = f
ns.ui.frame, ns.ui.tabs, ns.ui.search = f, TABBTN, search
ns.ui.settingsBtn = settingsBtn
ns.ui.backBtn, ns.ui.hBtn, ns.ui.hTitle, ns.ui.hSub1, ns.ui.hSub2 = backBtn, hBtn, hTitle, hSub1, hSub2
