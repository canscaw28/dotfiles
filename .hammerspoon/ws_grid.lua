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
local lastMoveTarget = nil  -- previous move-mode highlight (for revert on next move)
-- (lastRefreshTargetMon removed: re-querying on mode transitions catches
-- transient AeroSpace state during focus-N ops, corrupting grid position)

-- Element index lookup for in-place canvas updates (populated by drawGrid)
local keyFaceIdx = {}   -- key -> canvas element index for face rectangle
local keyTextIdx = {}   -- key -> canvas element index for text element

-- Forward declarations (referenced before definition)
local startKeyDrain, stopKeyDrain, refresh

-- Grid animation state
local gridFallTimer = nil
local gridTargetX = nil
local gridTargetY = nil

local GRID_FALL_DIST = 20
local GRID_FALL_STEPS = 10
local GRID_FALL_INTERVAL = 0.02

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
    -- Cancel any in-progress fall animation on the old grid
    if gridFallTimer then gridFallTimer:stop(); gridFallTimer = nil end

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
    gridTargetX = x
    gridTargetY = y

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
function M.visitKey(key, targetMon, swapMode, moveMode)
    local displayKey = AERO_TO_KEY[key] or key

    -- Q mode (swap/push/pull): highlight target key without updating
    -- workspace state or moving focus marker. The grid refreshes from
    -- actual AeroSpace state after the operation completes.
    if swapMode then
        if grid and shouldShowGrid() then
            local monId = lastVisibleWs[displayKey]
            local labelColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
            patchKey(displayKey, true, false, labelColor)
        end
        return
    end

    -- Move mode (E without R): window moves but focus stays on source
    -- workspace. Don't update lastFocusedKey or lastVisibleWs — only
    -- highlight the target keycap (reverting previous move highlight).
    if moveMode then
        if grid and shouldShowGrid() then
            -- Revert previous move target so rapid-fire doesn't leave stale highlights
            if lastMoveTarget and lastMoveTarget ~= displayKey then
                local prevMonId = lastVisibleWs[lastMoveTarget]
                local prevColor = (prevMonId and MONITOR_COLORS[prevMonId]) or TEXT_COLOR_DIM
                patchKey(lastMoveTarget, prevMonId ~= nil, lastMoveTarget == lastFocusedKey, prevColor)
            end
            local monId = lastVisibleWs[displayKey]
            local labelColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
            patchKey(displayKey, true, false, labelColor)
            lastMoveTarget = displayKey
        end
        return
    end

    -- Invalidate any in-flight showGrid async callback so stale AeroSpace
    -- state doesn't overwrite this fresh visitKey update (prevents grid
    -- marker flickering back to a previous workspace during rapid focus ops).
    -- Only bump when grid exists — the initial showGrid must complete to
    -- create the canvas, otherwise patchKey calls below are no-ops.
    if grid then
        taskGeneration = taskGeneration + 1
    end

    local monId = targetMon or lastFocusedMonId

    local prevFocused = lastFocusedKey
    local displacedKey = nil

    -- Update cached visible workspace state
    local sourceMonId = lastVisibleWs[displayKey]  -- where target ws was before
    if monId then
        for k, m in pairs(lastVisibleWs) do
            if m == monId then
                displacedKey = k
                if sourceMonId and sourceMonId ~= monId then
                    -- Target ws was visible on another monitor — swap:
                    -- displaced ws moves to where the target was.
                    lastVisibleWs[k] = sourceMonId
                else
                    -- Target ws was hidden — displaced ws becomes hidden.
                    lastVisibleWs[k] = nil
                end
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

        -- Displaced key: moved to another monitor (swap) or hidden
        if displacedKey and displacedKey ~= displayKey and displacedKey ~= lastFocusedKey then
            local dispMonId = lastVisibleWs[displacedKey]
            local dispColor = (dispMonId and MONITOR_COLORS[dispMonId]) or TEXT_COLOR_DIM
            patchKey(displacedKey, dispMonId ~= nil, false, dispColor)
        end

        -- Visited key: show * only if it's the focused key
        local curColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
        patchKey(displayKey, monId ~= nil, displayKey == lastFocusedKey, curColor)
    end
end

