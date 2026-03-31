local M = {}

-- ============================================================
-- State
-- ============================================================

-- Indicator
local indicatorCanvas = nil
local indicatorFadeTimer = nil
local INDICATOR_DIAMETER = 16
local INDICATOR_COLOR = {red = 1, green = 0.4, blue = 0.05, alpha = 0.8}

-- Grid overlay
local gridCanvas = nil
local gridVisible = false
local gridEnabled = false  -- toggled by P, persists across key releases
local currentGridSize = nil
local currentGridMode = nil -- "move" or "jump"

-- Hold-to-repeat
local moveTimer = nil
local REPEAT_DELAY = 0.3
local REPEAT_INTERVAL = 0.065

-- Fixed positions for F+E mode {xFraction, yFraction}
local JUMP_POSITIONS = {
    h         = {0.0625, 0.5},     -- left center
    l         = {0.9375, 0.5},     -- right center
    j         = {0.5, 0.9375},     -- bottom center
    k         = {0.5, 0.0625},     -- top center
    semicolon = {0.5, 0.5},        -- window center
    y         = {0.0625, 0.0625},  -- top-left corner
    o         = {0.9375, 0.0625},  -- top-right corner
    n         = {0.0625, 0.9375},  -- bottom-left corner
    period    = {0.9375, 0.9375},  -- bottom-right corner
    u         = {0.25, 0.25},      -- top-left quadrant center
    i         = {0.75, 0.25},      -- top-right quadrant center
    m         = {0.25, 0.75},      -- bottom-left quadrant center
    comma     = {0.75, 0.75},      -- bottom-right quadrant center
}

-- ============================================================
-- Indicator (red-amber dot at cursor position)
-- ============================================================
local function showIndicator()
    if indicatorFadeTimer then
        indicatorFadeTimer:stop()
        indicatorFadeTimer = nil
    end

    local pos = hs.mouse.absolutePosition()
    local x = pos.x - INDICATOR_DIAMETER / 2
    local y = pos.y - INDICATOR_DIAMETER / 2

    if not indicatorCanvas then
        indicatorCanvas = hs.canvas.new({x = x, y = y, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER})
        indicatorCanvas:level(hs.canvas.windowLevels.overlay)
        indicatorCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
        indicatorCanvas[1] = {
            type = "oval",
            frame = {x = 0, y = 0, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER},
            fillColor = INDICATOR_COLOR,
            action = "fill",
        }
    else
        indicatorCanvas:frame({x = x, y = y, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER})
    end

    indicatorCanvas:alpha(1)
    indicatorCanvas:show()

    local fadeSteps = 10
    local fadeInterval = 0.05
    local step = 0
    indicatorFadeTimer = hs.timer.doEvery(fadeInterval, function()
        step = step + 1
        if step >= fadeSteps then
            indicatorCanvas:hide()
            indicatorFadeTimer:stop()
            indicatorFadeTimer = nil
        else
            indicatorCanvas:alpha(1 - step / fadeSteps)
        end
    end)
end

-- ============================================================
-- Grid overlay — cursor-relative for move modes, fixed for jump
-- ============================================================

-- Line styles by distance from cursor (orange cursor, green/blue/etc away)
local LINE_STYLES = {
    cursor = {color = {red = 1, green = 0.5, blue = 0.1, alpha = 0.6}, width = 2.0},     -- orange, current pos
    major  = {color = {red = 0.1, green = 1.0, blue = 0.3, alpha = 0.55}, width = 2.0},  -- green, half screen
    mid    = {color = {red = 0.3, green = 0.6, blue = 1.0, alpha = 0.45}, width = 1.5},  -- blue
    fine   = {color = {red = 0.55, green = 0.75, blue = 1.0, alpha = 0.4}, width = 1.0}, -- brighter light blue
    minor  = {color = {red = 0.7, green = 0.6, blue = 0.85, alpha = 0.35}, width = 0.75, -- brighter purple, dashed
              dash = {6, 4}},
}

