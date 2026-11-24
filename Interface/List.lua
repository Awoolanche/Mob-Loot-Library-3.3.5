local addonName, ns = ...
local C, S, L, f = ns.C, ns.state, ns.layout, ns.frame
local ROW_H, MAX_ROWS, MAX_COLS, ICON_UNK = C.ROW_H, C.MAX_ROWS, C.MAX_COLS, ns.ICON_UNK

-- list
local scroll = CreateFrame("ScrollFrame", "MobLootScroll", f, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -134)
scroll:SetPoint("BOTTOMRIGHT", -36, 16)

local rows = {}          -- rows[line][col] = cell button

local scanTip = CreateFrame("GameTooltip", "MobLootScanTip", UIParent, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function UpdateRows()
    -- pack entries into lines: headers get a full-width line, items fill L.cols per line
    local lines, cur = {}, nil
    for k = 1, #S.rowsData do
        local e = S.rowsData[k]
        if e.header then
            lines[#lines + 1] = { e }; cur = nil
        else
            if not cur or #cur >= L.cols then cur = {}; lines[#lines + 1] = cur end
            cur[#cur + 1] = e
        end
    end
    FauxScrollFrame_Update(scroll, #lines, L.rows, ROW_H)
    local offset = FauxScrollFrame_GetOffset(scroll)
    local missing = false
    for i = 1, MAX_ROWS do
      local ld = (i <= L.rows) and lines[i + offset] or nil
      for c = 1, MAX_COLS do
        local row = rows[i][c]
        local d = ld and ld[c] or nil
        if d then
            row.d = d
            local cw = d.header and L.rowW or L.colW
            row:SetWidth(cw)
            row.t1:SetWidth(d.header and math.max(100, cw - 40) or math.max(100, cw - 150))
            row.t2:SetWidth(math.max(100, cw - 59))
            if d.header then
                row.icon:Hide()
                row.t1:SetText("|cffffd100" .. d.header .. "|r")
                row.t2:SetText(""); row.r:SetText("")
                row.star:Hide()
            else
                if d.item then
                    local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(d.item)
                    if tex then
                        row.icon:SetTexture(tex)
                    else
                        missing = true
                        scanTip:SetHyperlink("item:" .. d.item)   -- ask the server
                        row.icon:SetTexture(ICON_UNK)
                    end
                else
                    row.icon:SetTexture(d.icon or ICON_UNK)
                end
                row.icon:Show()
                row.t1:SetText(d.t1 or "")
                row.t2:SetText(d.t2 or "")
                row.r:SetText(d.r or "")
                local fk, fid = ns.RowFav(d)
                if fk and ns.IsFav(fk, fid) then row.star:Show() else row.star:Hide() end
            end
            row:Show()
        else
            row.d = nil
            row:Hide()
        end
      end
    end
    if missing and S.retry < 8 then S.retry = S.retry + 1; S.retryTimer = 0.5 end
end

local function MakeRow()
    local row = CreateFrame("Button", nil, f)
    row:SetSize(394, ROW_H - 2)   -- width/position are set in Relayout / UpdateRows
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.hl:SetBlendMode("ADD")
    row.hl:Hide()
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 2, 0)
    row.t1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.t1:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.t1:SetWidth(250); row.t1:SetHeight(13); row.t1:SetJustifyH("LEFT")
    row.t2 = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.t2:SetPoint("TOPLEFT", row.t1, "BOTTOMLEFT", 0, -1)
    row.t2:SetWidth(335); row.t2:SetHeight(11); row.t2:SetJustifyH("LEFT")
    row.r = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.r:SetPoint("TOPRIGHT", -2, -3)
    row.r:SetWidth(100); row.r:SetJustifyH("RIGHT")
    row.star = row:CreateTexture(nil, "OVERLAY")          -- shown on favourites
    row.star:SetSize(12, 12); row.star:SetPoint("BOTTOMRIGHT", -3, 3)
    row.star:SetTexture(ns.ICON_STAR)
    row.star:SetVertexColor(unpack(ns.FAV_RGB))
    row.star:Hide()
    row:SetScript("OnEnter", function(self)
        local d = self.d
        if not d or d.header then return end
        if d.go or d.item then self.hl:Show() end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if d.spell then
            GameTooltip:SetHyperlink("spell:" .. d.spell)
        elseif d.item then
            GameTooltip:SetHyperlink("item:" .. d.item)
        elseif d.tip then
            GameTooltip:SetText(d.tip[1] or "", 1, 1, 1)
            for k = 2, 6 do if d.tip[k] then GameTooltip:AddLine(d.tip[k], 0.8, 0.8, 0.8, 1) end end
        else
            GameTooltip:Hide(); return
        end
        local fk, fid = ns.RowFav(d)
        if fk then
            GameTooltip:AddLine(ns.IsFav(fk, fid) and "Right-click: remove from favourites" or "Right-click: add to favourites", 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        local d = self.d
        if not d then return end
        if button == "RightButton" then               -- toggle favourite
            local fk, fid = ns.RowFav(d)
            if fk then
                ns.ToggleFav(fk, fid)
                local onEnter = self:GetScript("OnEnter")
                if self.d and onEnter then onEnter(self) end
            end
            return
        end
        if IsModifiedClick() and d.item then
            local _, link = GetItemInfo(d.item)
            if link and HandleModifiedItemClick(link) then return end
        end
        if d.go then ns.Navigate(d.go) end
    end)
    return row
end
for i = 1, MAX_ROWS do
    rows[i] = {}
    for c = 1, MAX_COLS do rows[i][c] = MakeRow() end
end

scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateRows)
end)

ns.ui.scroll, ns.ui.rows = scroll, rows
ns.UpdateRows = UpdateRows
