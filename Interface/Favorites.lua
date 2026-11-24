local addonName, ns = ...
local S, f, ui = ns.state, ns.frame, ns.ui
local format, sort = string.format, table.sort

--------------------------------------------------------------------
-- Favourites: stored in MobLootDB.fav[kind][id] = true
--   kinds: mob (creatures / vendors / trainers), item, recipe, quest, obj (chests / nodes)
--------------------------------------------------------------------
local FAVKIND = { mob = true, item = true, recipe = true, quest = true, obj = true }
local STAR = ns.ICON_STAR
local FR, FG, FB = unpack(ns.FAV_RGB)

local function Bucket(kind)
    local fav = MobLootDB.fav
    if not fav then fav = {}; MobLootDB.fav = fav end
    local b = fav[kind]
    if not b then b = {}; fav[kind] = b end
    return b
end

function ns.IsFav(kind, id)
    local fav = MobLootDB and MobLootDB.fav
    local b = fav and fav[kind]
    return (b and b[id]) and true or false
end

-- which favourite (if any) a list row stands for: explicit d.fav, else derived from its link target
function ns.RowFav(d)
    if d.fav then return d.fav.kind, d.fav.id end
    local g = d.go
    if g and FAVKIND[g.mode] and g.id then return g.mode, g.id end
end

function ns.ToggleFav(kind, id)
    local b = Bucket(kind)
    if b[id] then b[id] = nil else b[id] = true end
    if S.curTab == "favs" and S.view.mode == "search" then ns.Refresh() else ns.UpdateRows() end
    ns.UpdateFavButton()
    return b[id] and true or false
end

---------------------------------------------------------------- header star (current page)
local favBtn = CreateFrame("Button", "MobLootFavButton", f)
favBtn:SetSize(20, 20)
favBtn:SetFrameLevel(ui.hBtn:GetFrameLevel() + 5)   -- above the title button, which would otherwise take the mouse
favBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -64)
favBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
favBtn:GetHighlightTexture():SetBlendMode("ADD")
local favTex = favBtn:CreateTexture(nil, "ARTWORK")
favTex:SetAllPoints()
favTex:SetTexture(STAR)
favBtn:Hide()

local function FavTarget()
    local m = S.view.mode
    if FAVKIND[m] and S.view.id then return m, S.view.id end
end

function ns.UpdateFavButton()
    local kind, id = FavTarget()
    if not kind then favBtn:Hide(); return end
    local on = ns.IsFav(kind, id)
    if on then
        favTex:SetDesaturated(false)
        favTex:SetVertexColor(FR, FG, FB)        -- brass tint on the yellow star
    else
        favTex:SetDesaturated(true)              -- grey when not a favourite
        favTex:SetVertexColor(0.6, 0.6, 0.6)
    end
    favBtn:Show()
end

favBtn:SetScript("OnClick", function(self)
    local kind, id = FavTarget()
    if kind then ns.ToggleFav(kind, id) end
    if GameTooltip:GetOwner() == self then self:GetScript("OnEnter")(self) end
end)
favBtn:SetScript("OnEnter", function(self)
    local kind, id = FavTarget()
    if not kind then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.IsFav(kind, id) and "Remove from favourites" or "Add to favourites", 1, 1, 1)
    GameTooltip:Show()
end)
favBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
ui.favBtn = favBtn

---------------------------------------------------------------- favourites tab
local function PlainName(kind, id)
    if kind == "mob" then
        return (ns.MobInfo(id)) or ("NPC " .. id)
    elseif kind == "item" then
        local _, n = ns.ItemQN(id)
        return n or ("Item #" .. id)
    elseif kind == "recipe" then
        local c = ns.Craft(id)
        if c then
            local _, plain = ns.RecipeLabel(c)
            if plain then return plain end
        end
        return "Recipe #" .. id
    elseif kind == "quest" then
        local _, title = (MobLoot_Quests[id] or ""):match("^(%-?%d+)|(.*)$")
        return title or ("Quest #" .. id)
    else
        local name = (MobLoot_Objs[id] or ""):match("^([^|]*)|")
        return (name and name ~= "") and name or ("Object #" .. id)
    end
end

local function BuildRow(kind, id)
    local row
    if kind == "mob" then
        row = ns.MobRow(id)
    elseif kind == "item" then
        row = { item = id, t1 = ns.ColorName(id), t2 = "Item ID " .. id, go = { mode = "item", id = id } }
    elseif kind == "recipe" then
        row = ns.RecipeRow(id) or { icon = ns.ICON_UNK, t1 = "Recipe #" .. id, t2 = "No data", go = { mode = "recipe", id = id } }
    elseif kind == "quest" then
        row = ns.QuestRow(id, "")
    else
        local name, area = (MobLoot_Objs[id] or ""):match("^([^|]*)|(.*)$")
        local where = (area and area ~= "") and area or "location unknown"
        row = { icon = ns.ICON_OBJ, t1 = "|cff99ccff" .. ((name and name ~= "") and name or ("Object #" .. id)) .. "|r",
                t2 = where, tip = { name or "Object", "Location (approx.): " .. where } }
    end
    row.fav = { kind = kind, id = id }
    return row
end

local SECTIONS = {
    { "mob", "Creatures" }, { "item", "Items" }, { "recipe", "Recipes" },
    { "quest", "Quests" }, { "obj", "Chests / nodes" },
}

-- returns rows, shown count, total favourites
function ns.FavRows(query)
    local q = strtrim((query or ""):lower())
    local rows, shown, total = {}, 0, 0
    local fav = MobLootDB.fav or {}
    for _, sec in ipairs(SECTIONS) do
        local kind, title = sec[1], sec[2]
        local list = {}
        for id in pairs(fav[kind] or {}) do
            total = total + 1
            local name = PlainName(kind, id)
            if q == "" or name:lower():find(q, 1, true) then
                list[#list + 1] = { id = id, key = name:lower() }
            end
        end
        if #list > 0 then
            sort(list, function(a, b)
                if a.key ~= b.key then return a.key < b.key end
                return a.id < b.id
            end)
            rows[#rows + 1] = { header = format("%s (%d)", title, #list) }
            for _, e in ipairs(list) do rows[#rows + 1] = BuildRow(kind, e.id) end
            shown = shown + #list
        end
    end
    return rows, shown, total
end
