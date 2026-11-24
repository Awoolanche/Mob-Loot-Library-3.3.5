local addonName, ns = ...
local format = string.format
local ColorName = ns.ColorName

-- rewards of one quest: guaranteed items and "choose one" items
local function QuestRows(id)
    local rows = {}
    local fixed, choice = {}, {}
    local s = MobLoot_QuestRew[id]
    if s then
        for sign, iid in s:gmatch("(%-?)(%d+)") do
            local t = (sign == "-") and choice or fixed
            t[#t + 1] = tonumber(iid)
        end
    end
    local function section(title, list, note)
        if #list == 0 then return end
        rows[#rows + 1] = { header = format("%s (%d)", title, #list) }
        for _, iid in ipairs(list) do
            rows[#rows + 1] = { item = iid, t1 = ColorName(iid), t2 = note, go = { mode = "item", id = iid } }
        end
    end
    section("Guaranteed rewards", fixed, "Guaranteed reward")
    section("Reward choices", choice, "Reward choice")
    if #rows == 0 then
        rows[1] = { header = "No item rewards known for this quest." }
        rows[2] = { header = "|cff999999It may only give money, reputation or experience.|r" }
    end
    return rows
end

ns.QuestRows = QuestRows
