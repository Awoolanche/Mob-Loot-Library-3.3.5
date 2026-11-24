local addonName, ns = ...
local C, f = ns.C, ns.frame
local floor = math.floor
local SCALE_MIN, SCALE_MAX = C.SCALE_MIN, C.SCALE_MAX

---------------------------------------------------------------- scale / position / options
local DEF_X, DEF_Y = 200, 0                 -- default: CENTER of the screen, +200 right

-- the position is stored as the window's top-left corner in screen pixels,
-- so it stays put when the scale changes
local function SavePos()
    local l, t = f:GetLeft(), f:GetTop()
    if not l or not t then return end
    local sc = f:GetScale()
    MobLootDB.posTL = { x = l * sc, y = t * sc }
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)   -- same spot, fixed top-left anchor
end

local function ApplyPos()
    local sc = f:GetScale()
    local pos = MobLootDB.posTL
    f:ClearAllPoints()
    if pos and pos.x and pos.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / sc, pos.y / sc)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", DEF_X / sc, DEF_Y / sc)
    end
end

local function SetWindowScale(v)
    v = math.max(SCALE_MIN, math.min(SCALE_MAX, floor(v * 20 + 0.5) / 20))
    if f:GetLeft() then SavePos() end      -- remember where it is before scaling
    f:SetScale(v)
    MobLootDB.scale = v
    ApplyPos()
    return v
end

local function ResetScale()
    SetWindowScale(1)
end

local function ResetPosition()
    MobLootDB.posTL = nil
    ApplyPos()
end

local function ResetSize()
    MobLootDB.winSize = nil
    f:SetSize(C.DEF_W, C.DEF_H)
    if f:GetLeft() then SavePos() end
end

ns.SavePos, ns.ApplyPos, ns.SetWindowScale = SavePos, ApplyPos, SetWindowScale
ns.ResetScale, ns.ResetPosition, ns.ResetSize = ResetScale, ResetPosition, ResetSize