local function classifyByDistance(n, gridSize)
    if n == 0 then return "cursor" end
    local a = math.abs(n)
    if gridSize <= 8 then
        if a % 4 == 0 then return "major"
        elseif a % 2 == 0 then return "mid"
        else return "fine"
        end
    else
        if a % 16 == 0 then return "major"
        elseif a % 8 == 0 then return "mid"
        elseif a % 4 == 0 then return "fine"
        elseif a % 2 == 0 then return "minor"
        else return nil
        end
    end
end

local function addLine(elements, x, y, w, h, style)
    if style.dash then
        if w < h then
            table.insert(elements, {
                type = "segments",
                coordinates = {{x = x, y = y}, {x = x, y = y + h}},
                strokeColor = style.color,
                strokeWidth = style.width,
                strokeDashPattern = style.dash,
                action = "stroke",
            })
        else
            table.insert(elements, {
                type = "segments",
                coordinates = {{x = x, y = y}, {x = x + w, y = y}},
                strokeColor = style.color,
                strokeWidth = style.width,
                strokeDashPattern = style.dash,
                action = "stroke",
            })
        end
    else
        table.insert(elements, {
            type = "rectangle",
            frame = {x = x, y = y, w = math.max(w, style.width), h = math.max(h, style.width)},
            fillColor = style.color,
            action = "fill",
        })
    end
end

local function createMoveGrid(gridSize, winFrame, cursorRelX, cursorRelY)
    local elements = {}
    local cellW = winFrame.w / gridSize
    local cellH = winFrame.h / gridSize

    for n = -gridSize, gridSize do
        local x = cursorRelX + n * cellW
        if x >= 0 and x <= winFrame.w then
            local cat = classifyByDistance(n, gridSize)
            if cat then
                addLine(elements, math.floor(x), 0, LINE_STYLES[cat].width, winFrame.h, LINE_STYLES[cat])
            end
        end
    end

    for n = -gridSize, gridSize do
        local y = cursorRelY + n * cellH
        if y >= 0 and y <= winFrame.h then
            local cat = classifyByDistance(n, gridSize)
            if cat then
                addLine(elements, 0, math.floor(y), winFrame.w, LINE_STYLES[cat].width, LINE_STYLES[cat])
            end
        end
    end

    return elements
end

local JUMP_LABELS = {
    h = "H", l = "L", j = "J", k = "K", semicolon = ";",
    y = "Y", o = "O", n = "N", period = ".",
    u = "U", i = "I", m = "M", comma = ",",
}

local function createJumpGrid(winFrame)
    local elements = {}
    local DOT_SIZE = 10
    local DOT_COLOR = {red = 1, green = 0.6, blue = 0.1, alpha = 0.5}
    local LABEL_BG = {red = 1, green = 0.85, blue = 0, alpha = 0.9}
    local LABEL_FG = {red = 0, green = 0, blue = 0, alpha = 1}
    local LABEL_W = 18
    local LABEL_H = 16

    for key, pos in pairs(JUMP_POSITIONS) do
        local px = math.floor(pos[1] * winFrame.w)
        local py = math.floor(pos[2] * winFrame.h)
        local armLen = 12
        local armW = 1.5
        table.insert(elements, {
            type = "rectangle",
            frame = {x = px - armLen, y = py - armW / 2, w = armLen * 2, h = armW},
            fillColor = DOT_COLOR, action = "fill",
        })
        table.insert(elements, {
            type = "rectangle",
            frame = {x = px - armW / 2, y = py - armLen, w = armW, h = armLen * 2},
            fillColor = DOT_COLOR, action = "fill",
        })
        table.insert(elements, {
            type = "oval",
            frame = {x = px - DOT_SIZE / 2, y = py - DOT_SIZE / 2, w = DOT_SIZE, h = DOT_SIZE},
            fillColor = DOT_COLOR, action = "fill",
        })
        local lx = px - LABEL_W / 2
        local ly = py - armLen - LABEL_H - 2
        table.insert(elements, {
            type = "rectangle",
            frame = {x = lx, y = ly, w = LABEL_W, h = LABEL_H},
            fillColor = LABEL_BG, roundedRectRadii = {xRadius = 3, yRadius = 3}, action = "fill",
        })
        table.insert(elements, {
            type = "text",
            frame = {x = lx, y = ly, w = LABEL_W, h = LABEL_H},
            text = JUMP_LABELS[key] or key,
            textAlignment = "center", textColor = LABEL_FG, textFont = "Menlo-Bold", textSize = 11,
        })
    end

    return elements
