local addonName, ns = ...
local sort, strlower, strfind = table.sort, string.lower, string.find
local Craft, RecipeLabel, ItemQN, PROF = ns.Craft, ns.RecipeLabel, ns.ItemQN, ns.PROF

---------------------------------------------------------------- search index
local sindex            -- { mobs = {ids, ln}, items = {ids, ln} }

local function BuildSearchIndex()
    sindex = { mobs = { ids = {}, ln = {} }, items = { ids = {}, ln = {} }, recipes = { ids = {}, ln = {} } }
    local ids, ln, n = sindex.mobs.ids, sindex.mobs.ln, 0
    for id, s in pairs(MobLoot_Mobs) do
        n = n + 1; ids[n] = id; ln[n] = strlower(s:match("^([^|]*)") or "")
    end
    if MobLootDB.mobs then
        for id, m in pairs(MobLootDB.mobs) do
            if not MobLoot_Mobs[id] and m.name then
                n = n + 1; ids[n] = id; ln[n] = strlower(m.name)
            end
        end
    end
    ids, ln, n = sindex.items.ids, sindex.items.ln, 0
    for id, s in pairs(MobLoot_ItemInfo) do
        n = n + 1; ids[n] = id; ln[n] = strlower(s:match("^%d|(.*)$") or "")
    end
    ids, ln, n = sindex.recipes.ids, sindex.recipes.ln, 0
    for sp in pairs(MobLoot_Craft) do
        local c = Craft(sp)
        if c then
            local _, plain = RecipeLabel(c)
            if plain then
                local extra = ""
                if c.item and c.prof == "D" then extra = " " .. (select(2, ItemQN(c.item)) or "") end
                n = n + 1; ids[n] = sp
                ln[n] = strlower(plain .. " " .. (PROF[c.prof] or "") .. extra)
            end
        end
    end
end

local function RunSearch(tab, query)
    if not sindex then BuildSearchIndex() end
    local q = strlower(strtrim(query or ""))
    local words = {}
    for w in q:gmatch("%S+") do words[#words + 1] = w end
    if #q < 2 then return {}, 0 end
    local src = sindex[tab] or sindex.mobs
    local ids, ln = src.ids, src.ln
    local hits, nh = {}, 0
    for i = 1, #ids do
        local l, ok = ln[i], true
        for j = 1, #words do
            if not strfind(l, words[j], 1, true) then ok = false; break end
        end
        if ok then nh = nh + 1; hits[nh] = i end
    end
    local w1 = words[1]
    sort(hits, function(a, b)
        local pa, pb = strfind(ln[a], w1, 1, true) == 1, strfind(ln[b], w1, 1, true) == 1
        if pa ~= pb then return pa end
        if ln[a] ~= ln[b] then return ln[a] < ln[b] end
        return ids[a] < ids[b]
    end)
    local out = {}
    for i = 1, math.min(nh, 300) do out[i] = ids[hits[i]] end
    return out, nh
end

-- "12345", "#12345" or "id:12345" -> number (nil when the text is not an id)
local function ParseId(query)
    local q = strtrim(query or "")
    local n = q:match("^#?(%d+)$") or q:match("^[iI][dD]%s*[:=]?%s*(%d+)$")
    return n and tonumber(n) or nil
end

-- does this id exist on the current tab (npc / item / spell id), and is it a known quest id?
local function IdLookup(tab, id)
    local tabHit
    if tab == "mobs" then tabHit = ns.MobInfo(id) ~= nil
    elseif tab == "recipes" then tabHit = ns.Craft(id) ~= nil
    else tabHit = id > 0 end                -- any item id: unknown ones still open (tooltip asks the server)
    return tabHit, MobLoot_Quests[id] ~= nil
end

ns.RunSearch, ns.ParseId, ns.IdLookup = RunSearch, ParseId, IdLookup
ns.EnsureSearchIndex = function() if not sindex then BuildSearchIndex() end end
ns.ResetSearchIndex = function() sindex = nil end   -- rebuilt on next search (after clearing learned data)
