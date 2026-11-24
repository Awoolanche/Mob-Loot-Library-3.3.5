local addonName, ns = ...
local format = string.format
local ColorName, ChanceText, BuildDrops = ns.ColorName, ns.ChanceText, ns.BuildDrops

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

ns.MobRows = MobRows