end

local function refreshGrid(gridSize, mode)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end

    local elements
    if mode == "jump" then
        elements = createJumpGrid(f)
    else
        local pos = hs.mouse.absolutePosition()
        elements = createMoveGrid(gridSize, f, pos.x - f.x, pos.y - f.y)
    end

    gridCanvas = hs.canvas.new({x = f.x, y = f.y, w = f.w, h = f.h})
    gridCanvas:level(hs.canvas.windowLevels.overlay)
    gridCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    gridCanvas:canvasMouseEvents(false)

    for idx, elem in ipairs(elements) do
        gridCanvas[idx] = elem
    end

    gridCanvas:show()
    gridVisible = true
    currentGridSize = gridSize
    currentGridMode = mode
end

local function ensureGrid(gridSize, mode)
    if gridEnabled then
        refreshGrid(gridSize, mode)
    end
end

function M.toggleGrid(gridSize, mode)
    mode = mode or "move"
    if gridEnabled then
        gridEnabled = false
        M.hideGrid()
    else
        gridEnabled = true
        refreshGrid(gridSize, mode)
    end
end

function M.hideGrid()
    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end
    gridVisible = false
    currentGridSize = nil
    currentGridMode = nil
end

-- ============================================================
-- Pixel-based cursor movement (F+D, F+S) — no grid snapping
-- ============================================================

function M.move(direction, amount, gridSize)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()
    local pos = hs.mouse.absolutePosition()

    local cellW = f.w / gridSize
    local cellH = f.h / gridSize

    local x = pos.x
    local y = pos.y

    if direction == "left" then
        if amount < 0 then x = f.x + cellW * 0.5
        else x = x - amount * cellW end
    elseif direction == "right" then
        if amount < 0 then x = f.x + f.w - cellW * 0.5
        else x = x + amount * cellW end
    elseif direction == "up" then
        if amount < 0 then y = f.y + cellH * 0.5
        else y = y - amount * cellH end
    elseif direction == "down" then
        if amount < 0 then y = f.y + f.h - cellH * 0.5
        else y = y + amount * cellH end
    end

    -- Clamp to window bounds
    x = math.max(f.x, math.min(x, f.x + f.w))
    y = math.max(f.y, math.min(y, f.y + f.h))

    hs.mouse.absolutePosition(hs.geometry.point(x, y))
    ensureGrid(gridSize, "move")
    showIndicator()
end

-- Hold-to-repeat: first move immediate, then OS-style delay before continuous repeat
function M.startMove(direction, amount, gridSize)
    M.stopMove()
    ensureGrid(gridSize, "move")
    M.move(direction, amount, gridSize)
    moveTimer = hs.timer.doAfter(REPEAT_DELAY, function()
        M.move(direction, amount, gridSize)
        moveTimer = hs.timer.doEvery(REPEAT_INTERVAL, function()
            M.move(direction, amount, gridSize)
        end)
    end)
end

function M.stopMove()
    if moveTimer then
        moveTimer:stop()
        moveTimer = nil
    end
end

-- ============================================================
-- Fixed-position jumps (F+E)
-- ============================================================

function M.jump(position)
    local pos = JUMP_POSITIONS[position]
    if not pos then return end

    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    local x = f.x + pos[1] * f.w
    local y = f.y + pos[2] * f.h

    hs.mouse.absolutePosition(hs.geometry.point(x, y))
    ensureGrid(8, "jump")
    showIndicator()
end

-- ============================================================
-- Reset — clears movement state, NOT gridEnabled
-- ============================================================

function M.reset()
    -- gridEnabled intentionally preserved
end

return M
