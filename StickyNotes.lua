-- StickyNotes.lua
-- Sticky note panel creation, management, and global show/hide toggle.

local E = MyNotesAddon

function CreateStickyNotePanel(existingStickyData)
    local stickyData = existingStickyData
    if not stickyData then
        stickyData = {
            id        = "StickyNote" .. math.random(1000000),
            notes     = {},
            isLarge   = false,
            collapsed = false,
        }
        table.insert(MyNotesStickyNotes, stickyData)
    end

    local sticky = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    sticky:SetBackdrop(E.GetBackdrop())
    sticky:SetSize(250, 200)
    sticky:SetClampedToScreen(true)

    if stickyData.savedPoint then
        sticky:SetPoint(
            stickyData.savedPoint.point, UIParent,
            stickyData.savedPoint.relativePoint,
            stickyData.savedPoint.x, stickyData.savedPoint.y
        )
    else
        sticky:SetPoint("CENTER", UIParent, "CENTER",
                        math.random(-200, 200), math.random(-200, 200))
    end

    sticky:EnableMouse(true)
    sticky:RegisterForDrag("LeftButton")
    sticky:SetMovable(true)
    if sticky.SetResizable then
        sticky:SetResizable(true)
    else
        sticky.isResizable = true
    end
    sticky:SetScript("OnDragStart", sticky.StartMoving)
    sticky:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        stickyData.savedPoint = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    sticky:HookScript("OnMouseDown", function()
        sticky.titleEdit:ClearFocus()
    end)

    local bgTexture = sticky:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints()
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")

    -- Close Button
    if sticky.CloseButton then sticky.CloseButton:Hide() end
    local closeButton = CreateFrame("Button", nil, sticky, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", sticky, "TOPRIGHT", 5, 5)
    closeButton:SetScript("OnClick", function()
        for i, data in ipairs(MyNotesStickyNotes) do
            if data.id == stickyData.id then
                table.remove(MyNotesStickyNotes, i)
                break
            end
        end
        -- If this sticky's input was the shift-click target, clear it.
        E.focusedEditBox = nil
        sticky:Hide()
        sticky:SetParent(nil)
    end)

    --------------------------------------------------------------------------
    -- Title EditBox
    --------------------------------------------------------------------------
    local titleEdit = CreateFrame("EditBox", nil, sticky, "InputBoxTemplate")
    titleEdit:SetPoint("TOPLEFT",  sticky, "TOPLEFT",   25,   0)
    titleEdit:SetPoint("TOPRIGHT", sticky, "TOPRIGHT", -75,   0)
    titleEdit:SetHeight(20)
    titleEdit:SetAutoFocus(false)
    titleEdit:SetText(stickyData.title or "Sticky Note")
    titleEdit:SetScript("OnEscapePressed",  function(self) self:ClearFocus() end)
    titleEdit:SetScript("OnEnterPressed",   function(self) stickyData.title = self:GetText(); self:ClearFocus() end)
    titleEdit:SetScript("OnEditFocusLost",  function(self) stickyData.title = self:GetText() end)
    sticky.titleEdit = titleEdit

    --------------------------------------------------------------------------
    -- Notes Scroll Area
    --------------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, sticky, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     sticky, "TOPLEFT",     10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", sticky, "BOTTOMRIGHT", -30,  40)

    local notesContainer = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(notesContainer)
    notesContainer:SetSize(1, 1)

    local function refreshStickyNotes()
        for _, child in ipairs({ notesContainer:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        local offsetY = 0
        for i, note in ipairs(stickyData.notes) do
            local noteEntry = CreateFrame("Frame", nil, notesContainer)
            noteEntry:SetWidth(scrollFrame:GetWidth() - 20)
            noteEntry:SetPoint("TOPLEFT", notesContainer, "TOPLEFT", 0, -offsetY)

            local checkbox = CreateFrame("CheckButton", nil, noteEntry, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", noteEntry, "LEFT", 5, 0)
            checkbox:SetChecked(note.done)

            local noteLabel = noteEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noteLabel:SetPoint("LEFT",  checkbox,  "RIGHT",   5,   0)
            noteLabel:SetPoint("RIGHT", noteEntry, "RIGHT",  -35,  0)
            noteLabel:SetJustifyH("LEFT")
            noteLabel:SetWordWrap(true)
            -- Apply user font size
            do
                local font, _, flags = noteLabel:GetFont()
                noteLabel:SetFont(font, E.noteFontSize, flags)
            end
            noteLabel:SetText(note.text)
            -- SetAlpha dims the whole label including embedded |c color codes in
            -- item links, so linked items gray out correctly when marked done.
            noteLabel:SetAlpha(note.done and 0.45 or 1.0)

            checkbox:SetScript("OnClick", function(self)
                note.done = self:GetChecked()
                noteLabel:SetAlpha(note.done and 0.45 or 1.0)
            end)

            local delButton = CreateFrame("Button", nil, noteEntry, "UIPanelButtonTemplate")
            delButton:SetSize(25, 20)
            delButton:SetText("-")
            delButton:GetFontString():SetFont(delButton:GetFontString():GetFont(), 12, "OUTLINE")
            delButton:SetPoint("RIGHT", noteEntry, "RIGHT", -5, 0)
            delButton:SetScript("OnClick", function()
                table.remove(stickyData.notes, i)
                refreshStickyNotes()
            end)

            -- Show item tooltip when the note contains an item link;
            -- otherwise show the note text as before.
            noteEntry:SetScript("OnEnter", function(self)
                local hyperlink = E.GetHyperlinkFromText(note.text)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if hyperlink then
                    GameTooltip:SetHyperlink(hyperlink)
                else
                    GameTooltip:SetText(note.text, 1, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end)
            noteEntry:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local labelHeight = noteLabel:GetStringHeight() or 0
            local entryHeight = math.max(25, labelHeight + 10)
            noteEntry:SetHeight(entryHeight)
            noteEntry:Show()

            offsetY = offsetY + entryHeight + 5
        end

        notesContainer:SetHeight(offsetY)
    end

    refreshStickyNotes()

    -- Expose the refresh function so the font-size slider can trigger it.
    stickyData.refresh = refreshStickyNotes

    --------------------------------------------------------------------------
    -- Resize Handle (click to toggle between 250×200 and 375×300)
    --------------------------------------------------------------------------
    local resizeHandle = CreateFrame("Button", nil, sticky)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", sticky, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnClick", function()
        if stickyData.isLarge then
            sticky:SetSize(250, 200)
            stickyData.isLarge = false
        else
            sticky:SetSize(375, 300)
            stickyData.isLarge = true
        end
        refreshStickyNotes()
    end)

    --------------------------------------------------------------------------
    -- Input Box + Add Button
    --------------------------------------------------------------------------
    local stickyInput = CreateFrame("EditBox", nil, sticky, "InputBoxTemplate")
    stickyInput:SetPoint("BOTTOM", sticky, "BOTTOM", -5, 10)
    stickyInput:SetHeight(25)
    stickyInput:SetWidth(sticky:GetWidth() - 80)
    stickyInput:SetAutoFocus(false)
    stickyInput:SetText("")
    stickyInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    stickyInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            table.insert(stickyData.notes, { text = text, done = false })
            refreshStickyNotes()
            self:SetText("")
            self:ClearFocus()
        end
    end)
    stickyInput:SetScript("OnEditFocusGained", function(self) E.SetFocusedEditBox(self) end)

    local stickyAddButton = CreateFrame("Button", nil, sticky, "UIPanelButtonTemplate")
    stickyAddButton:SetSize(60, 20)
    stickyAddButton:SetText("Add")
    stickyAddButton:SetPoint("BOTTOM", stickyInput, "TOP", 0, 5)
    stickyAddButton:SetScript("OnClick", function()
        local text = stickyInput:GetText()
        if text and text ~= "" then
            table.insert(stickyData.notes, { text = text, done = false })
            refreshStickyNotes()
            stickyInput:SetText("")
            stickyInput:ClearFocus()
        end
    end)

    sticky.bgTexture = bgTexture
    sticky:SetScript("OnUpdate", function(self)
        local alpha = E.activeAlpha
        if E.transparencyEnabled then
            alpha = self:IsMouseOver() and E.activeAlpha or E.passiveAlpha
        end
        if self.bgTexture then self.bgTexture:SetVertexColor(0, 0, 0, alpha) end
    end)
    sticky:SetScript("OnSizeChanged", function(self, width)
        if stickyInput then stickyInput:SetWidth(width - 40) end
    end)

    sticky.noteID    = stickyData.id
    stickyData.frame = sticky
    return sticky
end

--------------------------------------------------------------------------------
-- Global toggle button to show/hide all open sticky notes.
-- Saves the visibility state so it persists across sessions.
--------------------------------------------------------------------------------
local stickyToggleButton = CreateFrame("Button", "StickyNotesToggleButton", UIParent, "UIPanelButtonTemplate")
stickyToggleButton:SetSize(60, 22)
stickyToggleButton:SetText("Stickies")
stickyToggleButton:EnableMouse(true)
stickyToggleButton:SetMovable(true)
stickyToggleButton:RegisterForDrag("LeftButton")
stickyToggleButton:SetScript("OnDragStart", stickyToggleButton.StartMoving)
stickyToggleButton:SetScript("OnDragStop",  stickyToggleButton.StopMovingOrSizing)
stickyToggleButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -140)
stickyToggleButton:SetScript("OnClick", function()
    -- Determine the new state by checking if any sticky is currently shown.
    local anyShown = false
    for _, stickyData in ipairs(MyNotesStickyNotes) do
        if stickyData.frame and stickyData.frame:IsShown() then
            anyShown = true
            break
        end
    end
    local newVisible = not anyShown
    for _, stickyData in ipairs(MyNotesStickyNotes) do
        if stickyData.frame then
            if newVisible then stickyData.frame:Show() else stickyData.frame:Hide() end
        end
    end
    -- Persist so the same state is restored on next login.
    MyNotesPanelSettings.stickiesVisible = newVisible
end)
