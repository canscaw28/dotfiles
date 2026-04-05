-- surround_pair.lua
-- Handles surround-pair insertion with selection wrapping.
-- Called from Karabiner via: hs -c "require('surround_pair').fire('[')"

local M = {}

-- Pair mappings: char -> {open, close}
local PAIRS = {
    ["("] = {"(", ")"},  [")"] = {"(", ")"},
    ["["] = {"[", "]"},  ["]"] = {"[", "]"},
    ["{"] = {"{", "}"},  ["}"] = {"{", "}"},
    ["<"] = {"<", ">"},  [">"] = {"<", ">"},
    ["'"] = {"'", "'"},  ['"'] = {'"', '"'},
    ["`"] = {"`", "`"},
    ["*"] = {"*", "*"},
    ["#"] = {"#", "#"},
}

local function getPair(char)
    local pair = PAIRS[char]
    if pair then
        return pair[1], pair[2]
    end
    return char, char
end

local function restoreClipboard(saved)
    if saved then
        hs.pasteboard.writeAllData(saved)
    end
end

-- Send N shift+left keystrokes to re-select text
local function selectBack(n)
    for _ = 1, n do
        hs.eventtap.event.newKeyEvent({"shift"}, "left", true):post()
        hs.eventtap.event.newKeyEvent({"shift"}, "left", false):post()
    end
end

function M.fire(char)
    local open, close = getPair(char)
    local savedClipboard = hs.pasteboard.readAllData()

    hs.pasteboard.clearContents()
    hs.eventtap.keyStroke({"cmd"}, "c")

    hs.timer.doAfter(0.1, function()
        local selected = hs.pasteboard.getContents()

        if selected and #selected > 0 then
            -- Has selection: type open (replaces selection), paste, type close
            hs.eventtap.keyStrokes(open)
            hs.eventtap.keyStroke({"cmd"}, "v")
            hs.timer.doAfter(0.03, function()
                hs.eventtap.keyStrokes(close)
                -- Re-select the entire wrapped text: open + content + close
                -- Use utf8.len for correct character count (not byte count)
                local charLen = utf8.len(selected) or #selected
                local totalLen = #open + charLen + #close
                hs.timer.doAfter(0.05, function()
                    selectBack(totalLen)
                    restoreClipboard(savedClipboard)
                end)
            end)
        else
            -- No selection: insert pair with cursor between
            hs.eventtap.keyStrokes(open .. close)
            hs.eventtap.keyStroke({}, "left")
            restoreClipboard(savedClipboard)
        end
    end)
end

return M
