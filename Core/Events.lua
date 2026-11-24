local addonName, ns = ...
local C, f = ns.C, ns.frame
local WIN_MIN_W, WIN_MIN_H, WIN_MAX_W, WIN_MAX_H = C.WIN_MIN_W, C.WIN_MIN_H, C.WIN_MAX_W, C.WIN_MAX_H
local SCALE_MIN, SCALE_MAX = C.SCALE_MIN, C.SCALE_MAX

-- saved variables are available now: fill defaults and restore window / button state
local function OnAddonLoaded()
    MobLootDB.learned = MobLootDB.learned or {}
    MobLootDB.mobs = MobLootDB.mobs or {}
    MobLootDB.minimap = MobLootDB.minimap or { angle = 215 }
    MobLootDB.targetBtn = MobLootDB.targetBtn or {}
    local ws = MobLootDB.winSize
    if ws and ws.w and ws.h then
        f:SetSize(math.max(WIN_MIN_W, math.min(WIN_MAX_W, ws.w)), math.max(WIN_MIN_H, math.min(WIN_MAX_H, ws.h)))
    end
    ns.Relayout()
    if MobLootDB.scale then f:SetScale(math.max(SCALE_MIN, math.min(SCALE_MAX, MobLootDB.scale))) end
    MobLootDB.pos = nil   -- old bottom-left format, no longer used
    ns.ApplyPos()
    ns.MinimapPos()
    if MobLootDB.minimap.hide then ns.mb:Hide() else ns.mb:Show() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("LOOT_OPENED")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then OnAddonLoaded() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.OnTargetChanged()
    elseif event == "LOOT_OPENED" then
        ns.OnLootOpened()
    end
end)
