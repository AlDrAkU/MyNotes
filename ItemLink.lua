-- ItemLink.lua
-- Allows shift-clicking items to insert their links into a focused MyNotes
-- edit box.  When a saved note contains an item link, hovering over it shows
-- the item's full tooltip so you can inspect stats without opening the bag.

local E = MyNotesAddon

E.focusedEditBox = nil
E.debugMode      = false

function E.SetFocusedEditBox(editBox)
    E.focusedEditBox = editBox
end

function E.ClearFocusedEditBox(editBox)
    if E.focusedEditBox == editBox then
        E.focusedEditBox = nil
    end
end

-- Returns the WoW hyperlink payload inside a string (e.g. "item:1234:0:0:0…").
function E.GetHyperlinkFromText(text)
    return text:match("|H([^|]+)|h")
end

--------------------------------------------------------------------------
-- Shared insert helper.  Returns true if the link was written so callers
-- can deduplicate when multiple hooks are active.
--------------------------------------------------------------------------
local function tryInsertLink(link)
    if not link                          then return false end
    if not E.focusedEditBox              then return false end
    if not E.focusedEditBox:IsVisible()  then return false end
    local cur = E.focusedEditBox:GetText()
    E.focusedEditBox:SetText(cur == "" and link or (cur .. link))
    return true
end

local lastInsertTime = 0  -- dedup guard shared across hooks

--------------------------------------------------------------------------
-- Hook 1: ChatFrameUtil.InsertLink  ← THE real API in Classic 1.15.x
--
-- In Classic Era 1.15.x (interface 11507) Blizzard replaced the old
-- ChatEdit_InsertLink global with ChatFrameUtil.InsertLink.  This is a
-- table-method hook so the syntax is hooksecurefunc(table, "method", fn).
-- AtlasLoot itself calls this same function in Button:AddChatLink().
--------------------------------------------------------------------------
if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link)
        if E.debugMode then
            print("[MyNotes] ChatFrameUtil.InsertLink fired | link=" .. tostring(link)
                  .. " | focused=" .. tostring(E.focusedEditBox))
        end
        if tryInsertLink(link) then
            lastInsertTime = GetTime()
        end
    end)
else
    print("|cffff4444[MyNotes]|r ChatFrameUtil.InsertLink not found – link hook inactive.")
end

--------------------------------------------------------------------------
-- Hook 2: ChatEdit_InsertLink  (old-style global, present in older clients)
-- Kept as a fallback.  Dedup prevents double-insertion if both fire.
--------------------------------------------------------------------------
if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if E.debugMode then
            print("[MyNotes] ChatEdit_InsertLink fired | link=" .. tostring(link))
        end
        if GetTime() - lastInsertTime < 0.1 then return end  -- already handled
        if tryInsertLink(link) then
            lastInsertTime = GetTime()
        end
    end)
end

--------------------------------------------------------------------------
-- Hook 3: ContainerFrameItemButton_OnModifiedClick  (bag-button fallback)
-- Some Classic builds call this directly without going through either
-- of the two functions above.
--------------------------------------------------------------------------
if ContainerFrameItemButton_OnModifiedClick then
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self)
        if not IsShiftKeyDown() then return end
        if GetTime() - lastInsertTime < 0.1 then return end
        if E.debugMode then
            print("[MyNotes] ContainerFrameItemButton_OnModifiedClick fired")
        end
        local bagID  = self:GetParent():GetID()
        local slotID = self:GetID()
        local link
        if C_Container and C_Container.GetContainerItemLink then
            link = C_Container.GetContainerItemLink(bagID, slotID)
        elseif GetContainerItemLink then
            link = GetContainerItemLink(bagID, slotID)
        end
        if tryInsertLink(link) then
            lastInsertTime = GetTime()
        end
    end)
end

--------------------------------------------------------------------------
-- Slash commands  /mynotes <sub-command>
--   debug      – print current state
--   debug on   – verbose prints on every hook fire
--   debug off  – disable verbose prints
--   test       – inject a dummy link directly (bypasses all hooks)
--------------------------------------------------------------------------
SLASH_MYNOTES1 = "/mynotes"
SlashCmdList["MYNOTES"] = function(msg)
    msg = msg and msg:lower() or ""

    if msg == "debug on" then
        E.debugMode = true
        print("|cff00ff00[MyNotes]|r Debug ON – shift-click an item to see output.")

    elseif msg == "debug off" then
        E.debugMode = false
        print("|cff00ff00[MyNotes]|r Debug OFF.")

    elseif msg == "debug" then
        print("|cff00ff00[MyNotes]|r --- State ---")
        print("  focusedEditBox                              : " .. tostring(E.focusedEditBox))
        if E.focusedEditBox then
            print("  IsVisible                                   : " .. tostring(E.focusedEditBox:IsVisible()))
        end
        print("  ChatFrameUtil.InsertLink exists             : " .. tostring(ChatFrameUtil ~= nil and ChatFrameUtil.InsertLink ~= nil))
        print("  ChatEdit_InsertLink exists                  : " .. tostring(ChatEdit_InsertLink ~= nil))
        print("  ContainerFrameItemButton_OnModifiedClick    : " .. tostring(ContainerFrameItemButton_OnModifiedClick ~= nil))

    elseif msg == "test" then
        local testLink = "|cff1eff00|Hitem:6948:0:0:0:0:0:0:0|h[Hearthstone]|h|r"
        if E.focusedEditBox and E.focusedEditBox:IsVisible() then
            local cur = E.focusedEditBox:GetText()
            E.focusedEditBox:SetText(cur == "" and testLink or (cur .. testLink))
            print("|cff00ff00[MyNotes]|r Test link inserted – press Enter or click Add Note.")
        else
            print("|cffff4444[MyNotes]|r No focused editbox. Open the MyNotes panel first.")
        end

    else
        print("|cff00ff00[MyNotes]|r Commands: debug | debug on | debug off | test")
    end
end
