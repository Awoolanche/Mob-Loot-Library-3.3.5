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
-- File layout (see MobLoot.toc for the load order):
--   Core/Init.lua           namespace, constants, shared state
--   Core/Util.lua           lookups + formatting helpers
--   Index/ReverseIndex.lua  item -> sources index (built incrementally)
--   Index/Search.lua        name search index
--   Views/*.lua             row builders for creature / item / recipe pages
--   UI/Window.lua           main frame, tabs, search box, header
--   UI/List.lua             scrolling multi-column result list
--   UI/Layout.lua           size-dependent layout (rows, columns)
--   UI/Position.lua         window scale / position / size persistence
--   UI/ResizeGrip.lua       bottom-right resize triangle
--   UI/Options.lua          Interface > AddOns panel
--   UI/MinimapButton.lua    minimap button
--   UI/PortraitButton.lua   target portrait button
--   Views/Controller.lua    Refresh / Navigate / Back / SetTab, timers
--   Core/Learning.lua       records what you see and loot
--   Core/Events.lua         event dispatch + saved variable setup
--   Core/Slash.lua          /mobloot, /ml
----------------------------------------------------------------------
local addonName, ns = ...
ns.name = addonName

-- layout / behaviour constants
ns.C = {
    ROW_H = 32, MAX_ROWS = 30,
    MAX_COLS = 4, COL_MIN_W = 300, COL_GAP = 8,    -- extra columns appear once each column can be >= COL_MIN_W wide
    SEARCH_MIN_W = 120, SEARCH_MAX_W = 260,        -- w-280 >= 120 at the 400px minimum window width
    WIN_MIN_W = 400, WIN_MIN_H = 300, WIN_MAX_W = 1400, WIN_MAX_H = 1000,
    DEF_W = 450, DEF_H = 470,                      -- default window size
    SCALE_MIN = 0.5, SCALE_MAX = 1.5,
}

-- generated data tables (MobLootData.lua / MobLootInfo.lua); empty when those files are missing
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

ns.RANK = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }
ns.ICON_MOB   = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
ns.ICON_BOSS  = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
ns.ICON_QUEST = "Interface\\Icons\\INV_Misc_Note_01"
ns.ICON_OBJ   = "Interface\\Icons\\INV_Box_01"
ns.ICON_UNK   = "Interface\\Icons\\INV_Misc_QuestionMark"

-- mutable state shared between files (locals cannot cross file boundaries)
ns.state = {
    view = { mode = "search", tab = "mobs", query = "" },   -- what the window currently shows
    stack = {},                                            -- back history
    rowsData = {},                                         -- entries of the current view
    curTab = "mobs",
    currentNpc = nil,                                      -- npc id of the current target
    searchTimer = nil, retry = 0, retryTimer = nil,
}
-- current list geometry (written by UI/Layout.lua)
ns.layout = { rows = 10, cols = 1, rowW = 394, colW = 394 }

ns.ui = {}   -- widgets, filled in by the UI files
