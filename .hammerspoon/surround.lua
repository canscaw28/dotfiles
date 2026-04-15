-- surround.lua
-- Insert symbol pairs with cursor between.
--
-- Karabiner sends hyper+key (Ctrl+Cmd+Opt+key) for unshifted variants.
-- Shifted variants call M.doSurround() directly via shell_command.

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

-- ── Insert pair with cursor between ─────────────────────────────────────

local function insertPair(open, close)
    hs.eventtap.keyStrokes(open .. close)
    hs.timer.doAfter(0.02, function()
        hs.eventtap.event.newKeyEvent({}, hs.keycodes.map["left"], true):post()
        hs.eventtap.event.newKeyEvent({}, hs.keycodes.map["left"], false):post()
    end)
end

-- ── Direct surround (called via shell_command for shifted variants) ─────

function M.doSurround(open, close)
    insertPair(open, close)
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

        insertPair(pair[1], pair[2])
        return true -- consume the event
    end
)

initPairMap()

function M.start()
    M.handler:start()
end

function M.stop()
    M.handler:stop()
end

return M
