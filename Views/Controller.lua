local addonName, ns = ...
local floor, concat, format = math.floor, table.concat, string.format
local S, f, ui = ns.state, ns.frame, ns.ui
local TABBTN, backBtn, hBtn, hTitle, hSub1, hSub2 = ui.tabs, ui.backBtn, ui.hBtn, ui.hTitle, ui.hSub1, ui.hSub2
local search, scroll = ui.search, ui.scroll
local MobInfo, LearnedZones, LevelText, ColorName = ns.MobInfo, ns.LearnedZones, ns.LevelText, ns.ColorName
local Craft, RecipeLabel, PROF, RANK = ns.Craft, ns.RecipeLabel, ns.PROF, ns.RANK
local MobRow, RecipeRow, RunSearch = ns.MobRow, ns.RecipeRow, ns.RunSearch
local MobRows, ItemRows, RecipeRows = ns.MobRows, ns.ItemRows, ns.RecipeRows
local QuestRow, QuestRows = ns.QuestRow, ns.QuestRows

---------------------------------------------------------------- views
function ns.Refresh(resetScroll)
    -- tabs
    for key, b in pairs(TABBTN) do
        if key == S.curTab then b:Disable() else b:Enable() end
    end
    if #S.stack > 0 then
        backBtn:Show()
        hBtn:ClearAllPoints(); hBtn:SetPoint("TOPLEFT", 84, -66)
    else
        backBtn:Hide()
        hBtn:ClearAllPoints(); hBtn:SetPoint("TOPLEFT", 20, -66)
    end
    hSub1:SetText(""); hSub2:SetText("")

    if S.view.mode == "search" then
        hTitle:SetText(({ mobs = "Find a creature", items = "Find an item", recipes = "Find a crafting recipe" })[S.curTab])
        local list, total = RunSearch(S.curTab, S.view.query)
        S.rowsData = {}

        -- exact id match: npc / item / spell id of the current tab, quest ids on any tab
        local idq = ns.ParseId(S.view.query)
        local idRows = {}
        if idq then
            local tabHit, questHit = ns.IdLookup(S.curTab, idq)
            if tabHit then
                local row
                if S.curTab == "mobs" then
                    row = MobRow(idq)
                elseif S.curTab == "recipes" then
                    row = RecipeRow(idq)
                else
                    row = { item = idq, t1 = ColorName(idq), t2 = "Item ID " .. idq, go = { mode = "item", id = idq } }
                end
                if row then idRows[#idRows + 1] = row end
                local kept = {}                              -- do not list the same id twice
                for _, id in ipairs(list) do if id ~= idq then kept[#kept + 1] = id end end
                if #kept < #list then total = total - 1 end
                list = kept
            end
            if questHit then idRows[#idRows + 1] = QuestRow(idq) end
        end

        if #list == 0 and #idRows == 0 then
            if #strtrim(S.view.query or "") < 2 and not idq then
                hSub1:SetText("Type at least 2 letters, or an ID. Click a result for details.")
                S.rowsData[1] = { header = ({
                    mobs = "Shows where to find it and what it drops.",
                    items = "Shows who drops it, sells it, and what crafts it.",
                    recipes = "Shows reagents, what it makes and where to learn it." })[S.curTab] }
            else
                hSub1:SetText("No matches.")
            end
        else
            local shown, all = #list + #idRows, total + #idRows
            hSub1:SetText(all > shown and format("%d matches (showing the first %d)", all, shown)
                                       or format("%d matches", all))
            if #idRows > 0 then
                S.rowsData[#S.rowsData + 1] = { header = "Matches ID " .. idq }
                for _, row in ipairs(idRows) do S.rowsData[#S.rowsData + 1] = row end
                if #list > 0 then S.rowsData[#S.rowsData + 1] = { header = format("Name matches (%d)", total) } end
            end
            for _, id in ipairs(list) do
                if S.curTab == "mobs" then
                    S.rowsData[#S.rowsData + 1] = MobRow(id)
                elseif S.curTab == "recipes" then
                    S.rowsData[#S.rowsData + 1] = RecipeRow(id)
                else
                    S.rowsData[#S.rowsData + 1] = { item = id, t1 = ColorName(id), t2 = "Item ID " .. id,
                                                    go = { mode = "item", id = id } }
                end
            end
        end

    elseif S.view.mode == "mob" then
        local name, mn, mx, rank, area = MobInfo(S.view.id)
        hTitle:SetText(name or ("NPC " .. S.view.id))
        hSub1:SetText(format("%s%s   |cff888888NPC ID %d|r", LevelText(mn, mx),
                             RANK[rank] and ("  " .. RANK[rank]) or "", S.view.id))
        local where = (area and area ~= "") and area or "unknown (summoned / special spawn)"
        local txt = "|cffffd100Where (approx.):|r " .. where
        local zones = LearnedZones(S.view.id)
        if #zones > 0 then txt = txt .. "\n|cffffd100Seen in:|r " .. concat(zones, ", ") end
        hSub2:SetText(txt)
        S.rowsData = MobRows(S.view.id)

    elseif S.view.mode == "quest" then
        local lvl, title = (MobLoot_Quests[S.view.id] or ""):match("^(%-?%d+)|(.*)$")
        hTitle:SetText("|cffffff00" .. (title or ("Quest #" .. S.view.id)) .. "|r")
        hSub1:SetText((lvl and ("Level " .. lvl .. "   ") or "") .. "|cff888888Quest ID " .. S.view.id .. "|r")
        S.rowsData = QuestRows(S.view.id)

    elseif S.view.mode == "item" then
        hTitle:SetText(ColorName(S.view.id))
        hSub1:SetText("|cff888888Item ID " .. S.view.id .. "|r  -  hover the name for the tooltip")
        S.rowsData = ItemRows(S.view.id)

    elseif S.view.mode == "recipe" then
        local c = Craft(S.view.id)
        local label = c and RecipeLabel(c)
        hTitle:SetText(label or ("Recipe #" .. S.view.id))
        if c then
            hSub1:SetText(format("%s  -  requires skill %d   |cff888888spell %d|r",
                                 PROF[c.prof] or "?", c.skill, S.view.id))
        end
        hSub2:SetText("Hover the name for the recipe tooltip. Click an item to see where to get it.")
        S.rowsData = RecipeRows(S.view.id)
    end

    if resetScroll then
        FauxScrollFrame_SetOffset(scroll, 0)
        scroll:SetVerticalScroll(0)
    end
    S.retry = 0
    ns.UpdateRows()
end

function ns.Navigate(v, replace)
    if not replace and S.view then S.stack[#S.stack + 1] = S.view end
    if #S.stack > 30 then table.remove(S.stack, 1) end
    S.view = v
    if not v.tab then v.tab = S.curTab end
    f:Show()
    ns.Refresh(true)
end

function ns.Back()
    local v = table.remove(S.stack)
    if not v then return end
    S.view = v
    if v.tab then S.curTab = v.tab end
    ns.Refresh(true)
end

function ns.SetTab(key)
    S.curTab = key
    S.stack = {}
    S.view = { mode = "search", tab = key, query = search:GetText() }
    ns.Refresh(true)
end

--------------------------------------------------------------------
-- window timers (delayed search, icon retry) and first-show setup
--------------------------------------------------------------------
f:SetScript("OnUpdate", function(self, el)
    if S.searchTimer then
        S.searchTimer = S.searchTimer - el
        if S.searchTimer <= 0 then
            S.searchTimer = nil
            if S.view.mode ~= "search" then S.stack = {}; S.view = { mode = "search", tab = S.curTab } end
            S.view.query = search:GetText()
            ns.Refresh(true)
        end
    end
    if S.retryTimer then
        S.retryTimer = S.retryTimer - el
        if S.retryTimer <= 0 then S.retryTimer = nil; ns.UpdateRows() end
    end
end)

f:SetScript("OnShow", function()
    ns.StartIndexBuild()
    ns.EnsureSearchIndex()
end)

--------------------------------------------------------------------
-- opening the window from the buttons
--------------------------------------------------------------------
local function OpenSearch()
    if f:IsShown() and S.view.mode == "search" then f:Hide(); return end
    S.stack = {}
    S.view = { mode = "search", tab = S.curTab, query = search:GetText() }
    f:Show(); ns.Refresh(true)
end

local function LibraryClick(button)
    if button == "RightButton" or not S.currentNpc then
        OpenSearch()
    elseif f:IsShown() and S.view.mode == "mob" and S.view.id == S.currentNpc then
        f:Hide()
    else
        ns.Navigate({ mode = "mob", id = S.currentNpc, follow = true })
    end
end
ns.LibraryClick = LibraryClick
