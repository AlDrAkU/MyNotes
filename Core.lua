-- Core.lua
-- MyNotes v1.0.3
-- Shared module state, saved variable initialization, and addon bootstrap.

MyNotesAddon = MyNotesAddon or {}
local E = MyNotesAddon

E.name    = "MyNotes"
E.version = "1.0.3"

-- Transparency settings shared across all panels.
E.transparencyEnabled = false
E.activeAlpha         = 1.0
E.passiveAlpha        = 0.25

--------------------------------------------------------------------------------
-- Border style definitions
--------------------------------------------------------------------------------
local BORDER_STYLE_DATA = {
    none    = { edgeFile = nil,                                             edgeSize = 32 },
    dialog  = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",   edgeSize = 12 },
    tooltip = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",        edgeSize = 16 },
}
E.BORDER_STYLES_ORDER  = { "none", "dialog", "tooltip" }
E.BORDER_STYLES_LABELS = { none = "None", dialog = "Dialog", tooltip = "Tooltip" }

-- Returns the backdrop table that matches the current E.borderStyle.
-- Call this whenever creating or refreshing a panel backdrop.
function E.GetBackdrop()
    local style = BORDER_STYLE_DATA[E.borderStyle] or BORDER_STYLE_DATA.none
    return {
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = style.edgeFile,
        tile = true, tileSize = 32, edgeSize = style.edgeSize,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    }
end

-- Reapplies the current backdrop to every open panel (main, settings, stickies).
function E.ApplyBackdropToAll()
    local bd = E.GetBackdrop()
    if _G["MyNotesFrame"]         then _G["MyNotesFrame"]:SetBackdrop(bd)         end
    if _G["MyNotesSettingsFrame"] then _G["MyNotesSettingsFrame"]:SetBackdrop(bd) end
    for _, sd in ipairs(MyNotesStickyNotes) do
        if sd.frame then sd.frame:SetBackdrop(bd) end
    end
end

--------------------------------------------------------------------------------
-- Saved Variable Defaults
--------------------------------------------------------------------------------
if not MyNotesSavedNotes then
    MyNotesSavedNotes = {}
end
if not MyNotesStickyNotes then
    MyNotesStickyNotes = {}
end
if not MyNotesPanelSettings then
    MyNotesPanelSettings = {
        point           = "CENTER",
        relativePoint   = "CENTER",
        x               = 0,
        y               = 0,
        width           = 300,
        height          = 400,
        visible         = true,
        isLarge         = false,
        showBorders     = false,
        borderStyle     = "none",
        noteFontSize    = 12,
        stickiesVisible = true,
    }
end

-- Back-fill keys added in later versions so old saved data is never broken.
if MyNotesPanelSettings.visible         == nil then MyNotesPanelSettings.visible         = true  end
if MyNotesPanelSettings.showBorders     == nil then MyNotesPanelSettings.showBorders     = false  end
if MyNotesPanelSettings.borderStyle     == nil then
    -- Migrate old boolean showBorders to the new string key.
    MyNotesPanelSettings.borderStyle = MyNotesPanelSettings.showBorders and "dialog" or "none"
end
if MyNotesPanelSettings.noteFontSize    == nil then MyNotesPanelSettings.noteFontSize    = 12    end
if MyNotesPanelSettings.stickiesVisible == nil then MyNotesPanelSettings.stickiesVisible = true  end

-- Mirror persisted settings into the module so all panels can read them.
E.showBorders  = MyNotesPanelSettings.showBorders   -- kept for compat
E.borderStyle  = MyNotesPanelSettings.borderStyle
E.noteFontSize = MyNotesPanelSettings.noteFontSize

--------------------------------------------------------------------------------
-- Bootstrap: fires after all addon files are loaded.
--------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyNotes" then
        E.Initialize()
        for _, stickyData in ipairs(MyNotesStickyNotes) do
            CreateStickyNotePanel(stickyData)
        end
        -- Restore the stickies show/hide state from the previous session.
        if not MyNotesPanelSettings.stickiesVisible then
            for _, stickyData in ipairs(MyNotesStickyNotes) do
                if stickyData.frame then stickyData.frame:Hide() end
            end
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
