local addonName, ns = ...
local S, f = ns.state, ns.frame
local GetNpcId = ns.GetNpcId

local function Note(npc, unit)
    local m = MobLootDB.mobs[npc]
    if not m then m = { name = UnitName(unit), zones = {} }; MobLootDB.mobs[npc] = m end
    local lvl = UnitLevel(unit)
    if lvl and lvl > 0 then
        m.lmin = math.min(m.lmin or lvl, lvl); m.lmax = math.max(m.lmax or lvl, lvl)
    else
        m.boss = true
    end
    local z, sz = GetRealZoneText(), GetSubZoneText()
    local key = (z and z ~= "") and ((sz and sz ~= "") and (z .. " - " .. sz) or z) or nil
    if key then
        local n = 0
        for _ in pairs(m.zones) do n = n + 1 end
        if m.zones[key] or n < 8 then m.zones[key] = true end
    end
end

local counted = {}
local function LootUnit()
    for _, u in ipairs({ "target", "mouseover" }) do
        if UnitExists(u) and UnitIsDead(u) and not UnitIsPlayer(u) and GetNpcId(u) then return u end
    end
end

-- LOOT_OPENED: remember the kill and what dropped
function ns.OnLootOpened()
    if IsFishingLoot and IsFishingLoot() then return end
    local unit = LootUnit()
    if not unit then return end
    local guid = UnitGUID(unit)
    if counted[guid] then return end          -- skinning / second open
    counted[guid] = true
    local npc = GetNpcId(unit)
    Note(npc, unit)
    local rec = MobLootDB.learned[npc]
    if not rec then rec = { kills = 0, items = {} }; MobLootDB.learned[npc] = rec end
    rec.kills = rec.kills + 1
    for slot = 1, GetNumLootItems() do
        if LootSlotIsItem(slot) then
            local link = GetLootSlotLink(slot)
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then rec.items[id] = (rec.items[id] or 0) + 1 end
        end
    end
    if f:IsShown() and S.view.mode == "mob" and S.view.id == npc then ns.Refresh() end
end

-- PLAYER_TARGET_CHANGED: track the target and keep a followed view in sync
function ns.OnTargetChanged()
    local id = UnitExists("target") and not UnitIsPlayer("target") and GetNpcId("target") or nil
    S.currentNpc = id
    ns.UpdatePortraitButton()
    if id then
        if not UnitPlayerControlled("target") then Note(id, "target") end
        if f:IsShown() and S.view.follow then
            S.view = { mode = "mob", id = id, follow = true, tab = S.curTab }
            S.stack = {}
            ns.Refresh(true)
        end
    end
end
