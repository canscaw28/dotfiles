-- help_overlay.lua
-- Momentary hotkey cheat-sheet overlay. Held while caps+? (index) or
-- caps+<layer>+? is pressed; hidden on release. Data comes from
-- help_data.json, generated from karabiner/README.md by build_help.py —
-- so this overlay can never drift from the documented keybindings.

local M = {}

local canvas = nil
local fallTimer = nil
local targetX, targetY = nil, nil
local data = nil
local dataMtime = nil

local DATA_PATH = hs.configdir .. "/help_data.json"

-- Palette (dark glass panel; blue section headers; gray keycaps)
local PANEL_BG = {red = 0.08, green = 0.08, blue = 0.10, alpha = 0.94}
local PANEL_BORDER = {red = 0.32, green = 0.55, blue = 0.92, alpha = 0.9}
local TITLE_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local TITLE_CHORD = {red = 0.45, green = 0.68, blue = 1.0, alpha = 1}
local HEADER_COLOR = {red = 0.55, green = 0.75, blue = 1.0, alpha = 1}
local HEADER_RULE = {red = 0.30, green = 0.40, blue = 0.60, alpha = 0.6}
local GROUP_COLOR = {red = 0.55, green = 0.55, blue = 0.60, alpha = 1}
local BEHAVIOR_COLOR = {red = 0.94, green = 0.94, blue = 0.96, alpha = 1}
local DESC_COLOR = {red = 0.60, green = 0.60, blue = 0.64, alpha = 1}
local CAP_FACE = {red = 0.40, green = 0.40, blue = 0.43, alpha = 1}
local CAP_EDGE = {red = 0.24, green = 0.24, blue = 0.27, alpha = 1}
local CAP_BORDER = {red = 0.58, green = 0.58, blue = 0.62, alpha = 1}
local CAP_TEXT = {red = 1, green = 1, blue = 1, alpha = 1}

local FONT = "Helvetica Neue"
local FONT_BOLD = "Helvetica Neue Bold"

local TITLE_H = 44
local SLOT_H = 24
local PAD = 18
local COL_W = 360
local CAP = 21          -- keycap size
local CAP_X = 6         -- keycap left inset within a slot
local TEXT_X = CAP_X + CAP + 10  -- where behavior text starts
local FONT_SIZE = 13
local HEADER_FONT_SIZE = 13
local TITLE_FONT_SIZE = 19

-- ── Data ───────────────────────────────────────────────────────────────

local function loadData()
    local attrs = hs.fs.attributes(DATA_PATH)
    local mtime = attrs and attrs.modification or nil
    if data and mtime == dataMtime then return data end
    local ok, parsed = pcall(hs.json.read, DATA_PATH)
    if ok and parsed then
        data = parsed
        dataMtime = mtime
    end
    return data
end

-- ── Item model ──────────────────────────────────────────────────────────
-- Flatten a layer (or the index) into uniform-height slots so columns pack
-- evenly. Each item is either a section {header=true} or a binding.

local function stripMarks(s)
    return (s:gsub("[%*`]", "")):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Extract the action key from a combo cell: "[⇪+T+R] + H" -> "H".
-- Plain shortcuts ("⌘ + Z") have no bracket and are returned whole.
local function trigOf(keys)
    local t = keys:match("%]%s*%+%s*(.+)$")
    return stripMarks(t or keys)
end