function M.showGrid()
    -- Immediately reposition existing grid and update * marker before async
    -- query. Gives instant visual feedback (e.g. monitor switch via ') while
    -- the full AeroSpace state query runs in the background.
    if grid then
        local monId = targetMonitor()
        if monId ~= nil then
            local screen
            if monId == 0 then
                screen = hs.screen.mainScreen()
            else
                screen = screenForMonitor(monId)
            end
            if screen then
                local screenFrame = screen:frame()
                local f = grid:frame()
                grid:topLeft({
                    x = screenFrame.x + (screenFrame.w - f.w) / 2,
                    y = screenFrame.y + (screenFrame.h - f.h) / 2,
                })

                -- Update * marker to the workspace visible on the focused monitor.
                -- Reverse-lookup: screen → AeroSpace monitor ID → workspace key.
                local focusedMonId
                if monId == 0 then
                    local allScreens = hs.screen.allScreens()
                    table.sort(allScreens, function(a, b) return a:frame().x < b:frame().x end)
                    for idx, s in ipairs(allScreens) do
                        if s == screen then focusedMonId = idx; break end
                    end
                else
                    focusedMonId = monId
                end
                if focusedMonId then
                    local newFocusedKey = nil
                    for k, m in pairs(lastVisibleWs) do
                        if m == focusedMonId then newFocusedKey = k; break end
                    end
                    if newFocusedKey and newFocusedKey ~= lastFocusedKey then
                        -- Remove * from old focused key
                        if lastFocusedKey then
                            local oldMonId = lastVisibleWs[lastFocusedKey]
                            local oldColor = (oldMonId and MONITOR_COLORS[oldMonId]) or TEXT_COLOR_DIM
                            patchKey(lastFocusedKey, oldMonId ~= nil, false, oldColor)
                        end
                        -- Add * to new focused key
                        local newColor = MONITOR_COLORS[focusedMonId] or TEXT_COLOR_DIM
                        patchKey(newFocusedKey, true, true, newColor)
                        lastFocusedKey = newFocusedKey
                        lastFocusedMonId = focusedMonId
                    end
                end
            end
        end
    end

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
        lastMoveTarget = nil

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

-- Eventtap: Karabiner workspace manipulators output fn+key with modifier flags
-- encoding the operation mode. We decode the mode directly from the event,
-- bypassing the async keyDown/keyUp IPC that can drop events and leave keys
-- stuck. Keys are queued and drained one per display frame (~16ms) so each
-- gets its own drawRect pass.

-- macOS virtual keyCode → workspace key string
local KEY_CODE_MAP = {
    [22] = "6", [26] = "7", [28] = "8", [25] = "9", [29] = "0",
    [16] = "y", [32] = "u", [34] = "i", [31] = "o", [35] = "p",
    [4]  = "h", [38] = "j", [40] = "k", [37] = "l", [41] = ";",
    [45] = "n", [46] = "m", [43] = ",", [47] = ".", [44] = "/",
}

-- Decode operation mode from modifier flags on workspace key events.
-- Karabiner encodes the mode as extra modifiers alongside fn.
-- Returns: op, mon, swap, moveMode
--   op: operation name string
--   mon: target monitor ID (nil = current, 1-4 = specific)
--   swap: true if Q mode (swap/push/pull)
--   moveMode: true if move (window moves, focus stays)
local function decodeMode(flags)
    local s, c, o, m = flags.shift or false, flags.ctrl or false, flags.alt or false, flags.cmd or false
    -- Encoding matches apply_t_ws_layer.py OPERATIONS extra_modifiers:
    if m then
        if s then return "pull-windows", nil, true, false end  -- cmd+shift
        return "push-windows", nil, true, false                -- cmd
    end
    if s and c and o then return "swap-windows", nil, true, false end
    if c and o then return "focus-4", 4, false, false end
    if s and o then return "focus-3", 3, false, false end
    if o then return "focus-2", 2, false, false end
    if s and c then return "focus-1", 1, false, false end
    if c then return "move-focus", nil, false, false end
    if s then return "move", nil, false, true end
    return "focus", nil, false, false                          -- fn only
end

-- Map operation to expected keys state for reconciliation
local MODE_KEYS = {
    ["focus"]        = {t = true, w = true,  e = false, r = false, ["3"] = false, ["4"] = false, q = false},
    ["move"]         = {t = true, w = false, e = true,  r = false, ["3"] = false, ["4"] = false, q = false},
    ["move-focus"]   = {t = true, w = false, e = true,  r = true,  ["3"] = false, ["4"] = false, q = false},
    ["focus-1"]      = {t = true, w = true,  e = true,  r = false, ["3"] = false, ["4"] = false, q = false},
    ["focus-2"]      = {t = true, w = true,  e = false, r = true,  ["3"] = false, ["4"] = false, q = false},
    ["focus-3"]      = {t = true, w = true,  e = false, r = false, ["3"] = true,  ["4"] = false, q = false},
    ["focus-4"]      = {t = true, w = true,  e = false, r = false, ["3"] = false, ["4"] = true,  q = false},
    ["swap-windows"] = {t = true, w = false, e = false, r = false, ["3"] = false, ["4"] = false, q = true},
    ["push-windows"] = {t = true, w = false, e = false, r = false, ["3"] = true,  ["4"] = false, q = true},
    ["pull-windows"] = {t = true, w = false, e = true,  r = false, ["3"] = false, ["4"] = false, q = true},
}

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
    M.visitKey(entry.key, entry.mon, entry.swap, entry.moveMode)
    local ws_notify = require("ws_notify")
    ws_notify.show(entry.key, entry.mon or lastFocusedMonId, entry.source, entry.followFocus)
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

-- Catches workspace key events from Karabiner's virtual keyboard output.
-- Mode is decoded from modifier flags — no dependency on async keyDown/keyUp.
local wsEventTap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local keyCode = event:getKeyCode()
        local wsKey = KEY_CODE_MAP[keyCode]
        if not wsKey then return false end  -- not a workspace key, pass through

        -- Consume keyUp silently (prevents orphaned keyUp reaching apps)
        if event:getType() == hs.eventtap.event.types.keyUp then
            return true
        end

        -- Ignore key repeat
        if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0 then
            return true
        end

        -- Decode mode from modifier flags (source of truth from Karabiner)
        local flags = event:getFlags()
        local op, mon, swapMode, moveMode = decodeMode(flags)

        -- Reconcile keys table to match decoded mode — self-corrects any
        -- stale state from dropped async keyDown/keyUp IPC calls.
        local expected = MODE_KEYS[op]
        if expected then
            for k, v in pairs(expected) do
                if keys[k] ~= v then
                    keys[k] = v
                end
            end
            refresh()
        end

        -- Enqueue for frame-paced drain
        local source = (moveMode or op == "move-focus") and lastFocusedKey or nil
        local followFocus = (op == "move-focus")
        pendingKeyQueue[#pendingKeyQueue + 1] = {
            key = wsKey, mon = mon, swap = swapMode,
            moveMode = moveMode, source = source, followFocus = followFocus,
        }
        startKeyDrain()

        return true  -- consume
    end
)

