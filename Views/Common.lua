local addonName, ns = ...
local sort, concat, format = table.sort, table.concat, string.format
local MobInfo, LearnedZones, LevelText = ns.MobInfo, ns.LearnedZones, ns.LevelText
local Craft, RecipeLabel, PROF, RANK = ns.Craft, ns.RecipeLabel, ns.PROF, ns.RANK
local ICON_MOB, ICON_BOSS = ns.ICON_MOB, ns.ICON_BOSS

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

local function QuestRow(id, right)
    local lvl, title = (MobLoot_Quests[id] or ""):match("^(%-?%d+)|(.*)$")
    return {
        icon = ns.ICON_QUEST, t1 = "|cffffff00" .. (title or ("Quest #" .. id)) .. "|r",
        t2 = (lvl and ("Level " .. lvl .. " - ") or "") .. "Quest ID " .. id, r = right or "Quest",
        go = { mode = "quest", id = id },
        tip = { title or "Quest", "Quest ID " .. id },
    }
end

ns.BuildDrops, ns.MobRow, ns.RecipeRow, ns.SortSpells, ns.QuestRow = BuildDrops, MobRow, RecipeRow, SortSpells, QuestRow
