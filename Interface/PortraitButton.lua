local addonName, ns = ...
local S, MobInfo = ns.state, ns.MobInfo

---------------------------------------------------------------- portrait button (like the level badge)
local tb = CreateFrame("Button", "MobLootPortraitButton", TargetFrame)
tb:SetSize(31, 31)
tb:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)
tb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
tb:RegisterForDrag("LeftButton")
tb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local tbBG = tb:CreateTexture(nil, "BACKGROUND")
tbBG:SetSize(20, 20); tbBG:SetPoint("TOPLEFT", 7, -5)
tbBG:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local tbIcon = tb:CreateTexture(nil, "ARTWORK")
tbIcon:SetSize(20, 20); tbIcon:SetPoint("TOPLEFT", 7, -5)
tbIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
tbIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local tbRing = tb:CreateTexture(nil, "OVERLAY")
tbRing:SetSize(53, 53); tbRing:SetPoint("TOPLEFT")
tbRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
tb:Hide()

local function PortraitAnchor() return TargetFramePortrait or TargetFrame end

local function PortraitPos()
    local db = MobLootDB.targetBtn
    local angle = math.rad((db and db.angle) or 45)
    local r = (PortraitAnchor():GetWidth() / 2) + 1
    tb:ClearAllPoints()
    tb:SetPoint("CENTER", PortraitAnchor(), "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- first use: mirror the level badge's position to the other side of the portrait
local function DefaultPortraitAngle()
    local lt = TargetFrameTextureFrameLevelText
    local px, py = PortraitAnchor():GetCenter()
    local lx, ly
    if lt then lx, ly = lt:GetCenter() end
    if px and lx then return -math.deg(math.atan2(ly - py, lx - px)) end
    return 45
end

tb:SetScript("OnDragStart", function(self)
    self.dragging = true
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
        local mx, my = PortraitAnchor():GetCenter()
        local cx, cy = GetCursorPosition()
        local sc = TargetFrame:GetEffectiveScale()   -- the portrait is a texture: no scale of its own
        MobLootDB.targetBtn = MobLootDB.targetBtn or {}
        MobLootDB.targetBtn.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
        PortraitPos()
    end)
end)
tb:SetScript("OnDragStop", function(self)
    self.dragging = nil
    self:SetScript("OnUpdate", nil)
end)
tb:SetScript("OnEnter", function(self)
    if self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("MobLoot Library", 1, 1, 1)
    local name = S.currentNpc and MobInfo(S.currentNpc)
    GameTooltip:AddLine("Left-click: loot table of " .. (name or UnitName("target") or "this creature"), nil, nil, nil, 1)
    GameTooltip:AddLine("Right-click: search the library", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine("Drag: move around the portrait", 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
end)
tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
tb:SetScript("OnClick", function(self, button) ns.LibraryClick(button) end)

local function UpdatePortraitButton()
    local db = MobLootDB.targetBtn
    if S.currentNpc and not (db and db.hide) then
        if db and not db.angle then db.angle = DefaultPortraitAngle() end
        PortraitPos()
        tb:Show()
    else
        tb:Hide()
    end
end

ns.UpdatePortraitButton = UpdatePortraitButton
