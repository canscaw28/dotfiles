-- ws_grid.lua
-- Workspace grid overlay shown while caps+T+W, caps+T+E, or caps+T+Q is held.
-- Displays 4x5 grid of workspace keys styled as keyboard keycaps.
-- Visible workspaces colored by monitor. Focused workspace gets a * prefix.

local M = {}

local grid = nil
local pendingTask = nil
local taskGeneration = 0
local keys = {t = false, w = false, e = false, r = false, ["3"] = false, ["4"] = false, q = false}

local lastVisibleWs = {}    -- key -> monitorId for cached workspace state
local lastFocusedKey = nil
local lastFocusedMonId = nil

-- Element index lookup for in-place canvas updates (populated by drawGrid)
local keyFaceIdx = {}   -- key -> canvas element index for face rectangle
local keyTextIdx = {}   -- key -> canvas element index for text element

-- Forward declarations for key drain (referenced by showGrid callback)
local startKeyDrain, stopKeyDrain

-- Grid layout: 4 rows of 5 keys with keyboard stagger
local ROWS = {
    {keys = {"6", "7", "8", "9", "0"}, stagger = 0},
    {keys = {"y", "u", "i", "o", "p"}, stagger = 0.25},
    {keys = {"h", "j", "k", "l", ";"}, stagger = 0.5},
    {keys = {"n", "m", ",", ".", "/"}, stagger = 0.75},
}

-- Monitor colors
local MONITOR_COLORS = {
    [1] = {red = 0.1, green = 0.3, blue = 0.7, alpha = 1},      -- blue
    [2] = {red = 0.7, green = 0.25, blue = 0.1, alpha = 1},     -- orange
    [3] = {red = 0.1, green = 0.5, blue = 0.25, alpha = 1},     -- green
    [4] = {red = 0.4, green = 0.15, blue = 0.6, alpha = 1},     -- purple
}

-- Keycap styling — high contrast so keys read as individual caps, not a blob
local KEY_FACE = {red = 0.38, green = 0.38, blue = 0.40, alpha = 0.9}
local KEY_FACE_ACTIVE = {red = 0.48, green = 0.48, blue = 0.50, alpha = 0.9}
local KEY_EDGE = {red = 0.28, green = 0.28, blue = 0.30, alpha = 0.9}   -- darker bottom/side for 3D
local KEY_BORDER = {red = 0.55, green = 0.55, blue = 0.58, alpha = 0.9}
local KEY_SHADOW = {red = 0, green = 0, blue = 0, alpha = 0.5}
local TEXT_COLOR_DIM = {red = 0.18, green = 0.18, blue = 0.20, alpha = 1}
local CELL_SIZE = 44
local CELL_GAP = 8
local KEY_RADIUS = 7
local FONT_SIZE = 17
local SHADOW_OFFSET = 3
local EDGE_HEIGHT = 4     -- visible "thickness" of keycap bottom edge
local PADDING = 14

-- Map AeroSpace workspace names to grid display keys
local AERO_TO_KEY = {
    [";"] = ";", ["comma"] = ",",
}

-- Map sub-mode keys to AeroSpace monitor IDs
local MODE_TO_MONITOR = {e = 1, r = 2, ["3"] = 3, ["4"] = 4}

