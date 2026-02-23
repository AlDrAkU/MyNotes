-- MainPanel.lua
-- Creates and manages the main MyNotesClassic panel.

local E = MyNotesClassicAddon

local function Initialize()
    local notes = MyNotesClassicSavedNotes

    --------------------------------------------------------------------------
    -- Main Frame
    --------------------------------------------------------------------------
    local frame = CreateFrame("Frame", "MyNotesClassicFrame", UIParent, "BackdropTemplate")
    frame:SetBackdrop(E.GetBackdrop())
    frame:SetSize(MyNotesClassicSettings.width, MyNotesClassicSettings.height)
    frame:SetPoint(
        MyNotesClassicSettings.point, UIParent,
        MyNotesClassicSettings.relativePoint,
        MyNotesClassicSettings.x, MyNotesClassicSettings.y
    )
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        MyNotesClassicSettings.point         = point
        MyNotesClassicSettings.relativePoint = relativePoint
        MyNotesClassicSettings.x             = x
        MyNotesClassicSettings.y             = y
    end)

    if MyNotesClassicSettings.visible then frame:Show() else frame:Hide() end

    -- Auto-register/deregister the note input as the shift-click target so
    -- the user doesn't need to manually click the input box before shift-
    -- clicking an item in their bags.
    frame:SetScript("OnShow", function()
        MyNotesClassicSettings.visible = true
        if noteInput then E.SetFocusedEditBox(noteInput) end
    end)
    frame:SetScript("OnHide", function()
        MyNotesClassicSettings.visible = false
        if noteInput then E.ClearFocusedEditBox(noteInput) end
    end)

    -- Forward declarations so OnSizeChanged can safely reference them before
    -- the widgets are created further below.
    local noteInput, addNoteButton, refreshNotes

    frame:SetScript("OnSizeChanged", function(self, width, height)
        MyNotesClassicSettings.width  = width
        MyNotesClassicSettings.height = height
        if noteInput then noteInput:SetWidth(self:GetWidth() - 100) end
        -- Defer refreshNotes to the next frame so GetStringHeight() returns
        -- post-layout values; calling it synchronously here produces stale
        -- heights that cause note entries to visually overlap each other.
        if refreshNotes then C_Timer.After(0, refreshNotes) end
    end)

    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints()
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    bgTexture:SetVertexColor(0, 0, 0, E.transparencyEnabled and E.passiveAlpha or E.activeAlpha)

    frame:SetScript("OnUpdate", function(self)
        local alpha = E.activeAlpha
        if E.transparencyEnabled then
            alpha = self:IsMouseOver() and E.activeAlpha or E.passiveAlpha
        end
        bgTexture:SetVertexColor(0, 0, 0, alpha)
        if noteInput     then noteInput:SetAlpha(alpha)     end
        if addNoteButton then addNoteButton:SetAlpha(alpha) end
    end)

    --------------------------------------------------------------------------
    -- Settings Fold-out (shown above the main frame)
    --------------------------------------------------------------------------
    local settingsFrame = CreateFrame("Frame", "MyNotesClassicSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetBackdrop(E.GetBackdrop())
    settingsFrame:SetSize(frame:GetWidth(), 100)
    settingsFrame:SetPoint("BOTTOM", frame, "TOP", 0, -5)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:Hide()

    local settingsBg = settingsFrame:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints()
    settingsBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    settingsBg:SetVertexColor(0, 0, 0, E.activeAlpha)
    settingsFrame.bgTexture = settingsBg

    settingsFrame:SetScript("OnUpdate", function(self)
        local alpha = E.activeAlpha
        if E.transparencyEnabled then
            alpha = self:IsMouseOver() and E.activeAlpha or E.passiveAlpha
        end
        if self.bgTexture then self.bgTexture:SetVertexColor(0, 0, 0, alpha) end
    end)

    local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -5, -5)
    versionText:SetText("v" .. E.version)

    -- ── Row 1: Border Style cycle button ────────────────────────────────────
    local borderBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    borderBtn:SetSize(130, 20)
    borderBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, -8)
    do
        local fs = borderBtn:GetFontString()
        local font, size, flags = fs:GetFont()
        fs:SetFont(font, size - 2, flags)
    end
    local function updateBorderBtn()
        borderBtn:SetText("Border: " .. (E.BORDER_STYLES_LABELS[E.borderStyle] or "None"))
    end
    updateBorderBtn()
    borderBtn:SetScript("OnClick", function()
        local order = E.BORDER_STYLES_ORDER
        local cur = 1
        for i, k in ipairs(order) do
            if k == E.borderStyle then cur = i; break end
        end
        E.borderStyle = order[(cur % #order) + 1]
        MyNotesClassicSettings.borderStyle = E.borderStyle
        updateBorderBtn()
        E.ApplyBackdropToAll()
    end)

    -- ── Row 2: Transparency checkbox ────────────────────────────────────────
    local transparencyCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
    transparencyCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, -35)
    transparencyCheckbox.text = transparencyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    do
        local font, size, flags = transparencyCheckbox.text:GetFont()
        transparencyCheckbox.text:SetFont(font, size - 2, flags)
    end
    transparencyCheckbox.text:SetPoint("LEFT", transparencyCheckbox, "RIGHT", 2, 0)
    transparencyCheckbox.text:SetText("Transparency")
    transparencyCheckbox:SetChecked(E.transparencyEnabled)
    transparencyCheckbox:SetScript("OnClick", function(self)
        E.transparencyEnabled = self:GetChecked()
    end)

    -- ── Row 3: Font size controls ────────────────────────────────────────────
    local fontLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, -68)
    do
        local font, size, flags = fontLabel:GetFont()
        fontLabel:SetFont(font, size - 2, flags)
    end
    fontLabel:SetText("Font Size:")

    local fontDecBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    fontDecBtn:SetSize(20, 20)
    fontDecBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 80, -64)
    fontDecBtn:SetText("-")

    local fontDisplay = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontDisplay:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 105, -68)
    do
        local font, size, flags = fontDisplay:GetFont()
        fontDisplay:SetFont(font, size - 2, flags)
    end

    local fontIncBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    fontIncBtn:SetSize(20, 20)
    fontIncBtn:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 124, -64)
    fontIncBtn:SetText("+")

    local function updateFontDisplay()
        fontDisplay:SetText(tostring(E.noteFontSize))
    end
    updateFontDisplay()

    local function applyFontSize()
        MyNotesClassicSettings.noteFontSize = E.noteFontSize
        refreshNotes()
        for _, sd in ipairs(MyNotesClassicStickyNotes) do
            if sd.refresh then sd.refresh() end
        end
    end

    fontDecBtn:SetScript("OnClick", function()
        if E.noteFontSize > 8 then
            E.noteFontSize = E.noteFontSize - 1
            updateFontDisplay()
            applyFontSize()
        end
    end)
    fontIncBtn:SetScript("OnClick", function()
        if E.noteFontSize < 20 then
            E.noteFontSize = E.noteFontSize + 1
            updateFontDisplay()
            applyFontSize()
        end
    end)

    -- Options Button (toggles the settings fold-out)
    local optionsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsButton:SetSize(20, 20)
    optionsButton:SetText("=")
    optionsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    optionsButton:SetScript("OnClick", function()
        if settingsFrame:IsShown() then settingsFrame:Hide() else settingsFrame:Show() end
    end)

    -- Close Button
    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
            settingsFrame:Hide()
        end)
    end

    -- New Sticky Button
    local stickyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stickyButton:SetSize(70, 20)
    stickyButton:SetText("New Sticky")
    stickyButton:SetPoint("TOPRIGHT", frame.CloseButton, "TOPLEFT", -5, -5)
    do
        local fs = stickyButton:GetFontString()
        local font, size, flags = fs:GetFont()
        fs:SetFont(font, size - 2, flags)
    end
    stickyButton:SetScript("OnClick", function()
        CreateStickyNotePanel()
    end)

    --------------------------------------------------------------------------
    -- Notes Scroll Area
    --------------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     10,  -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30,  40)

    local notesContainer = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(notesContainer)
    notesContainer:SetSize(1, 1)

    local noteEntries = {}

    refreshNotes = function()
        for _, noteFrame in ipairs(noteEntries) do
            noteFrame:Hide()
            noteFrame:SetParent(nil)
        end
        noteEntries = {}

        local previousEntry = nil
        local totalHeight   = 0

        for i, note in ipairs(notes) do
            local noteEntry = CreateFrame("Frame", nil, notesContainer)
            noteEntry:SetWidth(scrollFrame:GetWidth() - 20)

            if previousEntry then
                noteEntry:SetPoint("TOPLEFT", previousEntry, "BOTTOMLEFT", 0, -5)
            else
                noteEntry:SetPoint("TOPLEFT", notesContainer, "TOPLEFT", 0, 0)
            end

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
                table.remove(notes, i)
                refreshNotes()
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

            table.insert(noteEntries, noteEntry)
            previousEntry = noteEntry
            totalHeight   = totalHeight + entryHeight + 5
        end

        notesContainer:SetHeight(totalHeight)
    end

    refreshNotes()

    --------------------------------------------------------------------------
    -- Input Box + Add Note Button
    --------------------------------------------------------------------------
    noteInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    noteInput:SetPoint("BOTTOM", frame, "BOTTOM", -40, 20)
    noteInput:SetHeight(25)
    noteInput:SetWidth(160)
    noteInput:SetAutoFocus(false)
    noteInput:SetText("")
    noteInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    noteInput:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            table.insert(notes, { text = text, done = false })
            refreshNotes()
            self:SetText("")
            self:ClearFocus()
        end
    end)
    noteInput:SetScript("OnEditFocusGained", function(self) E.SetFocusedEditBox(self) end)

    -- If the panel was already visible when the addon loaded, register now.
    if frame:IsVisible() then E.SetFocusedEditBox(noteInput) end

    addNoteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addNoteButton:SetSize(60, 25)
    addNoteButton:SetText("Add Note")
    do
        local fs = addNoteButton:GetFontString()
        local font, size, flags = fs:GetFont()
        fs:SetFont(font, size - 2, flags)
    end
    addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 140, -25)

    -- OnSizeChanged fires only when the frame SIZE CHANGES, not on the initial
    -- SetSize call during Initialize().  Manually correct both widgets now so
    -- a relog into large-mode looks right without needing a second resize click.
    noteInput:SetWidth(frame:GetWidth() - 100)
    if MyNotesClassicSettings.isLarge then
        addNoteButton:ClearAllPoints()
        addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 210, -25)
    end

    addNoteButton:SetScript("OnClick", function()
        local text = noteInput:GetText()
        if text and text ~= "" then
            table.insert(notes, { text = text, done = false })
            refreshNotes()
            noteInput:SetText("")
            noteInput:ClearFocus()
        end
    end)

    --------------------------------------------------------------------------
    -- Resize Handle (click to toggle between normal and 1.5x size)
    --------------------------------------------------------------------------
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnClick", function()
        if MyNotesClassicSettings.isLarge then
            frame:SetSize(300, 400)
            MyNotesClassicSettings.isLarge = false
            addNoteButton:ClearAllPoints()
            addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 140, -25)
        else
            frame:SetSize(450, 600)
            MyNotesClassicSettings.isLarge = true
            addNoteButton:ClearAllPoints()
            addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 210, -25)
        end
        -- refreshNotes is triggered by the C_Timer.After(0,...) in OnSizeChanged,
        -- which fires when SetSize is processed.  No explicit call needed here.
    end)

    --------------------------------------------------------------------------
    -- Toggle Button (anchored below the Minimap)
    --------------------------------------------------------------------------
    local toggleButton = CreateFrame("Button", "MyNotesClassicToggleButton", UIParent, "UIPanelButtonTemplate")
    toggleButton:SetSize(80, 22)
    toggleButton:SetText("MNClassic")
    if Minimap then
        toggleButton:SetPoint("TOP", Minimap, "BOTTOM", 0, -15)
    else
        toggleButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -115)
    end
    toggleButton:SetMovable(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", toggleButton.StartMoving)
    toggleButton:SetScript("OnDragStop",  toggleButton.StopMovingOrSizing)
    toggleButton:SetScript("OnClick", function()
        if frame:IsShown() then frame:Hide() else frame:Show() end
        if settingsFrame:IsShown() then settingsFrame:Hide() end
    end)
end

E.Initialize = Initialize
