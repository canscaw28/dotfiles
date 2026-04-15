-- surround.lua
-- Encapsulate/surround text with symbol pairs.
--
-- Karabiner sends hyper+key (Ctrl+Cmd+Opt+key) when caps+Q+symbol is pressed.
-- This eventtap catches those events, checks for selected text via the
-- accessibility API (no clipboard), and either wraps the selection or
-- inserts a pair with the cursor between.

local M = {}

-- ── Pair table ──────────────────────────────────────────────────────────
-- Map key codes → {default_pair, shifted_pair}
-- Each pair is {open, close}. shifted_pair is nil when same as default.

local pairMap = {}

local function initPairMap()
    local km = hs.keycodes.map
    -- Number row: always produce shifted-symbol pair
    pairMap[km["1"]]  = {{"!", "!"}}
    pairMap[km["2"]]  = {{"@", "@"}}
    pairMap[km["3"]]  = {{"#", "#"}}
    pairMap[km["4"]]  = {{"$", "$"}}
    pairMap[km["5"]]  = {{"%", "%"}}
    pairMap[km["6"]]  = {{"^", "^"}}
    pairMap[km["7"]]  = {{"&", "&"}}
    pairMap[km["8"]]  = {{"*", "*"}}
    pairMap[km["9"]]  = {{"(", ")"}}
    pairMap[km["0"]]  = {{"(", ")"}}
    -- Keys with different shifted pairs
    pairMap[km["["]]  = {{"[", "]"}, {"{", "}"}}
    pairMap[km["]"]]  = {{"[", "]"}, {"{", "}"}}
    pairMap[km["'"]]  = {{"'", "'"}, {'"', '"'}}
    pairMap[km["`"]]  = {{"`", "`"}, {"~", "~"}}
    pairMap[km["-"]]  = {{"-", "-"}, {"_", "_"}}
    pairMap[km["="]]  = {{"=", "="}, {"+", "+"}}
    pairMap[km[";"]]  = {{";", ";"}, {":", ":"}}
    pairMap[km[","]]  = {{",", ","}, {"<", ">"}}
    pairMap[km["."]]  = {{".", "."}, {"<", ">"}}
    pairMap[km["/"]]  = {{"/", "/"}, {"?", "?"}}
    pairMap[km["\\"]] = {{"\\", "\\"}, {"|", "|"}}
end

local function getPair(keyCode, shifted)
    local entry = pairMap[keyCode]
    if not entry then return nil end
    if shifted and entry[2] then
        return entry[2]
    end
    return entry[1]
end

-- ── Key event helpers ───────────────────────────────────────────────────

local function postKey(mods, keyCode)
    hs.eventtap.event.newKeyEvent(mods, keyCode, true):post()
    hs.eventtap.event.newKeyEvent(mods, keyCode, false):post()
end

-- ── AX helpers ──────────────────────────────────────────────────────────

local function getFocusedElement()
    local sys = hs.axuielement.systemWideElement()
    if not sys then return nil end
    return sys:attributeValue("AXFocusedUIElement")
end

local function getSelectedText(el)
    if not el then return nil end
    local ok, text = pcall(function() return el:attributeValue("AXSelectedText") end)
    if ok and text and #text > 0 then return text end
    return nil
end

local function getSelectedRange(el)
    if not el then return nil end
    local ok, range = pcall(function() return el:attributeValue("AXSelectedTextRange") end)
    if ok and range then return range end
    return nil
end

-- ── Surround logic ─────────────────────────────────────────────────────

local function wrapSelection(open, close, selected, el)
    local wrapped = open .. selected .. close
    local range = getSelectedRange(el)

    -- Try AX write: replace selection via accessibility
    local writeOk = pcall(function()
        el:setAttributeValue("AXSelectedText", wrapped)
    end)

    if writeOk then
        -- Re-select the original text (skip the opening symbol)
        if range then
            pcall(function()
                el:setAttributeValue("AXSelectedTextRange", {
                    location = range.loc + #open,
                    length = range.len,
                })
            end)
        end
        return
    end

    -- Fallback: type the wrapped text (replaces selection via keystroke)
    hs.eventtap.keyStrokes(wrapped)
    -- Re-select with arrow keys
    hs.timer.doAfter(0.02, function()
        local leftCode = hs.keycodes.map["left"]
        for _ = 1, #close do
            postKey({}, leftCode)
        end
        for _ = 1, #selected do
            postKey({"shift"}, leftCode)
        end
    end)
end

local function insertPair(open, close)
    hs.eventtap.keyStrokes(open .. close)
    hs.timer.doAfter(0.02, function()
        postKey({}, hs.keycodes.map["left"])
    end)
end

-- ── Direct surround (called via shell_command for shifted variants) ─────

function M.doSurround(open, close)
    local el = getFocusedElement()
    local selected = getSelectedText(el)
    if selected then
        wrapSelection(open, close, selected, el)
    else
        insertPair(open, close)
    end
end

-- ── Eventtap ────────────────────────────────────────────────────────────

M.handler = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(event)
        local flags = event:getFlags()
        local keyCode = event:getKeyCode()

        -- Must have exactly ctrl+cmd+alt (+ optional shift), nothing else
        if not (flags.ctrl and flags.cmd and flags.alt) then return false end
        if flags.fn then return false end

        local shifted = flags.shift or false

        local pair = getPair(keyCode, shifted)
        if not pair then return false end

        local open, close = pair[1], pair[2]

        -- Check for selection via accessibility (no clipboard)
        local el = getFocusedElement()
        local selected = getSelectedText(el)

        if selected then
            wrapSelection(open, close, selected, el)
        else
            insertPair(open, close)
        end

        return true -- consume the event
    end
)

initPairMap()
M.handler:start()

return M
