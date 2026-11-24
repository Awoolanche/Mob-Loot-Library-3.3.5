local addonName, ns = ...
local S, MobInfo = ns.state, ns.MobInfo

---------------------------------------------------------------- minimap button
local mb = CreateFrame("Button", "MobLootMinimapButton", Minimap)
mb:SetSize(31, 31)
mb:SetFrameStrata("MEDIUM")
mb:SetFrameLevel(8)
mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mb:RegisterForDrag("LeftButton")
mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mbBG = mb:CreateTexture(nil, "BACKGROUND")
mbBG:SetSize(20, 20); mbBG:SetPoint("TOPLEFT", 7, -5)
mbBG:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local mbIcon = mb:CreateTexture(nil, "ARTWORK")
mbIcon:SetSize(20, 20); mbIcon:SetPoint("TOPLEFT", 7, -5)
mbIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
mbIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local mbRing = mb:CreateTexture(nil, "OVERLAY")
mbRing:SetSize(53, 53); mbRing:SetPoint("TOPLEFT")
mbRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function MinimapPos()
    local db = MobLootDB.minimap
    local angle = math.rad((db and db.angle) or 215)
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then   -- square minimaps
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    local r = (Minimap:GetWidth() / 2) + 10
    mb:ClearAllPoints()
    mb:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

mb:SetScript("OnDragStart", function(self)
    self.dragging = true
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local sc = Minimap:GetEffectiveScale()
        MobLootDB.minimap = MobLootDB.minimap or {}
        MobLootDB.minimap.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
        MinimapPos()
    end)
end)
mb:SetScript("OnDragStop", function(self)
    self.dragging = nil
    self:SetScript("OnUpdate", nil)
end)

mb:SetScript("OnEnter", function(self)
    if self.dragging then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("MobLoot Library", 1, 1, 1)
    if S.currentNpc then
        local name = MobInfo(S.currentNpc)
        GameTooltip:AddLine("Left-click: loot table of " .. (name or UnitName("target") or "your target"), nil, nil, nil, 1)
        GameTooltip:AddLine("Right-click: search the library", 0.8, 0.8, 0.8, 1)
    else
        GameTooltip:AddLine("Click: search creatures and items", nil, nil, nil, 1)
        GameTooltip:AddLine("Target a creature to see its loot table.", 0.8, 0.8, 0.8, 1)
    end
    GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
mb:SetScript("OnClick", function(self, button) ns.LibraryClick(button) end)

MinimapPos()

ns.mb, ns.MinimapPos = mb, MinimapPos