-- Determine target monitor ID for grid display (nil = don't show)
local function targetMonitor()
    if not keys.t then return nil end
    if keys.q then return 0 end  -- 0 = current monitor
    if keys.e and not keys.w then return 0 end  -- move/move-focus mode
    if not keys.w then return nil end
    -- W held: check if a focus-on-monitor sub-mode is active
    for k, monId in pairs(MODE_TO_MONITOR) do
        if keys[k] then return monId end
    end
    return 0  -- W only = current monitor
end

-- Get screen for an AeroSpace monitor ID (sorted left-to-right to match AeroSpace ordering)
local function screenForMonitor(monitorId)
    if not monitorId or monitorId < 1 then return hs.mouse.getCurrentScreen() or hs.screen.mainScreen() end
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens[monitorId]  -- nil if monitor doesn't exist
end

local function shouldShowGrid()
    return targetMonitor() ~= nil
end

-- Lightweight in-place update of a single key's face color and text label.
-- Uses hs.canvas:elementAttribute() to avoid full canvas recreation.
local function patchKey(key, isActive, isFocused, labelColor)
    if not grid then return end
    local fi = keyFaceIdx[key]
    local ti = keyTextIdx[key]
    if not fi or not ti then return end
    grid:elementAttribute(fi, "fillColor", isActive and KEY_FACE_ACTIVE or KEY_FACE)
    local displayText = isFocused and ("*" .. key) or key
    local fontName = isActive and "Helvetica-Bold" or "Helvetica"
    local styledText = hs.styledtext.new(displayText, {
        font = {name = fontName, size = FONT_SIZE},
        color = labelColor,
        paragraphStyle = {alignment = "center"},
    })
    grid:elementAttribute(ti, "text", styledText)
end

local function drawGrid(visibleWs, focusedKey, focusedMonId)
    if grid then
        grid:delete()
        grid = nil
    end
    keyFaceIdx = {}
    keyTextIdx = {}

    local monId = targetMonitor()
    if monId == nil then return end
    -- For "current monitor" (0), use AeroSpace's focused monitor instead of mouse position
    local screen = screenForMonitor(monId == 0 and (focusedMonId or 0) or monId)
    if not screen then return end  -- target monitor doesn't exist
    local screenFrame = screen:frame()

    local numCols = 5
    local numRows = #ROWS
    local maxStagger = ROWS[numRows].stagger * CELL_SIZE
    local gridW = numCols * (CELL_SIZE + CELL_GAP) - CELL_GAP + maxStagger
    local gridH = numRows * (CELL_SIZE + CELL_GAP) - CELL_GAP + EDGE_HEIGHT
    local totalW = gridW + PADDING * 2
    local totalH = gridH + PADDING * 2

    local x = screenFrame.x + (screenFrame.w - totalW) / 2
    local y = screenFrame.y + (screenFrame.h - totalH) / 2

    grid = hs.canvas.new({x = x, y = y, w = totalW, h = totalH})
    grid:level(hs.canvas.windowLevels.overlay + 1)
    grid:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    grid:clickActivating(false)
    grid:canvasMouseEvents(false)

    -- Plate: one opaque rounded rect per row, overlapping vertically.
    local PLATE_PAD = 12
    local PLATE_RADIUS = 10
    local PLATE_COLOR = {red = 0.1, green = 0.1, blue = 0.12, alpha = 0.85}
    local rowW = numCols * (CELL_SIZE + CELL_GAP) - CELL_GAP
    for rowIdx, row in ipairs(ROWS) do
        local rLeft = PADDING + row.stagger * CELL_SIZE - PLATE_PAD
        local rTop = PADDING + (rowIdx - 1) * (CELL_SIZE + CELL_GAP) - PLATE_PAD
        local rW = rowW + 2 * PLATE_PAD
        local rH = CELL_SIZE + 2 * PLATE_PAD
        if rowIdx < numRows then
            rH = rH + CELL_GAP  -- overlap into gap to merge with next row
        else
            rH = rH + EDGE_HEIGHT  -- cover key edge on last row
        end
        grid:appendElements({
            type = "rectangle",
            action = "fill",
            fillColor = PLATE_COLOR,
            roundedRectRadii = {xRadius = PLATE_RADIUS, yRadius = PLATE_RADIUS},
            frame = {x = rLeft, y = rTop, w = rW, h = rH},
        })
    end

    -- Draw keycaps (5 elements per key: shadow, edge, face, border, text)
    -- Track element count to record face/text indices for patchKey
    local elementCount = #ROWS  -- plates already added
    for rowIdx, row in ipairs(ROWS) do
        for colIdx, key in ipairs(row.keys) do
            local cellX = PADDING + (colIdx - 1) * (CELL_SIZE + CELL_GAP) + row.stagger * CELL_SIZE
            local cellY = PADDING + (rowIdx - 1) * (CELL_SIZE + CELL_GAP)

            local keyMonId = visibleWs[key]
            local isFocused = (key == focusedKey)
            local isActive = keyMonId ~= nil

            -- Layer 1: Drop shadow
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = KEY_SHADOW,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX + 1, y = cellY + SHADOW_OFFSET,
                         w = CELL_SIZE, h = CELL_SIZE},
            })
            elementCount = elementCount + 1

            -- Layer 2: Key edge/side
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = KEY_EDGE,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE + EDGE_HEIGHT},
            })
            elementCount = elementCount + 1

            -- Layer 3: Key face
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = isActive and KEY_FACE_ACTIVE or KEY_FACE,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE},
            })
            elementCount = elementCount + 1
            keyFaceIdx[key] = elementCount

            -- Layer 4: Border
            grid:appendElements({
                type = "rectangle",
                action = "stroke",
                strokeWidth = 1.5,
                strokeColor = KEY_BORDER,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE},
            })
            elementCount = elementCount + 1

            -- Key label
            local labelColor = (keyMonId and MONITOR_COLORS[keyMonId]) or TEXT_COLOR_DIM
            local displayText = isFocused and ("*" .. key) or key
            local fontName = isActive and "Helvetica-Bold" or "Helvetica"
            local styledText = hs.styledtext.new(displayText, {
                font = {name = fontName, size = FONT_SIZE},
                color = labelColor,
                paragraphStyle = {alignment = "center"},
            })
            local textOffsetY = (CELL_SIZE - FONT_SIZE * 1.25) / 2
            grid:appendElements({
                type = "text",
                text = styledText,
                frame = {x = cellX, y = cellY + textOffsetY, w = CELL_SIZE, h = FONT_SIZE * 1.5},
            })
            elementCount = elementCount + 1
            keyTextIdx[key] = elementCount
        end
    end

    grid:alpha(1)
    grid:show()
