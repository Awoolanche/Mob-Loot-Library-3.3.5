local addonName, ns = ...
local format = string.format
local Craft, ColorName, MobRow = ns.Craft, ns.ColorName, ns.MobRow

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

ns.RecipeRows = RecipeRows