local function joinDesc(cols)
    local parts = {}
    for _, c in ipairs(cols) do
        local s = stripMarks(c)
        if s ~= "" then parts[#parts + 1] = s end
    end
    return parts
end

local function bindItem(keys, cols)
    local parts = joinDesc(cols)
    return {
        header = false,
        trig = trigOf(keys),
        behavior = parts[1] or "",
        desc = parts[2] or "",
    }
end

local function sectionItems(section, items)
    items[#items + 1] = {header = true, title = section.title, group = section.group}
    for _, row in ipairs(section.rows) do
        items[#items + 1] = bindItem(row.keys, row.cols)
    end
end

local function buildItems(which)
    local d = loadData()
    if not d then return nil, "Help data not found — run build_help.py" end
    local items = {}
    local title, chord

    if which == "index" then
        title, chord = "Hotkey Layers", "⇪+?"
        items[#items + 1] = {header = true, title = "Layers", group = nil}
        for _, e in ipairs(d.index) do
            local cap = e.key == "default" and "⇪" or e.key
            local hint = e.key == "default" and "⇪ alone"
                or (e.key == "Q" and "⇪+Q" or ("⇪+" .. e.key .. "+?"))
            items[#items + 1] = {
                header = false, trig = cap,
                behavior = e.name, desc = e.domain ~= "" and e.domain or hint,
            }
        end
        -- The base layer has no peek chord; surface it under the index.
        local base = d.layers and d.layers["default"]
        if base then
            for _, s in ipairs(base.sections) do sectionItems(s, items) end
        end
        return items, nil, title, chord
    end

    local L = d.layers and d.layers[which]
    if not L then return nil, "No help for layer " .. tostring(which) end
    title = L.name
    chord = which == "default" and "⇪" or ("⇪+" .. which)
    for _, s in ipairs(L.sections) do sectionItems(s, items) end
    return items, nil, title, chord
end

-- ── Rendering ────────────────────────────────────────────────────────────

local function styled(text, font, size, color)
    return hs.styledtext.new(text, {
        font = {name = font, size = size}, color = color,
    })
end

local function drawCap(c, x, y, trig)
    -- Short triggers get a keycap; longer ones (e.g. "⌘ + Z") render inline.
    if utf8.len(trig) and utf8.len(trig) <= 2 and not trig:find(" ") then
        c:appendElements({
            type = "rectangle", action = "fill", fillColor = CAP_EDGE,
            roundedRectRadii = {xRadius = 5, yRadius = 5},
            frame = {x = x, y = y + 2, w = CAP, h = CAP},
        }, {
            type = "rectangle", action = "fill", fillColor = CAP_FACE,
            roundedRectRadii = {xRadius = 5, yRadius = 5},
            frame = {x = x, y = y, w = CAP, h = CAP},
        }, {
            type = "rectangle", action = "stroke", strokeWidth = 1, strokeColor = CAP_BORDER,
            roundedRectRadii = {xRadius = 5, yRadius = 5},
            frame = {x = x, y = y, w = CAP, h = CAP},
        }, {
            type = "text",
            text = hs.styledtext.new(trig, {
                font = {name = FONT_BOLD, size = 12}, color = CAP_TEXT,
                paragraphStyle = {alignment = "center"},
            }),
            frame = {x = x - 1, y = y + (CAP - 14) / 2, w = CAP + 2, h = 16},
        })
        return TEXT_X
    end
    -- Inline accent label for compound triggers
    c:appendElements({
        type = "text", text = styled(trig, FONT_BOLD, FONT_SIZE, TITLE_CHORD),
        frame = {x = x, y = y + (CAP - FONT_SIZE) / 2 - 1, w = 90, h = 18},
    })
    local w = hs.drawing.getTextDrawingSize(styled(trig, FONT_BOLD, FONT_SIZE, TITLE_CHORD)).w
    return x + w + 8
end

local function startFall()
    local step = 0
    fallTimer = hs.timer.doEvery(0.02, function()
        step = step + 1
        if not canvas then
            if fallTimer then fallTimer:stop(); fallTimer = nil end
            return
        end
        if step >= 8 then
            if fallTimer then fallTimer:stop(); fallTimer = nil end
            if canvas then canvas:delete(); canvas = nil end
        else
            local t = step / 8
            canvas:topLeft({x = targetX, y = targetY + 12 * t})
            canvas:alpha(1 - t)
        end
    end)
end

function M.show(which)
    if fallTimer then fallTimer:stop(); fallTimer = nil end
    if canvas then canvas:delete(); canvas = nil end

    local items, err, title, chord = buildItems(which)
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local sf = screen:frame()

    if err then
        items = {{header = true, title = err}}
        title, chord = "Help", ""
    end

    -- Pack items into balanced columns that fit the screen height.
    local availH = sf.h * 0.84 - TITLE_H - PAD * 2
    local perCol = math.max(1, math.floor(availH / SLOT_H))
    local cols = math.max(1, math.ceil(#items / perCol))
    local maxCols = math.max(1, math.floor((sf.w * 0.96 - PAD * 2) / COL_W))
    cols = math.min(cols, maxCols)
    perCol = math.ceil(#items / cols)

    local canvasW = cols * COL_W + PAD * 2
    local canvasH = perCol * SLOT_H + TITLE_H + PAD * 2
    targetX = sf.x + (sf.w - canvasW) / 2
    targetY = sf.y + (sf.h - canvasH) / 2

    local c = hs.canvas.new({x = targetX, y = targetY, w = canvasW, h = canvasH})
    c:level(hs.canvas.windowLevels.overlay + 1)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    c:clickActivating(false)
    c:canvasMouseEvents(false)

    -- Panel
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = PANEL_BG,
        roundedRectRadii = {xRadius = 16, yRadius = 16},
    }, {
        type = "rectangle", action = "stroke", strokeWidth = 2, strokeColor = PANEL_BORDER,
        roundedRectRadii = {xRadius = 16, yRadius = 16},
    })

    -- Title bar
    c:appendElements({
        type = "text", text = styled(title, FONT_BOLD, TITLE_FONT_SIZE, TITLE_COLOR),
        frame = {x = PAD, y = PAD - 2, w = canvasW - PAD * 2 - 80, h = 28},
    }, {
        type = "text",
        text = hs.styledtext.new(chord, {
            font = {name = FONT_BOLD, size = TITLE_FONT_SIZE}, color = TITLE_CHORD,
            paragraphStyle = {alignment = "right"},
        }),
        frame = {x = canvasW - PAD - 160, y = PAD - 2, w = 160, h = 28},
    }, {
        type = "rectangle", action = "fill", fillColor = HEADER_RULE,
        frame = {x = PAD, y = TITLE_H + PAD - 8, w = canvasW - PAD * 2, h = 1},
    })

    -- Items, column-major
    local bodyY = TITLE_H + PAD
    for idx, item in ipairs(items) do
        local col = math.floor((idx - 1) / perCol)
        local row = (idx - 1) % perCol
        local x = PAD + col * COL_W
        local y = bodyY + row * SLOT_H

        if item.header then
            local label = item.title or ""
            if item.group then label = item.group .. " · " .. label end
            c:appendElements({
                type = "text", text = styled(label, FONT_BOLD, HEADER_FONT_SIZE, HEADER_COLOR),
                frame = {x = x, y = y + 4, w = COL_W - 14, h = 18},
            }, {
                type = "rectangle", action = "fill", fillColor = HEADER_RULE,
                frame = {x = x, y = y + SLOT_H - 2, w = COL_W - 18, h = 1},
            })
        else
            local textX = drawCap(c, x + CAP_X, y + (SLOT_H - CAP) / 2, item.trig)
            local label = styled(item.behavior, FONT, FONT_SIZE, BEHAVIOR_COLOR)
            if item.desc ~= "" then
                label = label .. styled("  " .. item.desc, FONT, FONT_SIZE, DESC_COLOR)
            end
            c:appendElements({
                type = "text", text = label,
                frame = {x = x + textX, y = y + (SLOT_H - FONT_SIZE) / 2 - 2,
                         w = COL_W - textX - 12, h = 18},
            })
        end
    end

    c:alpha(1)
    c:show()
    canvas = c
end

function M.hide()
    if not canvas then return end
    if fallTimer then return end  -- already fading
    startFall()
end

return M
