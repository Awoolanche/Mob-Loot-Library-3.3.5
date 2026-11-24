local addonName, ns = ...
local sort, format = table.sort, string.format

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

ns.GetNpcId, ns.MobInfo, ns.LearnedZones = GetNpcId, MobInfo, LearnedZones
ns.LevelText, ns.ItemQN, ns.ColorName = LevelText, ItemQN, ColorName
ns.PROF, ns.Craft, ns.RecipeLabel, ns.ChanceText = PROF, Craft, RecipeLabel, ChanceText
