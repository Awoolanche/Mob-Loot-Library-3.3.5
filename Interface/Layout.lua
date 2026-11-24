local addonName, ns = ...
local C, L, f, ui = ns.C, ns.layout, ns.frame, ns.ui
local floor = math.floor
local ROW_H, MAX_ROWS, MAX_COLS, COL_MIN_W, COL_GAP = C.ROW_H, C.MAX_ROWS, C.MAX_COLS, C.COL_MIN_W, C.COL_GAP
local SEARCH_MIN_W, SEARCH_MAX_W = C.SEARCH_MIN_W, C.SEARCH_MAX_W
local rows, scroll, search = ui.rows, ui.scroll, ui.search
local hSub1, hSub2, hTitle, hBtn = ui.hSub1, ui.hSub2, ui.hTitle, ui.hBtn

-- resize: recompute how many rows fit and stretch the text to the new width
local function Relayout()
    local w, h = f:GetWidth(), f:GetHeight()
    L.rows = math.max(1, math.min(MAX_ROWS, floor((h - 150) / ROW_H)))
    L.rowW = w - 56
    L.cols = math.max(1, math.min(MAX_COLS, floor((L.rowW + COL_GAP) / (COL_MIN_W + COL_GAP))))
    L.colW = floor((L.rowW - (L.cols - 1) * COL_GAP) / L.cols)
    for i = 1, MAX_ROWS do
        for c = 1, MAX_COLS do
            local row = rows[i][c]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scroll, "TOPLEFT", (c - 1) * (L.colW + COL_GAP), -(i - 1) * ROW_H)
        end
    end
    hSub1:SetWidth(w - 42); hSub2:SetWidth(w - 42)
    search:SetWidth(math.max(SEARCH_MIN_W, math.min(SEARCH_MAX_W, w - 280)))   -- right-anchored; left edge never goes past the tabs (x=234)
    hTitle:SetWidth(w - 110); hBtn:SetWidth(w - 110)
    ns.UpdateRows()
end
f:SetScript("OnSizeChanged", Relayout)
Relayout()
ns.Relayout = Relayout
