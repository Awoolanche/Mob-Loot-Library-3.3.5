local addonName, ns = ...
local S, f, ui, mb = ns.state, ns.frame, ns.ui, ns.mb

---------------------------------------------------------------- slash
SLASH_MOBLOOT1 = "/mobloot"
SLASH_MOBLOOT2 = "/ml"
SlashCmdList["MOBLOOT"] = function(msg)
    msg = strtrim(msg or "")
    local low = msg:lower()
    if low == "reset" then
        MobLootDB.learned = {}; MobLootDB.mobs = {}; ns.ResetSearchIndex()
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
        ns.UpdatePortraitButton()
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
        S.curTab = tab; S.stack = {}
        S.view = { mode = "search", tab = tab, query = text }
        ui.search:SetText(text)
        f:Show(); ns.Refresh(true)
    else
        ns.ToggleLibrary()
    end
end

---------------------------------------------------------------- keybinding
-- Toggle: hide if shown, else open the current target's loot table,
-- else open the search view.
function ns.ToggleLibrary()
    if f:IsShown() then
        f:Hide()
    elseif S.currentNpc then
        ns.Navigate({ mode = "mob", id = S.currentNpc, follow = true })
    else
        S.stack = {}; S.view = { mode = "search", tab = S.curTab, query = ui.search:GetText() }
        f:Show(); ns.Refresh(true)
    end
end

-- Labels shown in Key Bindings (ESC > Key Bindings > AddOns)
BINDING_HEADER_MOBLOOT = "Mob Loot Library"
BINDING_NAME_MOBLOOT_TOGGLE = "Toggle Loot Library"

-- Global entry point used by Bindings.xml
function MobLoot_Toggle() ns.ToggleLibrary() end
