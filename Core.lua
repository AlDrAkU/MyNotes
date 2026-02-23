-- Core.lua
-- MyNotesClassic v1.0.3
-- Shared module state, saved variable initialization, and addon bootstrap.

MyNotesClassicAddon = MyNotesClassicAddon or {}
local E = MyNotesClassicAddon

E.name    = "MyNotesClassic"
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
    if _G["MyNotesClassicFrame"]         then _G["MyNotesClassicFrame"]:SetBackdrop(bd)         end
    if _G["MyNotesClassicSettingsFrame"] then _G["MyNotesClassicSettingsFrame"]:SetBackdrop(bd) end
    for _, sd in ipairs(MyNotesClassicStickyNotes) do
        if sd.frame then sd.frame:SetBackdrop(bd) end
    end
end

--------------------------------------------------------------------------------
-- Saved Variable Defaults
--------------------------------------------------------------------------------
if not MyNotesClassicSavedNotes then
    MyNotesClassicSavedNotes = {}
end
if not MyNotesClassicStickyNotes then
    MyNotesClassicStickyNotes = {}
end
if not MyNotesClassicSettings then
    MyNotesClassicSettings = {
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
        hasRun          = false,   -- false on brand-new installs; triggers first-run hint
    }
end

-- Back-fill keys added in later versions so old saved data is never broken.
if MyNotesClassicSettings.visible         == nil then MyNotesClassicSettings.visible         = true  end
if MyNotesClassicSettings.showBorders     == nil then MyNotesClassicSettings.showBorders     = false  end
if MyNotesClassicSettings.borderStyle     == nil then
    MyNotesClassicSettings.borderStyle = MyNotesClassicSettings.showBorders and "dialog" or "none"
end
if MyNotesClassicSettings.noteFontSize    == nil then MyNotesClassicSettings.noteFontSize    = 12    end
if MyNotesClassicSettings.stickiesVisible == nil then MyNotesClassicSettings.stickiesVisible = true  end
-- Existing users upgrading from a version without hasRun should not see the
-- first-run hint, so back-fill to true for them.
if MyNotesClassicSettings.hasRun          == nil then MyNotesClassicSettings.hasRun          = true  end

--------------------------------------------------------------------------------
-- First-run migration from the old "MyNotes" addon.
-- MyNotesSavedNotes / MyNotesStickyNotes / MyNotesPanelSettings are also
-- declared in the TOC so that if the user copies their WTF SavedVariables file
--   WTF/.../SavedVariables/MyNotes.lua  →  MyNotesClassic.lua  (same folder)
-- WoW will load those globals here and the block below merges them once then
-- clears the originals so they are not re-imported on subsequent logins.
--------------------------------------------------------------------------------
local _migrationMsg
do
    local any = false

    if MyNotesSavedNotes and #MyNotesSavedNotes > 0
            and #MyNotesClassicSavedNotes == 0 then
        for _, v in ipairs(MyNotesSavedNotes) do
            table.insert(MyNotesClassicSavedNotes, v)
        end
        MyNotesSavedNotes = nil
        any = true
    end

    if MyNotesStickyNotes and #MyNotesStickyNotes > 0
            and #MyNotesClassicStickyNotes == 0 then
        for _, v in ipairs(MyNotesStickyNotes) do
            table.insert(MyNotesClassicStickyNotes, v)
        end
        MyNotesStickyNotes = nil
        any = true
    end

    if MyNotesPanelSettings then
        local src, dst = MyNotesPanelSettings, MyNotesClassicSettings
        for _, k in ipairs({ "point","relativePoint","x","y","width","height",
                              "isLarge","visible","stickiesVisible" }) do
            if src[k] ~= nil then dst[k] = src[k] end
        end
        MyNotesPanelSettings = nil
        any = true
    end

    if any then
        local n = #MyNotesClassicSavedNotes
        local s = #MyNotesClassicStickyNotes
        _migrationMsg = "|cff00ff00[MyNotesClassic]|r Imported "
                        .. n .. " note(s) and " .. s
                        .. " sticky/stickies from the old MyNotes addon."
    elseif not MyNotesClassicSettings.hasRun then
        _migrationMsg = "|cffaaaaaa[MyNotesClassic]|r First run."
                        .. "  Had old MyNotes data?  Type "
                        .. "|cffffd700/mynotesclassic import|r for import instructions."
    end

    MyNotesClassicSettings.hasRun = true
end

-- Mirror persisted settings into the module so all panels can read them.
-- Done AFTER migration so any migrated settings values are picked up here.
E.showBorders  = MyNotesClassicSettings.showBorders   -- kept for compat
E.borderStyle  = MyNotesClassicSettings.borderStyle
E.noteFontSize = MyNotesClassicSettings.noteFontSize

--------------------------------------------------------------------------------
-- Bootstrap: fires after all addon files are loaded.
--------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyNotesClassic" then
        E.Initialize()
        if _migrationMsg then print(_migrationMsg) end
        for _, stickyData in ipairs(MyNotesClassicStickyNotes) do
            CreateStickyNotePanel(stickyData)
        end
        -- Restore the stickies show/hide state from the previous session.
        if not MyNotesClassicSettings.stickiesVisible then
            for _, stickyData in ipairs(MyNotesClassicStickyNotes) do
                if stickyData.frame then stickyData.frame:Hide() end
            end
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
