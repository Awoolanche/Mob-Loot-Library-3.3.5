local addonName, ns = ...
local C, f = ns.C, ns.frame
local floor = math.floor
local WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H = C.WIN_MIN_W, C.WIN_MIN_H, C.WIN_MAX_W, C.WIN_MAX_H

local grip = CreateFrame("Button", nil, f)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -7, 7)
grip:SetFrameLevel(f:GetFrameLevel() + 20)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
-- manual resizing (the built-in StartSizing re-anchors the window and throws it around
-- on scaled frames): the top-left corner stays fixed, the size follows the cursor delta
local function StopGrip(self)
    if not self.sizing then return end
    self.sizing = nil
    self:SetScript("OnUpdate", nil)
    MobLootDB.winSize = { w = floor(f:GetWidth() + 0.5), h = floor(f:GetHeight() + 0.5) }
    ns.SavePos()
end
grip:SetScript("OnMouseDown", function(self, btn)
    if btn ~= "LeftButton" then return end
    ns.SavePos()                                   -- pin the window by its top-left corner
    local cx, cy = GetCursorPosition()
    self.sizing = { cx = cx, cy = cy, w = f:GetWidth(), h = f:GetHeight() }
    self:SetScript("OnUpdate", function(self)
        local st = self.sizing
        if not st then return end
        local es = f:GetEffectiveScale()
        local x, y = GetCursorPosition()
        local sc = f:GetScale()
        local maxW = math.min(WIN_MAX_W, UIParent:GetWidth() / sc)
        local maxH = math.min(WIN_MAX_H, UIParent:GetHeight() / sc)
        local nw = st.w + (x - st.cx) / es
        local nh = st.h - (y - st.cy) / es
        nw = math.max(WIN_MIN_W, math.min(maxW, nw))
        nh = math.max(WIN_MIN_H, math.min(maxH, nh))
        f:SetSize(nw, nh)
    end)
end)
grip:SetScript("OnMouseUp", StopGrip)
grip:SetScript("OnHide", StopGrip)
grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Drag to resize", 1, 1, 1)
    GameTooltip:Show()
end)
grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

ns.ui.grip = grip
