----------------------------------------------------------------------
-- MobLoot Library (WoW 3.3.5a)
--   * minimap button (drag to move) -> loot table of your target / library
--   * /mobloot -> searchable library of creatures and items
--       creature -> location + everything it drops / sells
--       item     -> every creature, vendor, quest, chest/node, container and
--                   crafting recipe that gives it / uses it
--       recipe   -> reagents, what it makes, who teaches it
-- Data: MobLootData.lua / MobLootInfo.lua (generated) + what you see/loot.
----------------------------------------------------------------------
local ROWS, ROW_H = 10, 32
local floor, sort, concat = math.floor, table.sort, table.concat
local strfind, strlower, format = string.find, string.lower, string.format

MobLoot_Static   = MobLoot_Static   or {}   -- [npc]   = "item:chance:min:max,..."
MobLoot_Mobs     = MobLoot_Mobs     or {}   -- [npc]   = "name|minLvl|maxLvl|rank|area"
MobLoot_ItemInfo = MobLoot_ItemInfo or {}   -- [item]  = "quality|name"
MobLoot_Vend     = MobLoot_Vend     or {}   -- [npc]   = "item,item,..."
MobLoot_Objs     = MobLoot_Objs     or {}   -- [obj]   = "name|area"
MobLoot_ObjLoot  = MobLoot_ObjLoot  or {}   -- [obj]   = "item:chance:min:max,..."
MobLoot_BagLoot  = MobLoot_BagLoot  or {}   -- [item]  = "item:chance:min:max,..."
MobLoot_Quests   = MobLoot_Quests   or {}   -- [quest] = "level|title"
MobLoot_QuestRew = MobLoot_QuestRew or {}   -- [quest] = "item,-choiceItem,..."
MobLoot_Craft    = MobLoot_Craft    or {}   -- [spell]  = "prof|skill|item|yield|recipeItem|id:n id:n"
MobLoot_Trainers = MobLoot_Trainers or {}   -- [spell]  = "npc,npc,..."
MobLootDB = MobLootDB or {}

local RANK = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }
local ICON_MOB   = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local ICON_BOSS  = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
local ICON_QUEST = "Interface\\Icons\\INV_Misc_Note_01"
local ICON_OBJ   = "Interface\\Icons\\INV_Box_01"
local ICON_UNK   = "Interface\\Icons\\INV_Misc_QuestionMark"

local Refresh, Navigate, Back, SetTab     -- forward declarations
local view = { mode = "search", tab = "mobs", query = "" }
local stack = {}
local rowsData = {}
local curTab = "mobs"
local currentNpc

