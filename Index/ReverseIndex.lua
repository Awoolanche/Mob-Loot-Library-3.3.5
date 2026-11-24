local addonName, ns = ...
local S, Craft = ns.state, ns.Craft

---------------------------------------------------------------- reverse index (item -> sources)
local rev = { drop = {}, vend = {}, obj = {}, bag = {}, quest = {}, made = {}, reag = {}, teach = {},
              done = false, started = false, progress = 0 }

local function AddLoot(tbl, src, s)
    for id, ch in s:gmatch("(%d+):([%d%.]+):%d+:%d+") do
        id = tonumber(id)
        local t = tbl[id]; if not t then t = {}; tbl[id] = t end
        t[#t + 1] = src; t[#t + 1] = tonumber(ch)
    end
end
local function AddList(tbl, src, s)
    for sign, id in s:gmatch("(%-?)(%d+)") do
        id = tonumber(id)
        local t = tbl[id]; if not t then t = {}; tbl[id] = t end
        t[#t + 1] = src; t[#t + 1] = (sign == "-") and 1 or 0
    end
end

local function Push(tbl, key, value)
    local t = tbl[key]; if not t then t = {}; tbl[key] = t end
    t[#t + 1] = value
end
local function AddCraft(r, spell)
    local c = Craft(spell)
    if not c then return end
    if c.item then Push(r.made, c.item, spell) end
    for _, rg in ipairs(c.reagents) do Push(r.reag, rg[1], spell) end
    if c.recipe then Push(r.teach, c.recipe, spell) end
end

local PHASES = {
    { "drop",  function() return MobLoot_Static end,   function(r, k, v) AddLoot(r.drop, k, v) end },
    { "vend",  function() return MobLoot_Vend end,     function(r, k, v) AddList(r.vend, k, v) end },
    { "obj",   function() return MobLoot_ObjLoot end,  function(r, k, v) AddLoot(r.obj, k, v) end },
    { "bag",   function() return MobLoot_BagLoot end,  function(r, k, v) AddLoot(r.bag, k, v) end },
    { "quest", function() return MobLoot_QuestRew end, function(r, k, v) AddList(r.quest, k, v) end },
    { "craft", function() return MobLoot_Craft end,    AddCraft },
}
local build = { phase = 1, key = nil, count = 0, total = 1, t = 0 }
local builder = CreateFrame("Frame")

local function BuildStep(self, elapsed)
    local budget = 800
    while budget > 0 do
        local ph = PHASES[build.phase]
        if not ph then
            rev.done = true; rev.progress = 1
            self:SetScript("OnUpdate", nil)
            if MobLootFrame:IsShown() and S.view.mode == "item" then ns.Refresh() end
            return
        end
        local k, v = next(ph[2](), build.key)
        if k == nil then
            build.phase = build.phase + 1; build.key = nil
        else
            build.key = k
            ph[3](rev, k, v)
            build.count = build.count + 1
            budget = budget - 1
        end
    end
    rev.progress = build.count / build.total
    build.t = build.t + elapsed
    if build.t > 0.3 then
        build.t = 0
        if MobLootFrame:IsShown() and S.view.mode == "item" then ns.Refresh() end
    end
end

local function StartIndexBuild()
    if rev.started then return end
    rev.started = true
    local total = 0
    for _, ph in ipairs(PHASES) do for _ in pairs(ph[2]()) do total = total + 1 end end
    build.total = math.max(total, 1)
    builder:SetScript("OnUpdate", BuildStep)
end

ns.rev = rev
ns.StartIndexBuild = StartIndexBuild
