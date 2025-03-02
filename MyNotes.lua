-- MyNotes.lua
-- Version: 1.1 
-- This addon creates an in-game notes panel (MyNotes) with transparency options,
-- a resizable main panel that supports notes via a standard input box, and a “New Sticky” button
-- that creates a simplified sticky note panel (using the standard input box) for reminders.
-- All notes (main notes and sticky notes) and the main panel’s position/size/visibility are saved
-- in global tables.
--
-- SavedVariables:
--    MyNotesSavedNotes, MyNotesStickyNotes, MyNotesPanelSettings
--

local E = {}
E.name = "MyNotes"
E.version = "1.0.1"

-- Global transparency settings.
local transparencyEnabled = false
local activeAlpha = 1.0
local passiveAlpha = 0.25

--------------------------------------------------------------------------------
-- Ensure Saved Variables exist (account-wide)
--------------------------------------------------------------------------------
if not MyNotesSavedNotes then
    MyNotesSavedNotes = {}   -- Array of note objects: { text = <string>, done = <bool> }
end
if not MyNotesStickyNotes then
    MyNotesStickyNotes = {}  -- Array of sticky note data tables.
end
if not MyNotesPanelSettings then
    MyNotesPanelSettings = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 300,
        height = 400,
        visible = true,   -- Whether the main panel was visible last time.
        isLarge = false,  -- For toggling between regular and 1.5x size
        showBorders = false,  -- New option: default off
    }
end
if MyNotesPanelSettings.visible == nil then
    MyNotesPanelSettings.visible = true
end
if MyNotesPanelSettings.showBorders == nil then
    MyNotesPanelSettings.showBorders = false
end

local showBorders = MyNotesPanelSettings.showBorders