---------------------------------------------------------------- helpers
local function GetNpcId(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local hi = tonumber(guid:sub(3, 5), 16)
    if hi == 0xF13 or hi == 0xF15 then        -- creature / vehicle
        return tonumber(guid:sub(-12, -7), 16)
    end
end

local function MobInfo(id)
    local s = MobLoot_Mobs[id]
    if s then
        local name, mn, mx, rank, area = s:match("^([^|]*)|(%-?%d+)|(%-?%d+)|(%d+)|(.*)$")
        if name then return name, tonumber(mn), tonumber(mx), tonumber(rank), area end
    end
    local m = MobLootDB.mobs and MobLootDB.mobs[id]
    if m then return m.name, m.lmin, m.lmax, m.boss and 3 or 0, "" end
end

local function LearnedZones(id)
    local m = MobLootDB.mobs and MobLootDB.mobs[id]
    local out = {}
    if m and m.zones then for z in pairs(m.zones) do out[#out + 1] = z end end
    sort(out)
    return out
end

local function LevelText(mn, mx)
    if not mn or mn <= 0 or mn >= 83 or (mx and mx >= 83) then return "Lv ??" end
    if mx and mx ~= mn then return "Lv " .. mn .. "-" .. mx end
    return "Lv " .. mn
end

local function ItemQN(id)
    local n, _, q = GetItemInfo(id)
    if n then return q, n end
    local s = MobLoot_ItemInfo[id]
    if s then
        local qq, nn = s:match("^(%d)|(.*)$")
        if qq then return tonumber(qq), nn end
    end
end

local function ColorName(id)
    local q, n = ItemQN(id)
    local c = ITEM_QUALITY_COLORS[q or 1]
    return (c and c.hex or "|cffffffff") .. (n or ("Item #" .. id)) .. "|r"
end

local PROF = { A = "Alchemy", B = "Blacksmithing", D = "Enchanting", E = "Engineering",
               I = "Inscription", J = "Jewelcrafting", L = "Leatherworking", T = "Tailoring",
               W = "Cooking", X = "First Aid", Y = "Smelting" }
local craftCache = {}

local function Craft(spell)
    local c = craftCache[spell]
    if c ~= nil then return c or nil end
    local s = MobLoot_Craft[spell]
    local prof, skill, item, yield, recipe, reag
    if s then prof, skill, item, yield, recipe, reag = s:match("^(%a)|(%d+)|(%d*)|(%d*)|(%d*)|(.*)$") end
    if not prof then craftCache[spell] = false; return nil end
    item, recipe = tonumber(item), tonumber(recipe)
    c = { spell = spell, prof = prof, skill = tonumber(skill),
          item = (item and item > 0) and item or nil, yield = tonumber(yield) or 1,
          recipe = (recipe and recipe > 0) and recipe or nil, reagents = {} }
    for id, n in reag:gmatch("(%d+):(%d+)") do c.reagents[#c.reagents + 1] = { tonumber(id), tonumber(n) } end
    craftCache[spell] = c
    return c
end

-- returns coloured label, plain name, icon path (for recipes without an item)
local function RecipeLabel(c)
    if c.prof == "D" or not c.item then
        local n, _, icon = GetSpellInfo(c.spell)
        if n then return "|cffffd100" .. n .. "|r", n, icon end
    end
    if c.item then
        local q, n = ItemQN(c.item)
        local col = ITEM_QUALITY_COLORS[q or 1]
        n = n or ("Item #" .. c.item)
        return (col and col.hex or "|cffffffff") .. n .. "|r", n, nil
    end
end

local function ChanceText(c)
    if not c then return "" end
    if c < 0.1 then return "<0.1%" end
    if c >= 10 then return format("%.0f%%", c) end
    return format("%.1f%%", c)
end

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
            if MobLootFrame:IsShown() and view.mode == "item" then Refresh() end
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
        if MobLootFrame:IsShown() and view.mode == "item" then Refresh() end
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

---------------------------------------------------------------- loot of a creature
local function BuildDrops(npcId)
    local list, seen = {}, {}
    local s = MobLoot_Static[npcId]
    if s then
        for id, chance, mn, mx in s:gmatch("(%d+):([%d%.]+):(%d+):(%d+)") do
            id = tonumber(id)
            list[#list + 1] = { id = id, chance = tonumber(chance), min = tonumber(mn), max = tonumber(mx) }
            seen[id] = true
        end
    end
    local l = MobLootDB.learned and MobLootDB.learned[npcId]
    if l then
        for id, cnt in pairs(l.items) do
            if not seen[id] then
                list[#list + 1] = { id = id, learned = true, count = cnt, kills = l.kills,
                                    chance = l.kills > 0 and (cnt * 100 / l.kills) or 0 }
            end
        end
    end
    sort(list, function(a, b)
        if a.learned ~= b.learned then return not a.learned end
        if a.chance ~= b.chance then return a.chance > b.chance end
        return a.id < b.id
    end)
    return list
end

---------------------------------------------------------------- row builders
local function MobRow(id, right)
    local name, mn, mx, rank, area = MobInfo(id)
    name = name or ("NPC " .. id)
    local col = (rank and rank >= 1) and "|cffffd100" or "|cffffffff"
    local where = (area and area ~= "") and area or "location unknown"
    local zones = LearnedZones(id)
    return {
        icon = (rank == 3) and ICON_BOSS or ICON_MOB,
        t1 = col .. name .. "|r",
        t2 = LevelText(mn, mx) .. "  -  " .. where,
        r = right or (RANK[rank] or ""),
        go = { mode = "mob", id = id },
        tip = { name, LevelText(mn, mx) .. (RANK[rank] and (" " .. RANK[rank]) or ""),
                "Location (approx.): " .. where,
                (#zones > 0) and ("Seen in: " .. concat(zones, ", ")) or nil },
    }
end

local function RecipeRow(spell, right)
    local c = Craft(spell)
    if not c then return nil end
    local label, plain, icon = RecipeLabel(c)
    if not label then return nil end
    local t2 = format("%s - skill %d", PROF[c.prof] or "?", c.skill)
    if c.yield and c.yield > 1 then t2 = t2 .. format(" - makes %d", c.yield) end
    return { item = c.item, icon = icon, spell = (not c.item or c.prof == "D") and spell or nil,
             t1 = label, t2 = t2, r = right or "", go = { mode = "recipe", id = spell } }
end

local function SortSpells(list)
    sort(list, function(a, b)
        local ca, cb = Craft(a), Craft(b)
        if ca.prof ~= cb.prof then return (PROF[ca.prof] or "") < (PROF[cb.prof] or "") end
        if ca.skill ~= cb.skill then return ca.skill < cb.skill end
        return a < b
    end)
end

local function MobRows(id)
    local rows = {}
    local drops = BuildDrops(id)
    if #drops > 0 then
        rows[#rows + 1] = { header = format("Drops (%d)", #drops) }
        for _, e in ipairs(drops) do
            local t2 = ""
            if e.max and e.max > 1 then t2 = "Quantity: " .. (e.min == e.max and e.max or (e.min .. "-" .. e.max)) end
            local r = e.learned and format("~%.0f%%", e.chance) or ChanceText(e.chance)
            if e.learned then t2 = format("Seen %d of %d kills", e.count, e.kills) end
            rows[#rows + 1] = { item = e.id, t1 = ColorName(e.id), t2 = t2, r = r, go = { mode = "item", id = e.id } }
        end
    end
    local v = MobLoot_Vend[id]
    if v then
        local n = 0
        local items = {}
        for sid in v:gmatch("%d+") do items[#items + 1] = tonumber(sid) end
        rows[#rows + 1] = { header = format("Sells (%d)", #items) }
        for _, iid in ipairs(items) do
            rows[#rows + 1] = { item = iid, t1 = ColorName(iid), t2 = "Vendor item", go = { mode = "item", id = iid } }
        end
    end
    if #rows == 0 then
        rows[1] = { header = "No loot data for this creature yet." }
        rows[2] = { header = "|cff999999Loot it once and it will be recorded.|r" }
    end
    return rows
end

local function ItemRows(id)
    local rows = {}
    if not rev.done then
        rows[1] = { header = format("Building source index... %d%%", floor(rev.progress * 100)) }
        return rows
    end
    local function header(title, n) rows[#rows + 1] = { header = format("%s (%d)", title, n) } end

    local function recipeSection(title, list)
        if not list then return end
        local spells, seen, tmp = {}, {}, {}
        for _, sp in ipairs(list) do
            if not seen[sp] and Craft(sp) then seen[sp] = true; spells[#spells + 1] = sp end
        end
        SortSpells(spells)
        for _, sp in ipairs(spells) do
            local row = RecipeRow(sp)
            if row then tmp[#tmp + 1] = row end
        end
        if #tmp == 0 then return end
        header(title, #tmp)
        for _, row in ipairs(tmp) do rows[#rows + 1] = row end
    end

    recipeSection("Teaches recipe", rev.teach[id])
    recipeSection("Crafted by", rev.made[id])

    -- vendors
    local v = rev.vend[id]
    if v then
        local list = {}
        for i = 1, #v, 2 do list[#list + 1] = v[i] end
        sort(list, function(a, b)
            local na, nb = MobInfo(a) or "", MobInfo(b) or ""
            if na ~= nb then return na < nb end
            return a < b
        end)
        header("Sold by", #list)
        for _, npc in ipairs(list) do rows[#rows + 1] = MobRow(npc, "Vendor") end
    end

    -- quests
    local q = rev.quest[id]
    if q then
        header("Quest rewards", #q / 2)
        for i = 1, #q, 2 do
            local lvl, title = (MobLoot_Quests[q[i]] or ""):match("^(%-?%d+)|(.*)$")
            rows[#rows + 1] = {
                icon = ICON_QUEST, t1 = "|cffffff00" .. (title or ("Quest #" .. q[i])) .. "|r",
                t2 = (lvl and ("Level " .. lvl .. " - ") or "") .. (q[i + 1] == 1 and "reward choice" or "guaranteed reward"),
                tip = { title or "Quest", "Quest ID " .. q[i] },
            }
        end
    end

    -- chests / nodes
    local o = rev.obj[id]
    if o then
        header("Found in chests / nodes", #o / 2)
        for i = 1, #o, 2 do
            local name, area = (MobLoot_Objs[o[i]] or ""):match("^([^|]*)|(.*)$")
            rows[#rows + 1] = {
                icon = ICON_OBJ, t1 = "|cff99ccff" .. (name or ("Object #" .. o[i])) .. "|r",
                t2 = (area and area ~= "") and area or "location unknown", r = ChanceText(o[i + 1]),
                tip = { name or "Object", (area and area ~= "") and ("Location (approx.): " .. area) or nil },
            }
        end
    end

    -- containers
    local b = rev.bag[id]
    if b then
        header("Contained in", #b / 2)
        for i = 1, #b, 2 do
            rows[#rows + 1] = { item = b[i], t1 = ColorName(b[i]), t2 = "Container / lockbox",
                                r = ChanceText(b[i + 1]), go = { mode = "item", id = b[i] } }
        end
    end

    -- creature drops (database + what you have looted yourself)
    local list, have = {}, {}
    local d = rev.drop[id]
    if d then
        for i = 1, #d, 2 do list[#list + 1] = { npc = d[i], chance = d[i + 1] }; have[d[i]] = true end
    end
    if MobLootDB.learned then
        for npc, rec in pairs(MobLootDB.learned) do
            local cnt = rec.items[id]
            if cnt and not have[npc] and rec.kills > 0 then
                list[#list + 1] = { npc = npc, chance = cnt * 100 / rec.kills, learned = true }
            end
        end
    end
    if #list > 0 then
        sort(list, function(a, b)
            if a.chance ~= b.chance then return a.chance > b.chance end
            return a.npc < b.npc
        end)
        header("Dropped by", #list)
        for _, e in ipairs(list) do
            local row = MobRow(e.npc, e.learned and format("~%.0f%%", e.chance) or ChanceText(e.chance))
            rows[#rows + 1] = row
        end
    end

    recipeSection("Used as reagent in", rev.reag[id])

    if #rows == 0 then
        rows[1] = { header = "No known source for this item." }
        rows[2] = { header = "|cff999999It may be crafted, a raid/PvP reward or not in the database.|r" }
    end
    return rows
end

local function RecipeRows(spell)
    local rows = {}
    local c = Craft(spell)
    if not c then rows[1] = { header = "Unknown recipe." }; return rows end
    if c.item then
        rows[#rows + 1] = { header = "Creates" }
        rows[#rows + 1] = { item = c.item, t1 = ColorName(c.item),
                            t2 = (c.yield > 1) and ("Makes " .. c.yield) or "", go = { mode = "item", id = c.item } }
    end
    rows[#rows + 1] = { header = format("Reagents (%d)", #c.reagents) }
    for _, rg in ipairs(c.reagents) do
        rows[#rows + 1] = { item = rg[1], t1 = ColorName(rg[1]), r = "x" .. rg[2], go = { mode = "item", id = rg[1] } }
    end
    local known = false
    if c.recipe then
        known = true
        rows[#rows + 1] = { header = "Recipe item" }
        rows[#rows + 1] = { item = c.recipe, t1 = ColorName(c.recipe),
                            t2 = "Click to see who sells or drops it", go = { mode = "item", id = c.recipe } }
    end
    local tr = MobLoot_Trainers[spell]
    if tr then
        local ids = {}
        for sid in tr:gmatch("%d+") do ids[#ids + 1] = tonumber(sid) end
        if #ids > 0 then
            known = true
            rows[#rows + 1] = { header = format("Taught by trainers (%d)", #ids) }
            for _, npc in ipairs(ids) do rows[#rows + 1] = MobRow(npc, "Trainer") end
        end
    end
    if not known then
        rows[#rows + 1] = { header = "How to learn" }
        rows[#rows + 1] = { header = "|cff999999No trainer or recipe item known for it." }
        rows[#rows + 1] = { header = "|cff999999(starter recipe, quest reward, discovery...)" }
    end
    return rows
end

---------------------------------------------------------------- window
local f = CreateFrame("Frame", "MobLootFrame", UIParent)
f:SetSize(450, 470)
f:SetPoint("CENTER", 200, 0)
f:SetFrameStrata("DIALOG")
f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
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

-- tabs
local function MakeTab(text, x, w, key)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetPoint("TOPLEFT", x, -34); b:SetText(text)
    b:SetScript("OnClick", function() SetTab(key) end)
    return b
end
local tabMobs    = MakeTab("Creatures", 18, 78, "mobs")
local tabItems   = MakeTab("Items", 98, 58, "items")
local tabRecipes = MakeTab("Recipes", 158, 68, "recipes")
local TABBTN = { mobs = tabMobs, items = tabItems, recipes = tabRecipes }

-- search box
local search = CreateFrame("EditBox", "MobLootSearch", f, "InputBoxTemplate")
search:SetSize(166, 20)
search:SetPoint("TOPLEFT", 238, -35)
search:SetAutoFocus(false)
search:SetMaxLetters(40)
local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
hint:SetPoint("LEFT", 2, 0)
hint:SetText("search by name...")
local searchTimer

search:SetScript("OnTextChanged", function(self, user)
    if self:GetText() == "" then hint:Show() else hint:Hide() end
    if user then searchTimer = 0.25 end
end)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); searchTimer = 0.01 end)

-- header
local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
backBtn:SetSize(60, 22); backBtn:SetPoint("TOPLEFT", 18, -64); backBtn:SetText("< Back")
backBtn:SetScript("OnClick", function() Back() end)

local hBtn = CreateFrame("Button", nil, f)
hBtn:SetSize(340, 18)
local hTitle = hBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hTitle:SetPoint("LEFT", 0, 0); hTitle:SetWidth(340); hTitle:SetHeight(18); hTitle:SetJustifyH("LEFT")
hBtn:SetScript("OnEnter", function(self)
    if view.mode == "item" or view.mode == "recipe" then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink((view.mode == "item" and "item:" or "spell:") .. view.id)
        GameTooltip:Show()
    end
end)
hBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
hBtn:SetScript("OnClick", function()
    if view.mode == "item" and IsModifiedClick() then
        local _, link = GetItemInfo(view.id)
        if link then HandleModifiedItemClick(link) end
    end
end)

local hSub1 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hSub1:SetPoint("TOPLEFT", 20, -88); hSub1:SetWidth(408); hSub1:SetHeight(14); hSub1:SetJustifyH("LEFT")
local hSub2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hSub2:SetPoint("TOPLEFT", 20, -103); hSub2:SetWidth(408); hSub2:SetHeight(28)
hSub2:SetJustifyH("LEFT"); hSub2:SetJustifyV("TOP")

-- list
local scroll = CreateFrame("ScrollFrame", "MobLootScroll", f, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -134)
scroll:SetPoint("BOTTOMRIGHT", -36, 16)

local rows = {}
local retry, retryTimer = 0, nil

local scanTip = CreateFrame("GameTooltip", "MobLootScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function UpdateRows()
    local n = #rowsData
    FauxScrollFrame_Update(scroll, n, ROWS, ROW_H)
    local offset = FauxScrollFrame_GetOffset(scroll)
    local missing = false
    for i = 1, ROWS do
        local row, d = rows[i], rowsData[i + offset]
        if d then
            row.d = d
            if d.header then
                row.icon:Hide()
                row.t1:SetText("|cffffd100" .. d.header .. "|r")
                row.t2:SetText(""); row.r:SetText("")
            else
                if d.item then
                    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(d.item)
                    if tex then
                        row.icon:SetTexture(tex)
                    else
                        missing = true
                        scanTip:SetHyperlink("item:" .. d.item)   -- ask the server
                        row.icon:SetTexture(ICON_UNK)
                    end
                else
                    row.icon:SetTexture(d.icon or ICON_UNK)
                end
                row.icon:Show()
                row.t1:SetText(d.t1 or "")
                row.t2:SetText(d.t2 or "")
                row.r:SetText(d.r or "")
            end
            row:Show()
        else
            row.d = nil
            row:Hide()
        end
    end
    if missing and retry < 8 then retry = retry + 1; retryTimer = 0.5 end
end

local function MakeRow(i)
    local row = CreateFrame("Button", nil, f)
    row:SetSize(394, ROW_H - 2)
    row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.hl:SetBlendMode("ADD")
    row.hl:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 2, 0)
    row.t1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.t1:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.t1:SetWidth(250); row.t1:SetHeight(13); row.t1:SetJustifyH("LEFT")
    row.t2 = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.t2:SetPoint("TOPLEFT", row.t1, "BOTTOMLEFT", 0, -1)
    row.t2:SetWidth(335); row.t2:SetHeight(11); row.t2:SetJustifyH("LEFT")
    row.r = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.r:SetPoint("TOPRIGHT", -2, -3)
    row.r:SetWidth(100); row.r:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", function(self)
        local d = self.d
        if not d or d.header then return end
        if d.go or d.item then self.hl:Show() end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.spell then
            GameTooltip:SetHyperlink("spell:" .. d.spell)
        elseif d.item then
            GameTooltip:SetHyperlink("item:" .. d.item)
        elseif d.tip then
            GameTooltip:SetText(d.tip[1] or "", 1, 1, 1)
            for k = 2, 6 do if d.tip[k] then GameTooltip:AddLine(d.tip[k], 0.8, 0.8, 0.8, 1) end end
        else
            GameTooltip:Hide(); return
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        local d = self.d
        if not d then return end
        if IsModifiedClick() and d.item then
            local _, link = GetItemInfo(d.item)
            if link and HandleModifiedItemClick(link) then return end
        end
        if d.go then Navigate(d.go) end
    end)
    return row
end
for i = 1, ROWS do rows[i] = MakeRow(i) end

scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateRows)
end)

f:SetScript("OnUpdate", function(self, el)
    if searchTimer then
        searchTimer = searchTimer - el
        if searchTimer <= 0 then
            searchTimer = nil
            if view.mode ~= "search" then stack = {}; view = { mode = "search", tab = curTab } end
            view.query = search:GetText()
            Refresh(true)
        end
    end
    if retryTimer then
        retryTimer = retryTimer - el
        if retryTimer <= 0 then retryTimer = nil; UpdateRows() end
    end
end)

---------------------------------------------------------------- views
function Refresh(resetScroll)
    -- tabs
    for key, b in pairs(TABBTN) do
        if key == curTab then b:Disable() else b:Enable() end
    end
    if #stack > 0 then
        backBtn:Show()
        hBtn:ClearAllPoints(); hBtn:SetPoint("TOPLEFT", 84, -66)
    else
        backBtn:Hide()
        hBtn:ClearAllPoints(); hBtn:SetPoint("TOPLEFT", 20, -66)
    end
    hSub1:SetText(""); hSub2:SetText("")

    if view.mode == "search" then
        hTitle:SetText(({ mobs = "Find a creature", items = "Find an item", recipes = "Find a crafting recipe" })[curTab])
        local list, total = RunSearch(curTab, view.query)
        rowsData = {}
        if #list == 0 then
            if #strtrim(view.query or "") < 2 then
                hSub1:SetText("Type at least 2 letters. Click a result for details.")
                rowsData[1] = { header = ({
                    mobs = "Shows where to find it and what it drops.",
                    items = "Shows who drops it, sells it, and what crafts it.",
                    recipes = "Shows reagents, what it makes and where to learn it." })[curTab] }
            else
                hSub1:SetText("No matches.")
            end
        else
            hSub1:SetText(total > #list and format("%d matches (showing the first %d)", total, #list)
                                         or format("%d matches", total))
            for _, id in ipairs(list) do
                if curTab == "mobs" then
                    rowsData[#rowsData + 1] = MobRow(id)
                elseif curTab == "recipes" then
                    rowsData[#rowsData + 1] = RecipeRow(id)
                else
                    rowsData[#rowsData + 1] = { item = id, t1 = ColorName(id), t2 = "Item ID " .. id,
                                                go = { mode = "item", id = id } }
                end
            end
        end

    elseif view.mode == "mob" then
        local name, mn, mx, rank, area = MobInfo(view.id)
        hTitle:SetText(name or ("NPC " .. view.id))
        hSub1:SetText(format("%s%s   |cff888888NPC ID %d|r", LevelText(mn, mx),
                             RANK[rank] and ("  " .. RANK[rank]) or "", view.id))
        local where = (area and area ~= "") and area or "unknown (summoned / special spawn)"
        local txt = "|cffffd100Where (approx.):|r " .. where
        local zones = LearnedZones(view.id)
        if #zones > 0 then txt = txt .. "\n|cffffd100Seen in:|r " .. concat(zones, ", ") end
        hSub2:SetText(txt)
        rowsData = MobRows(view.id)

    elseif view.mode == "item" then
        hTitle:SetText(ColorName(view.id))
        hSub1:SetText("|cff888888Item ID " .. view.id .. "|r  -  hover the name for the tooltip")
        rowsData = ItemRows(view.id)

    elseif view.mode == "recipe" then
        local c = Craft(view.id)
        local label = c and RecipeLabel(c)
        hTitle:SetText(label or ("Recipe #" .. view.id))
        if c then
            hSub1:SetText(format("%s  -  requires skill %d   |cff888888spell %d|r",
                                 PROF[c.prof] or "?", c.skill, view.id))
        end
        hSub2:SetText("Hover the name for the recipe tooltip. Click an item to see where to get it.")
        rowsData = RecipeRows(view.id)
    end

    if resetScroll then
        FauxScrollFrame_SetOffset(scroll, 0)
        scroll:SetVerticalScroll(0)
    end
    retry = 0
    UpdateRows()
end

function Navigate(v, replace)
    if not replace and view then stack[#stack + 1] = view end
    if #stack > 30 then table.remove(stack, 1) end
    view = v
    if not v.tab then v.tab = curTab end
    f:Show()
    Refresh(true)
end

function Back()
    local v = table.remove(stack)
    if not v then return end
    view = v
    if v.tab then curTab = v.tab end
    Refresh(true)
end

function SetTab(key)
    curTab = key
    stack = {}
    view = { mode = "search", tab = key, query = search:GetText() }
    Refresh(true)
end

f:SetScript("OnShow", function()
    StartIndexBuild()
    if not sindex then BuildSearchIndex() end
end)

---------------------------------------------------------------- learning
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
    if currentNpc then
        local name = MobInfo(currentNpc)
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

local function OpenSearch()
    if f:IsShown() and view.mode == "search" then f:Hide(); return end
    stack = {}
    view = { mode = "search", tab = curTab, query = search:GetText() }
    f:Show(); Refresh(true)
end

local function LibraryClick(button)
    if button == "RightButton" or not currentNpc then
        OpenSearch()
    elseif f:IsShown() and view.mode == "mob" and view.id == currentNpc then
        f:Hide()
    else
        Navigate({ mode = "mob", id = currentNpc, follow = true })
    end
end
mb:SetScript("OnClick", function(self, button) LibraryClick(button) end)

MinimapPos()

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
    local name = currentNpc and MobInfo(currentNpc)
    GameTooltip:AddLine("Left-click: loot table of " .. (name or UnitName("target") or "this creature"), nil, nil, nil, 1)
    GameTooltip:AddLine("Right-click: search the library", 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine("Drag: move around the portrait", 0.6, 0.6, 0.6, 1)
    GameTooltip:Show()
end)
tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
tb:SetScript("OnClick", function(self, button) LibraryClick(button) end)

local function UpdatePortraitButton()
    local db = MobLootDB.targetBtn
    if currentNpc and not (db and db.hide) then
        if db and not db.angle then db.angle = DefaultPortraitAngle() end
        PortraitPos()
        tb:Show()
    else
        tb:Hide()
    end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("LOOT_OPENED")

local counted = {}
local function LootUnit()
    for _, u in ipairs({ "target", "mouseover" }) do
        if UnitExists(u) and UnitIsDead(u) and not UnitIsPlayer(u) and GetNpcId(u) then return u end
    end
end

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "MobLoot" then
        MobLootDB.learned = MobLootDB.learned or {}
        MobLootDB.mobs = MobLootDB.mobs or {}
        MobLootDB.minimap = MobLootDB.minimap or { angle = 215 }
        MobLootDB.targetBtn = MobLootDB.targetBtn or {}
        MinimapPos()
        if MobLootDB.minimap.hide then mb:Hide() else mb:Show() end

    elseif event == "PLAYER_TARGET_CHANGED" then
        local id = UnitExists("target") and not UnitIsPlayer("target") and GetNpcId("target") or nil
        currentNpc = id
        UpdatePortraitButton()
        if id then
            if not UnitPlayerControlled("target") then Note(id, "target") end
            if f:IsShown() and view.follow then
                view = { mode = "mob", id = id, follow = true, tab = curTab }
                stack = {}
                Refresh(true)
            end
        end

    elseif event == "LOOT_OPENED" then
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
        if f:IsShown() and view.mode == "mob" and view.id == npc then Refresh() end
    end
end)

---------------------------------------------------------------- slash
SLASH_MOBLOOT1 = "/mobloot"
SLASH_MOBLOOT2 = "/ml"
SlashCmdList["MOBLOOT"] = function(msg)
    msg = strtrim(msg or "")
    local low = msg:lower()
    if low == "reset" then
        MobLootDB.learned = {}; MobLootDB.mobs = {}; sindex = nil
        print("|cff33ff99MobLoot:|r learned data cleared.")
        return
    end
    if low == "minimap" then
        MobLootDB.minimap = MobLootDB.minimap or { angle = 215 }
        MobLootDB.minimap.hide = not MobLootDB.minimap.hide
        if MobLootDB.minimap.hide then mb:Hide() else mb:Show() end
        print("|cff33ff99MobLoot:|r minimap button " .. (MobLootDB.minimap.hide and "hidden" or "shown") .. ".")
        return
    end
    if low == "target" or low == "portrait" then
        MobLootDB.targetBtn = MobLootDB.targetBtn or {}
        MobLootDB.targetBtn.hide = not MobLootDB.targetBtn.hide
        UpdatePortraitButton()
        print("|cff33ff99MobLoot:|r portrait button " .. (MobLootDB.targetBtn.hide and "hidden" or "shown") .. ".")
        return
    end
    local tab, text = "mobs", msg
    local rest = low:match("^items?%s+(.+)$")
    if rest then
        tab, text = "items", msg:sub(#msg - #rest + 1)
    else
        rest = low:match("^recipes?%s+(.+)$") or low:match("^craft%s+(.+)$")
        if rest then tab, text = "recipes", msg:sub(#msg - #rest + 1) end
    end
    if text ~= "" then
        curTab = tab; stack = {}
        view = { mode = "search", tab = tab, query = text }
        search:SetText(text)
        f:Show(); Refresh(true)
    elseif f:IsShown() then
        f:Hide()
    elseif currentNpc then
        Navigate({ mode = "mob", id = currentNpc, follow = true })
    else
        stack = {}; view = { mode = "search", tab = curTab, query = search:GetText() }
        f:Show(); Refresh(true)
    end
end