local function startGridFall()
    if gridFallTimer then return end  -- already falling
    if not grid then return end

    -- Stop accepting new keys
    if wsEventTap:isEnabled() then wsEventTap:stop() end
    stopKeyDrain()
    if pendingTask and pendingTask:isRunning() then
        pendingTask:terminate()
        pendingTask = nil
    end
    local fallStep = 0
    gridFallTimer = hs.timer.doEvery(GRID_FALL_INTERVAL, function()
        fallStep = fallStep + 1
        if not grid then
            gridFallTimer:stop(); gridFallTimer = nil
            return
        end
        if fallStep >= GRID_FALL_STEPS then
            gridFallTimer:stop()
            gridFallTimer = nil
            grid:delete()
            grid = nil
            keyFaceIdx = {}
            keyTextIdx = {}
        else
            local t = fallStep / GRID_FALL_STEPS
            grid:topLeft({x = gridTargetX, y = gridTargetY + GRID_FALL_DIST * t})
            grid:alpha(1 - t)
        end
    end)
end

function M.hideGrid()
    if gridFallTimer then gridFallTimer:stop(); gridFallTimer = nil end
    if wsEventTap:isEnabled() then wsEventTap:stop() end
    stopKeyDrain()
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

refresh = function()
    if shouldShowGrid() then
        -- Cancel any ongoing fall animation — grid is needed again
        if gridFallTimer then
            gridFallTimer:stop()
            gridFallTimer = nil
            if grid then
                grid:topLeft({x = gridTargetX, y = gridTargetY})
                grid:alpha(1)
            end
        end

        if grid then
            -- Grid already visible: just reposition to target screen.
            -- NEVER re-query AeroSpace here — during focus-N ops, workers
            -- may be mid-operation with focus on the wrong monitor. The
            -- async query would capture that transient state, corrupting
            -- lastFocusedMonId and causing the grid to jump to the wrong
            -- screen with wrong colors. visitKey handles keycap updates
            -- from keyboard events; ws.sh calls showGrid() directly after
            -- ops complete with correct state.
            local monId = targetMonitor()
            local screen = screenForMonitor(monId == 0 and (lastFocusedMonId or 0) or monId)
            if screen then
                local screenFrame = screen:frame()
                local f = grid:frame()
                local newX = screenFrame.x + (screenFrame.w - f.w) / 2
                local newY = screenFrame.y + (screenFrame.h - f.h) / 2
                grid:topLeft({x = newX, y = newY})
                gridTargetX = newX
                gridTargetY = newY
            end
        else
            M.showGrid()
        end
        if not wsEventTap:isEnabled() then wsEventTap:start() end
    else
        -- Start fall animation instead of instant hide
        if grid and not gridFallTimer then
            startGridFall()
        elseif not grid and not gridFallTimer then
            if wsEventTap:isEnabled() then wsEventTap:stop() end
        end
    end
end

function M.keyDown(k)
    keys[k] = true
    refresh()
end

function M.keyUp(k)
    keys[k] = false
    refresh()
end

-- Safety net: reset all mode keys when caps lock is released.
-- Called from caps_lock setter's to_after_key_up shell command.
-- Catches any stale state from dropped async keyUp IPC calls.
function M.resetAllKeys()
    local changed = false
    for k, _ in pairs(keys) do
        if keys[k] then
            keys[k] = false
            changed = true
        end
    end
    if changed then refresh() end
end

return M