--------------------------------------------------------------------------------
-- Main Panel Initialization (Notes)
--------------------------------------------------------------------------------
local function Initialize()
    local notes = MyNotesSavedNotes 

    ----------------------------------------------------------------------------
    -- Create the MyNotes Main Panel
    ----------------------------------------------------------------------------
    local frame = CreateFrame("Frame", "MyNotesFrame", UIParent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetSize(MyNotesPanelSettings.width, MyNotesPanelSettings.height)
    frame:SetPoint(MyNotesPanelSettings.point, UIParent, MyNotesPanelSettings.relativePoint, MyNotesPanelSettings.x, MyNotesPanelSettings.y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        MyNotesPanelSettings.point = point
        MyNotesPanelSettings.relativePoint = relativePoint
        MyNotesPanelSettings.x = x
        MyNotesPanelSettings.y = y
    end)
    if MyNotesPanelSettings.visible then
        frame:Show()
    else
        frame:Hide()
    end

    -- Save panel visibility state when shown or hidden:
    frame:SetScript("OnShow", function(self)
        MyNotesPanelSettings.visible = true
    end)
    frame:SetScript("OnHide", function(self)
        MyNotesPanelSettings.visible = false
    end)

    frame:SetScript("OnSizeChanged", function(self, width, height)
        MyNotesPanelSettings.width = width
        MyNotesPanelSettings.height = height
        if noteInput then
            noteInput:SetWidth(self:GetWidth() - 100)
        end
        if refreshNotes then refreshNotes() end
    end)

    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints()
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    if transparencyEnabled then
        bgTexture:SetVertexColor(0, 0, 0, passiveAlpha)
    else
        bgTexture:SetVertexColor(0, 0, 0, activeAlpha)
    end
    frame:SetScript("OnUpdate", function(self, elapsed)
        local newAlpha = activeAlpha
        if transparencyEnabled then
            newAlpha = self:IsMouseOver() and activeAlpha or passiveAlpha
        end
        bgTexture:SetVertexColor(0, 0, 0, newAlpha)
        if noteInput then noteInput:SetAlpha(newAlpha) end
        if addNoteButton then addNoteButton:SetAlpha(newAlpha) end
    end)

    ----------------------------------------------------------------------------
    -- Fold-out Settings Menu (above the main panel)
    ----------------------------------------------------------------------------
    local settingsFrame = CreateFrame("Frame", "MyNotesSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    settingsFrame:SetSize(frame:GetWidth(), 60)  -- Increased height to fit two options
    settingsFrame:SetPoint("BOTTOM", frame, "TOP", 0, -5)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:Hide()

    -- Add a background texture so the settings panel also obeys transparency:
    local settingsBg = settingsFrame:CreateTexture(nil, "BACKGROUND")
    settingsBg:SetAllPoints()
    settingsBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    settingsBg:SetVertexColor(0, 0, 0, activeAlpha)
    settingsFrame.bgTexture = settingsBg

    settingsFrame:SetScript("OnUpdate", function(self, elapsed)
        local newAlpha = activeAlpha
        if transparencyEnabled then
            newAlpha = self:IsMouseOver() and activeAlpha or passiveAlpha
        end
        if self.bgTexture then
            self.bgTexture:SetVertexColor(0, 0, 0, newAlpha)
        end
    end)

    local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -5, -5)
    versionText:SetText("v" .. E.version)

    ----------------------------------------------------------------------------
    -- New: Borders Checkbox (moved 10px lower)
    ----------------------------------------------------------------------------
    local bordersCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
    bordersCheckbox:SetPoint("LEFT", settingsFrame, "LEFT", 10, 10)  -- was (10,20); now 10px lower
    bordersCheckbox.text = bordersCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    do
        local font, size, flags = bordersCheckbox.text:GetFont()
        bordersCheckbox.text:SetFont(font, size - 2, flags)
    end
    bordersCheckbox.text:SetPoint("LEFT", bordersCheckbox, "RIGHT", 5, 0)
    bordersCheckbox.text:SetText("Show Borders")
    bordersCheckbox:SetChecked(showBorders)
    bordersCheckbox:SetScript("OnClick", function(self)
        showBorders = self:GetChecked()
        MyNotesPanelSettings.showBorders = showBorders
        -- Update main panel backdrop:
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
            tile = true, tileSize = 32, edgeSize = 12,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        -- Update settings frame backdrop:
        settingsFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
            tile = true, tileSize = 32, edgeSize = 12,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        -- Update all existing sticky note panels:
        for _, stickyData in ipairs(MyNotesStickyNotes) do
            if stickyData.frame then
                stickyData.frame:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
                    tile = true, tileSize = 32, edgeSize = 12,
                    insets = { left = 5, right = 5, top = 5, bottom = 5 }
                })
            end
        end
    end)

    ----------------------------------------------------------------------------
    -- Existing: Transparency Checkbox (moved 10px lower)
    ----------------------------------------------------------------------------
    local transparencyCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
    transparencyCheckbox:SetPoint("LEFT", settingsFrame, "LEFT", 10, -10)  -- was (10,0); now 10px lower
    transparencyCheckbox.text = transparencyCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    do
        local font, size, flags = transparencyCheckbox.text:GetFont()
        transparencyCheckbox.text:SetFont(font, size - 2, flags)
    end
    transparencyCheckbox.text:SetPoint("LEFT", transparencyCheckbox, "RIGHT", 5, 0)
    transparencyCheckbox.text:SetText("Enable Transparency")
    transparencyCheckbox:SetChecked(transparencyEnabled)
    transparencyCheckbox:SetScript("OnClick", function(self)
        transparencyEnabled = self:GetChecked()
    end)

    ----------------------------------------------------------------------------
    -- Options Button (toggles the settings fold)
    ----------------------------------------------------------------------------
    local optionsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsButton:SetSize(20, 20)
    optionsButton:SetText("=")
    optionsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    optionsButton:SetScript("OnClick", function()
        if settingsFrame:IsShown() then
            settingsFrame:Hide()
        else
            settingsFrame:Show()
        end
    end)
    ---------------------------------------------------------------------------
    -- Close Button
    ---------------------------------------------------------------------------
    if not frame.CloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 5)
        frame.CloseButton:SetScript("OnClick", function()
            frame:Hide()
            settingsFrame:Hide()
        end)
    end
    ----------------------------------------------------------------------------
    -- "New Sticky" Button (5 pixels up relative to Close button)
    ----------------------------------------------------------------------------
    local stickyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stickyButton:SetSize(70, 20)
    stickyButton:SetText("New Sticky")
    stickyButton:SetPoint("TOPRIGHT", frame.CloseButton, "TOPLEFT", -5, -5)
    do
        local fontString = stickyButton:GetFontString()
        local font, size, flags = fontString:GetFont()
        fontString:SetFont(font, size - 2, flags)
    end
    stickyButton:SetScript("OnClick", function()
        CreateStickyNotePanel()
    end)

    ----------------------------------------------------------------------------
    -- Main Panel Notes Area (ScrollFrame)
    ----------------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)
    local notesContainer = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(notesContainer)
    notesContainer:SetSize(1, 1)
    local noteEntries = {}
    local function refreshNotes()
        for _, noteFrame in ipairs(noteEntries) do
            noteFrame:Hide()
            noteFrame:SetParent(nil)
        end
        noteEntries = {}
        local previousEntry = nil
        local totalHeight = 0
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
            noteLabel:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
            noteLabel:SetPoint("RIGHT", noteEntry, "RIGHT", -35, 0)
            noteLabel:SetJustifyH("LEFT")
            noteLabel:SetWordWrap(true)
            noteLabel:SetText(note.text)
            if note.done then
                noteLabel:SetTextColor(0.5, 0.5, 0.5)
            else
                noteLabel:SetTextColor(1, 1, 1)
            end
            checkbox:SetScript("OnClick", function(self)
                note.done = self:GetChecked()
                if note.done then
                    noteLabel:SetTextColor(0.5, 0.5, 0.5)
                else
                    noteLabel:SetTextColor(1, 1, 1)
                end
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
            noteEntry:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(note.text, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            noteEntry:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            local labelHeight = noteLabel:GetStringHeight() or 0
            local entryHeight = math.max(25, labelHeight + 10)
            noteEntry:SetHeight(entryHeight)
            table.insert(noteEntries, noteEntry)
            previousEntry = noteEntry
            totalHeight = totalHeight + entryHeight + 5
        end
        notesContainer:SetHeight(totalHeight)
    end
    refreshNotes()

    ----------------------------------------------------------------------------
    -- Main Panel Input Box and Add Note Button
    ----------------------------------------------------------------------------
    noteInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    noteInput:SetPoint("BOTTOM", frame, "BOTTOM", -40, 20)
    noteInput:SetHeight(25)
    noteInput:SetWidth(160)
    noteInput:SetAutoFocus(false)
    noteInput:SetText("")
    noteInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    addNoteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addNoteButton:SetSize(60, 25)
    addNoteButton:SetText("Add Note")
    do
        local fontString = addNoteButton:GetFontString()
        local font, size, flags = fontString:GetFont()
        fontString:SetFont(font, size - 2, flags)
    end
    addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 140, -25)
    addNoteButton:SetScript("OnClick", function()
        local noteText = noteInput:GetText()
        if noteText and noteText ~= "" then
            table.insert(notes, { text = noteText, done = false })
            refreshNotes()
            noteInput:SetText("")
            noteInput:ClearFocus()
        end
    end)

    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:EnableMouse(true)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnClick", function()
        if MyNotesPanelSettings.isLarge then
            frame:SetSize(300, 400)
            MyNotesPanelSettings.isLarge = false
            addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 140, -25)
            refreshNotes()
        else
            frame:SetSize(450, 600)
            MyNotesPanelSettings.isLarge = true
            addNoteButton:SetPoint("BOTTOM", noteInput, "TOP", 210, -25)
            refreshNotes()
        end
    end)
    ----------------------------------------------------------------------------
    -- Toggle Button for Main Panel
    ----------------------------------------------------------------------------
    local toggleButton = CreateFrame("Button", "MyNotesToggleButton", UIParent, "UIPanelButtonTemplate")
    toggleButton:SetSize(80, 22)
    toggleButton:SetText("MyNotes")
    if Minimap then
        toggleButton:SetPoint("TOP", Minimap, "BOTTOM", 0, -15)
    else
        toggleButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -115)
    end
    toggleButton:SetMovable(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", toggleButton.StartMoving)
    toggleButton:SetScript("OnDragStop", toggleButton.StopMovingOrSizing)
    toggleButton:SetScript("OnClick", function()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
        if settingsFrame:IsShown() then
            settingsFrame:Hide()
        end
    end)
end

E.Initialize = Initialize
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyNotes" then
        E.Initialize()
        for _, stickyData in ipairs(MyNotesStickyNotes) do
            CreateStickyNotePanel(stickyData)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

---------------------------------------------------------------------------
-- Sticky Note Functionality (Simplified Clone of Main Panel)
---------------------------------------------------------------------------
function CreateStickyNotePanel(existingStickyData)
    local stickyData = existingStickyData
    if not stickyData then
        stickyData = { id = "StickyNote" .. math.random(1000000), notes = {}, isLarge = false, collapsed = false }
        table.insert(MyNotesStickyNotes, stickyData)
    end

    local sticky = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    sticky:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = showBorders and "Interface\\DialogFrame\\UI-DialogBox-Border" or nil,
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    sticky:SetSize(250, 200)
    sticky:SetClampedToScreen(true)
    if stickyData.savedPoint then
        sticky:SetPoint(stickyData.savedPoint.point, UIParent, stickyData.savedPoint.relativePoint, stickyData.savedPoint.x, stickyData.savedPoint.y)
    else
        sticky:SetPoint("CENTER", UIParent, "CENTER", math.random(-200,200), math.random(-200,200))
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
    sticky:HookScript("OnMouseDown", function(self)
        sticky.titleEdit:ClearFocus()
    end)

    local bgTexture = sticky:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints()
    bgTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")

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
        sticky:Hide()
        sticky:SetParent(nil)
    end)

    ----------------------------------------------------------------------------
    -- Sticky Note Title Bar
    ----------------------------------------------------------------------------
    local titleEdit = CreateFrame("EditBox", nil, sticky, "InputBoxTemplate")
    titleEdit:SetPoint("TOPLEFT", sticky, "TOPLEFT", 25, 0)
    titleEdit:SetPoint("TOPRIGHT", sticky, "TOPRIGHT", -75, 0)
    titleEdit:SetHeight(20)
    titleEdit:SetAutoFocus(false)
    titleEdit:SetText(stickyData.title or "Sticky Note")
    titleEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    titleEdit:SetScript("OnEnterPressed", function(self)
        stickyData.title = self:GetText()
        self:ClearFocus()
    end)
    titleEdit:SetScript("OnEditFocusLost", function(self)
        stickyData.title = self:GetText()
    end)
    sticky.titleEdit = titleEdit

    ----------------------------------------------------------------------------
    -- Sticky Note Content Area (ScrollFrame)
    ----------------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, sticky, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", sticky, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", sticky, "BOTTOMRIGHT", -30, 40)
    local notesContainer = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(notesContainer)
    notesContainer:SetSize(1, 1)

    local function refreshStickyNotes()
        for _, child in ipairs({ notesContainer:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
    
        local totalHeight = 0
        for i, note in ipairs(stickyData.notes) do
            local noteEntry = CreateFrame("Frame", nil, notesContainer)
            noteEntry:SetWidth(scrollFrame:GetWidth() - 20)
            if i == 1 then
                noteEntry:SetPoint("TOPLEFT", notesContainer, "TOPLEFT", 0, 0)
            else
                noteEntry:SetPoint("TOPLEFT", notesContainer:GetChildren()[i-1] or notesContainer, "BOTTOMLEFT", 0, -5)
            end
            local checkbox = CreateFrame("CheckButton", nil, noteEntry, "UICheckButtonTemplate")
            checkbox:SetSize(20, 20)
            checkbox:SetPoint("LEFT", noteEntry, "LEFT", 5, 0)
            checkbox:SetChecked(note.done)
            local noteLabel = noteEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noteLabel:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
            noteLabel:SetPoint("RIGHT", noteEntry, "RIGHT", -35, 0)
            noteLabel:SetJustifyH("LEFT")
            noteLabel:SetWordWrap(true)
            noteLabel:SetText(note.text)
            if note.done then
                noteLabel:SetTextColor(0.5, 0.5, 0.5)
            else
                noteLabel:SetTextColor(1, 1, 1)
            end
            checkbox:SetScript("OnClick", function(self)
                note.done = self:GetChecked()
                if note.done then
                    noteLabel:SetTextColor(0.5, 0.5, 0.5)
                else
                    noteLabel:SetTextColor(1, 1, 1)
                end
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
            noteEntry:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(note.text, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            noteEntry:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            local labelHeight = noteLabel:GetStringHeight() or 0
            local entryHeight = math.max(25, labelHeight + 10)
            noteEntry:SetHeight(entryHeight)
            totalHeight = totalHeight + entryHeight + 5
            noteEntry:SetPoint("TOPLEFT", notesContainer, "TOPLEFT", 0, -totalHeight + entryHeight + 5)
            noteEntry:Show()
        end
        notesContainer:SetHeight(totalHeight)
    end
    refreshStickyNotes()

    ----------------------------------------------------------------------------
    -- Discrete resize handle: toggles size between 250×200 and 375×300.
    ----------------------------------------------------------------------------
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
            refreshStickyNotes()
        else
            sticky:SetSize(375, 300)
            stickyData.isLarge = true
            refreshStickyNotes()
        end
    end)
    ----------------------------------------------------------------------------
    -- Sticky Note Input and Add Button
    ----------------------------------------------------------------------------
    local stickyInput = CreateFrame("EditBox", nil, sticky, "InputBoxTemplate")
    stickyInput:SetPoint("BOTTOM", sticky, "BOTTOM", -5, 10)
    stickyInput:SetHeight(25)
    stickyInput:SetWidth(sticky:GetWidth() - 80)
    stickyInput:SetAutoFocus(false)
    stickyInput:SetText("")
    stickyInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
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
    sticky:SetScript("OnUpdate", function(self, elapsed)
        local newAlpha = activeAlpha
        if transparencyEnabled then
            newAlpha = self:IsMouseOver() and activeAlpha or passiveAlpha
        end
        if self.bgTexture then
            self.bgTexture:SetVertexColor(0, 0, 0, newAlpha)
        end
    end)
    sticky:SetScript("OnSizeChanged", function(self, width, height)
        if stickyInput then
            stickyInput:SetWidth(self:GetWidth() - 40)
        end
    end)
    
    sticky.noteID = stickyData.id
    stickyData.frame = sticky
    return sticky
end

-- Global Stickies Toggle Button to show/hide all sticky notes.
local stickyToggleButton = CreateFrame("Button", "StickyNotesToggleButton", UIParent, "UIPanelButtonTemplate")
stickyToggleButton:SetSize(60, 22)
stickyToggleButton:SetText("Stickies")
stickyToggleButton:EnableMouse(true)
stickyToggleButton:SetMovable(true)
stickyToggleButton:RegisterForDrag("LeftButton")
stickyToggleButton:SetScript("OnDragStart", stickyToggleButton.StartMoving)
stickyToggleButton:SetScript("OnDragStop", stickyToggleButton.StopMovingOrSizing)
stickyToggleButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -140)
stickyToggleButton:SetScript("OnClick", function()
    for i, stickyData in ipairs(MyNotesStickyNotes) do
        if stickyData.frame then
            if stickyData.frame:IsShown() then
                stickyData.frame:Hide()
            else
                stickyData.frame:Show()
            end
        end
    end
end)