end

-- Instant update for rapid key sequences.
-- Patches only changed keys (prev focused, displaced, current) instead of
-- recreating the entire 104-element canvas.
function M.visitKey(key, targetMon)
    local displayKey = AERO_TO_KEY[key] or key
    local monId = targetMon or lastFocusedMonId

    local prevFocused = lastFocusedKey
    local displacedKey = nil

    -- Update cached visible workspace state
    if monId then
        for k, m in pairs(lastVisibleWs) do
            if m == monId then
                displacedKey = k
                lastVisibleWs[k] = nil
                break
            end
        end
        lastVisibleWs[displayKey] = monId
    end

    -- Move the * marker only when operating on the user's actual focused
    -- monitor. focus-N ops on a different monitor change that monitor's
    -- workspace without moving focus, so * should stay put.
    local moveFocus = (targetMon == nil) or (targetMon == lastFocusedMonId)
    if moveFocus then
        lastFocusedKey = displayKey
    end

    -- Patch only changed keys (no full canvas recreation)
    if grid and shouldShowGrid() then
        -- Previous focused key: revert to normal state (only if * moved)
        if moveFocus and prevFocused and prevFocused ~= displayKey then
            local prevMonId = lastVisibleWs[prevFocused]
            local prevColor = (prevMonId and MONITOR_COLORS[prevMonId]) or TEXT_COLOR_DIM
            patchKey(prevFocused, prevMonId ~= nil, false, prevColor)
        end

        -- Displaced key: lost its monitor assignment
        if displacedKey and displacedKey ~= displayKey and displacedKey ~= lastFocusedKey then
            patchKey(displacedKey, false, false, TEXT_COLOR_DIM)
        end

        -- Visited key: show * only if it's the focused key
        local curColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
        patchKey(displayKey, monId ~= nil, displayKey == lastFocusedKey, curColor)
    end
end

function M.showGrid()
    -- Cancel any in-flight workspace query
    if pendingTask and pendingTask:isRunning() then
        pendingTask:terminate()
        pendingTask = nil
    end

    -- Bump generation so stale callbacks are silently ignored.
    taskGeneration = taskGeneration + 1
    local myGeneration = taskGeneration

    -- Query workspace state asynchronously to avoid blocking Hammerspoon IPC
    pendingTask = hs.task.new("/bin/bash", function(exitCode, stdout, stderr)
        pendingTask = nil
        if myGeneration ~= taskGeneration then return end  -- stale callback
        if exitCode ~= 0 then return end
        if not shouldShowGrid() then return end

        local visibleWs = {}
        local focusedKey = nil
        local focusedMonId = nil
        for line in stdout:gmatch("[^\n]+") do
            local focused = line:match("^F:(.+)")
            if focused then
                focused = focused:match("^%s*(.-)%s*$")
                if focused ~= "" then
                    focusedKey = AERO_TO_KEY[focused] or focused
                end
            end
            local fm = line:match("^FM:(%d+)")
            if fm then
                focusedMonId = tonumber(fm)
            end
            local monIdStr, ws = line:match("^M:(%d+):(.+)")
            if monIdStr and ws then
                ws = ws:match("^%s*(.-)%s*$")
                if ws ~= "" then
                    local displayKey = AERO_TO_KEY[ws] or ws
                    visibleWs[displayKey] = tonumber(monIdStr)
                end
            end
        end

        lastVisibleWs = visibleWs
        lastFocusedKey = focusedKey
        lastFocusedMonId = focusedMonId

        drawGrid(visibleWs, focusedKey, focusedMonId)

        -- Drain any keys that accumulated while the async query was in flight
        startKeyDrain()
    end, {"-c", [[
        focused=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
        echo "F:$focused"
        focused_mon=$(/opt/homebrew/bin/aerospace list-monitors --focused --format '%{monitor-id}')
        echo "FM:$focused_mon"
        for m in $(/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}'); do
            ws=$(/opt/homebrew/bin/aerospace list-workspaces --monitor "$m" --visible)
            echo "M:$m:$ws"
        done
    ]]})
    pendingTask:start()
