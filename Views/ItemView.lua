local addonName, ns = ...
local floor, sort, format = math.floor, table.sort, string.format
local MobInfo, ColorName, ChanceText, Craft = ns.MobInfo, ns.ColorName, ns.ChanceText, ns.Craft
local MobRow, RecipeRow, SortSpells, rev = ns.MobRow, ns.RecipeRow, ns.SortSpells, ns.rev
local ICON_QUEST, ICON_OBJ = ns.ICON_QUEST, ns.ICON_OBJ

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
                go = { mode = "quest", id = q[i] },
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
                fav = { kind = "obj", id = o[i] },
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

ns.ItemRows = ItemRows