end

function M.getFrame()
    if grid then return grid:frame() end
    return nil
end

-- File poll: Karabiner writes key names to /tmp/ws-grid-keys (printf builtin,
-- ~0ms). We poll at 60Hz while the grid is visible. Keys are queued and
-- drained one per display frame (~16ms) so each gets its own drawRect pass.
-- (hs.canvas:elementAttribute calls setNeedsDisplay which defers to runloop;
-- multiple calls in one callback produce only one visible frame.)
local WS_KEY_SET = {}
for _, row in ipairs(ROWS) do
    for _, key in ipairs(row.keys) do
        WS_KEY_SET[key] = true
    end
end

local KEY_FILE = "/tmp/ws-grid-keys"
local KEY_TMP  = "/tmp/ws-grid-keys.tmp"
local keyPollTimer = nil
local pendingKeyQueue = {}
local keyDrainTimer = nil

stopKeyDrain = function()
    pendingKeyQueue = {}
    if keyDrainTimer then keyDrainTimer:stop(); keyDrainTimer = nil end
end

local function drainOneKey()
    if #pendingKeyQueue == 0 then
        if keyDrainTimer then keyDrainTimer:stop(); keyDrainTimer = nil end
        return
    end
    -- Wait for grid to be ready (showGrid async query still in flight)
    if not grid then return end
    if not shouldShowGrid() then
        stopKeyDrain()
        return
    end
    local entry = table.remove(pendingKeyQueue, 1)
    M.visitKey(entry.key, entry.mon)
    if #pendingKeyQueue == 0 then
        if keyDrainTimer then keyDrainTimer:stop(); keyDrainTimer = nil end
    end
end

startKeyDrain = function()
    if keyDrainTimer then return end  -- already draining
    if #pendingKeyQueue == 0 then return end
    -- Process first key immediately if grid is ready
    if grid then
        drainOneKey()
    end
    -- Start timer to drain remaining (or retry when grid becomes ready)
    if #pendingKeyQueue > 0 and not keyDrainTimer then
        keyDrainTimer = hs.timer.doEvery(0.016, drainOneKey)
    end
end

local function pollKeys()
    -- Safety: if grid should no longer be visible, clean up
    if not shouldShowGrid() then
        if keyPollTimer then keyPollTimer:stop(); keyPollTimer = nil end
        stopKeyDrain()
        os.remove(KEY_FILE)
        os.remove(KEY_TMP)
        if grid then grid:delete(); grid = nil end
        return
    end

    local ok = os.rename(KEY_FILE, KEY_TMP)
    if not ok then return end
    local f = io.open(KEY_TMP, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    os.remove(KEY_TMP)

    -- Enqueue valid keys for frame-paced draining
    local added = false
    for key in content:gmatch("[^\n]+") do
        if WS_KEY_SET[key] then
            local mon = targetMonitor()
            if mon == 0 then mon = nil end
            pendingKeyQueue[#pendingKeyQueue + 1] = {key = key, mon = mon}
            added = true
        end
    end
    if added then startKeyDrain() end
end

local function startKeyPoll()
    if keyPollTimer then return end
    keyPollTimer = hs.timer.doEvery(0.016, pollKeys)  -- 60Hz (matches display)
end

local function stopKeyPoll()
    if keyPollTimer then
        keyPollTimer:stop()
        keyPollTimer = nil
    end
    stopKeyDrain()
end

function M.hideGrid()
    stopKeyPoll()
    os.remove(KEY_FILE)
    os.remove(KEY_TMP)
    if pendingTask and pendingTask:isRunning() then
        pendingTask:terminate()
        pendingTask = nil
    end
    if grid then
        grid:delete()
        grid = nil
    end
    keyFaceIdx = {}
    keyTextIdx = {}
end

local function refresh()
    if shouldShowGrid() then
        M.showGrid()
        startKeyPoll()
    else
        M.hideGrid()
    end
end

function M.keyDown(k)
    if k == "t" then
        -- T pressed: clear sub-mode keys to prevent stale state from
        -- out-of-order hs CLI IPC calls (each keyDown/keyUp is a separate
        -- background process that can race)
        keys.w = false
        keys.e = false
        keys.r = false
        keys["3"] = false
        keys["4"] = false
        keys.q = false
    end
    keys[k] = true
    refresh()
end

function M.keyUp(k)
    if k == "t" then
        -- T released: clear ALL key state so stuck sub-mode keys
        -- can't cause the grid to show on next T press
        for key in pairs(keys) do
            keys[key] = false
        end
    else
        keys[k] = false
    end
    refresh()
end

return M
