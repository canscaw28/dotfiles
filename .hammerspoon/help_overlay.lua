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

-- Realtime key tracking: layer and mode keys notify layerDown/layerUp
-- continuously (from the Karabiner setters + key_suppress), so while the
-- overlay is open it follows what's held without re-pressing /. The layer
-- picks the view; the full held set narrows it to the matching mode section.
local heldKeys = {}
local isOpen = false
local TRACKED = {a = true, f = true, g = true, t = true, r = true, s = true, d = true}
-- When several layer keys are held, the outer one owns the view: T+R is the
-- T layer's move mode, G+F is G's reorder mode, F+D is F's coarse grid.
local LAYER_PRIORITY = {"t", "g", "f", "a", "r"}

local APP_OF_BUNDLE = {
    ["com.google.Chrome"] = "chrome",
    ["com.googlecode.iterm2"] = "iterm",
}

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
local GAP = 9           -- vertical space inserted between QWERTY row groups
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

-- Drop markdown emphasis and code-span delimiters, but keep backticks that
-- are the content itself: "` `` `" -> "``", and a lone "`" key stays "`".
local function stripMarks(s)
    s = s:gsub("%*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^`+%s?(.-)%s?`+$", "%1")
    return s
end

-- Extract the action key from a combo cell: "[⇪+T+R] + H" -> "H".
-- Plain shortcuts ("⌘ + Z") have no bracket and are returned whole.
local function trigOf(keys)
    local t = keys:match("%]%s*%+%s*(.+)$")
    return stripMarks(t or keys)
end

-- Which physical QWERTY row a trigger key sits on (1=number .. 4=bottom),
-- 0 if unknown. Used to insert a gap between row groups in the sorted list.
local QROW = {}
do
    local rows = {"`1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,./"}
    for r = 1, 4 do
        for ch in rows[r]:gmatch(".") do QROW[ch] = r end
    end
end
local QSHIFT = {
    ["~"]="`", ["!"]="1", ["@"]="2", ["#"]="3", ["$"]="4", ["%"]="5", ["^"]="6",
    ["&"]="7", ["*"]="8", ["("]="9", [")"]="0", ["_"]="-", ["+"]="=", ["{"]="[",
    ["}"]="]", ["|"]="\\", [":"]=";", ['"']="'", ["<"]=",", [">"]=".", ["?"]="/",
}
-- "R+E" -> {"R", "E"}; nil unless every part is a single key.
local function capKeys(trig)
    local parts = {}
    for p in trig:gmatch("[^+]+") do
        if utf8.len(p) ~= 1 then return nil end
        parts[#parts + 1] = p
    end
    return #parts > 0 and parts or nil
end

local function qwertyRow(trig)
    local keys = trig and capKeys(trig)
    if not keys then return 0 end
    return QROW[QSHIFT[keys[1]] or keys[1]:lower()] or 0
end

local function joinDesc(cols)
    local parts = {}
    for _, c in ipairs(cols) do
        local s = stripMarks(c)
        if s ~= "" then parts[#parts + 1] = s end
    end
    return parts
end

local function bindItem(keys, cols, header)
    local parts = joinDesc(cols)
    -- Surround table: | Key | Pair | Shift+Key | Pair | -> "``--``  ⇧ __"
    if header[3] == "Shift+Key" then
        local shifted = stripMarks(cols[3] or "")
        return {
            header = false, trig = trigOf(keys), label = parts[1] or "",
            sub = shifted ~= "" and ("⇧ " .. shifted) or nil,
        }
    end
    -- Show the human description (last column), not the raw key translation
    -- (the Behavior column). Fall back to the only column when there's one.
    return {
        header = false,
        trig = trigOf(keys),
        label = parts[#parts] or "",
        sub = nil,
    }
end

local function sectionItems(section, items)
    items[#items + 1] = {
        header = true, title = section.title, group = section.group,
        chord = section.chord and table.concat(section.chord, "+") or nil,
    }
    for _, row in ipairs(section.rows) do
        items[#items + 1] = bindItem(row.keys, row.cols, section.header)
    end
end

local function frontApp()
    local app = hs.application.frontmostApplication()
    return app and APP_OF_BUNDLE[app:bundleID()] or "other"
end

-- Order-insensitive identity for a set of keys: {"T","R"} and {r=true,t=true}
-- both become "R+T".
local function setKey(list)
    local t = {}
    for _, k in ipairs(list) do t[#t + 1] = k:upper() end
    table.sort(t)
    return table.concat(t, "+")
end

local function heldList(held)
    local t = {}
    for k in pairs(held) do t[#t + 1] = k end
    return t
end

-- Title chord: the layer key first, then any held mode keys ("⇪+T+R").
local function displayChord(layer, held)
    local parts = {"⇪"}
    if layer then parts[#parts + 1] = layer:upper() end
    local modes = {}
    for k in pairs(held) do
        if k ~= layer then modes[#modes + 1] = k:upper() end
    end
    table.sort(modes)
    for _, m in ipairs(modes) do parts[#parts + 1] = m end
    return table.concat(parts, "+")
end

-- Narrow a layer's sections to the frontmost app, then (when a mode key is
-- held) to the sections triggered by exactly the held keys. Each step is
-- skipped when it would leave nothing, so a view is never empty.
local function pickSections(sections, held, app, narrow)
    local forApp = {}
    for _, s in ipairs(sections) do
        if not s.app or s.app == app then forApp[#forApp + 1] = s end
    end
    if #forApp == 0 then forApp = sections end
    if not narrow then return forApp, false end

    local want = setKey(heldList(held))
    local forMode = {}
    for _, s in ipairs(forApp) do
        if setKey(s.chord or {}) == want then forMode[#forMode + 1] = s end
    end
    if #forMode == 0 then return forApp, false end
    return forMode, true
end

local function buildItems(which, held)
    local d = loadData()
    if not d then return nil, "Help data not found — run build_help.py" end
    local items = {}
    local app = frontApp()

    if which == "index" then
        local base = d.layers and d.layers["default"]
        local sections, narrowed = pickSections(base and base.sections or {}, held, app, next(held) ~= nil)
        if not narrowed then
            items[#items + 1] = {header = true, title = "Layers", group = nil}
            for _, e in ipairs(d.index) do
                local cap = e.key == "default" and "⇪" or e.key
                local hint = e.key == "default" and "⇪ alone"
                    or (e.key == "Q" and "⇪+Q" or ("⇪+" .. e.key .. "+?"))
                items[#items + 1] = {
                    header = false, trig = cap,
                    label = e.name, sub = e.domain ~= "" and e.domain or hint,
                }
            end
        end
        -- The base layer has no peek chord; surface it under the index.
        for _, s in ipairs(sections) do sectionItems(s, items) end
        local chord = next(held) and displayChord(nil, held) or "⇪+?"
        return items, nil, "Hotkey Layers", chord
    end

    local L = d.layers and d.layers[which]
    if not L then return nil, "No help for layer " .. tostring(which) end
    local sections = pickSections(L.sections, held, app, #heldList(held) > 1)
    for _, s in ipairs(sections) do sectionItems(s, items) end
    return items, nil, L.name, displayChord(which:lower(), held)
end

-- ── Rendering ────────────────────────────────────────────────────────────

local function styled(text, font, size, color)
    return hs.styledtext.new(text, {
        font = {name = font, size = size}, color = color,
    })
end

local CAP_GAP = 3

local function drawOneCap(c, x, y, trig)
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
end

-- Short triggers get a keycap, "R+E" a row of keycaps; nil means anything
-- longer (e.g. "⌘ + Z"), which renders inline.
local function trigCaps(trig)
    if utf8.len(trig) and utf8.len(trig) <= 2 and not trig:find(" ") then return {trig} end
    return capKeys(trig)
end

-- Where the label would start after this trigger, relative to the slot.
local function labelOffset(trig)
    local keys = trigCaps(trig)
    if keys then return TEXT_X + (#keys - 1) * (CAP + CAP_GAP) end
    return CAP_X + hs.drawing.getTextDrawingSize(styled(trig, FONT_BOLD, FONT_SIZE, TITLE_CHORD)).w + 8
end

-- Draws the trigger at absolute (x, y).
local function drawCap(c, x, y, trig)
    local keys = trigCaps(trig)
    if keys then
        for i, k in ipairs(keys) do
            drawOneCap(c, x + (i - 1) * (CAP + CAP_GAP), y, k)
        end
        return
    end
    c:appendElements({
        type = "text", text = styled(trig, FONT_BOLD, FONT_SIZE, TITLE_CHORD),
        frame = {x = x, y = y + (CAP - FONT_SIZE) / 2 - 1, w = 90, h = 18},
    })
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

function M.show(which, held)
    if fallTimer then fallTimer:stop(); fallTimer = nil end
    if canvas then canvas:delete(); canvas = nil end

    local items, err, title, chord = buildItems(which, held or {})
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local sf = screen:frame()

    if err then
        items = {{header = true, title = err}}
        title, chord = "Help", ""
    end

    -- Insert a gap when the sorted bindings cross into a new QWERTY row,
    -- so each physical row group reads as a cluster. Headers reset grouping.
    local prevGroup
    for _, item in ipairs(items) do
        if item.header then
            prevGroup = nil
            item.gapBefore = false
        else
            local g = qwertyRow(item.trig)
            item.gapBefore = prevGroup ~= nil and prevGroup ~= 0
                and g ~= 0 and g ~= prevGroup
            prevGroup = g
        end
    end

    -- Every label in a section starts at the same x, past its widest trigger,
    -- so a "W E" row doesn't push its description out of line.
    local sectionStart = 1
    for i = 1, #items + 1 do
        local item = items[i]
        if not item or item.header then
            local x = TEXT_X
            for j = sectionStart, i - 1 do x = math.max(x, items[j].textX) end
            for j = sectionStart, i - 1 do items[j].textX = x end
            sectionStart = i + 1
        else
            item.textX = labelOffset(item.trig)
        end
    end

    -- Pack into columns greedily by accumulated height (so gaps fit cleanly).
    local availH = sf.h * 0.84 - TITLE_H - PAD * 2
    local maxCols = math.max(1, math.floor((sf.w * 0.96 - PAD * 2) / COL_W))
    local total = 0
    for _, item in ipairs(items) do
        total = total + SLOT_H + (item.gapBefore and GAP or 0)
    end
    local cols = math.max(1, math.min(maxCols, math.ceil(total / availH)))
    local target = total / cols

    local bodyY = TITLE_H + PAD
    local curCol, curY, maxColH = 0, 0, 0
    for _, item in ipairs(items) do
        local gap = (curY > 0 and item.gapBefore) and GAP or 0
        if curY > 0 and curCol < cols - 1 and curY + gap + SLOT_H > target then
            curCol = curCol + 1; curY = 0; gap = 0
        end
        curY = curY + gap
        item._x = PAD + curCol * COL_W
        item._y = bodyY + curY
        curY = curY + SLOT_H
        if curY > maxColH then maxColH = curY end
    end

    local canvasW = cols * COL_W + PAD * 2
    local canvasH = maxColH + TITLE_H + PAD * 2
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

    -- Items
    for _, item in ipairs(items) do
        local x, y = item._x, item._y

        if item.header then
            local label = item.title or ""
            if item.group then label = item.group .. " · " .. label end
            c:appendElements({
                type = "text", text = styled(label, FONT_BOLD, HEADER_FONT_SIZE, HEADER_COLOR),
                frame = {x = x, y = y + 4, w = COL_W - 14, h = 18},
            }, {
                type = "text",
                text = hs.styledtext.new(item.chord or "", {
                    font = {name = FONT_BOLD, size = HEADER_FONT_SIZE}, color = TITLE_CHORD,
                    paragraphStyle = {alignment = "right"},
                }),
                frame = {x = x, y = y + 4, w = COL_W - 18, h = 18},
            }, {
                type = "rectangle", action = "fill", fillColor = HEADER_RULE,
                frame = {x = x, y = y + SLOT_H - 2, w = COL_W - 18, h = 1},
            })
        else
            drawCap(c, x + CAP_X, y + (SLOT_H - CAP) / 2, item.trig)
            local textX = item.textX
            local label = styled(item.label, FONT, FONT_SIZE, BEHAVIOR_COLOR)
            if item.sub and item.sub ~= "" then
                label = label .. styled("  " .. item.sub, FONT, FONT_SIZE, DESC_COLOR)
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

-- The view is the highest-priority held layer; the held set picks the mode.
local function currentView()
    for _, k in ipairs(LAYER_PRIORITY) do
        if heldKeys[k] then return k:upper() end
    end
    return "index"
end

local function rerender()
    if isOpen then M.show(currentView(), heldKeys) end
end

-- Called on / down/up: open follows whatever keys are already held.
function M.open()
    isOpen = true
    M.show(currentView(), heldKeys)
end

function M.close()
    isOpen = false
    M.hide()
end

-- Called continuously by the layer/mode-key setters (and key_suppress); only
-- redraws while open, so it's a cheap table update the rest of the time.
function M.layerDown(key)
    if not TRACKED[key] then return end
    heldKeys[key] = true
    rerender()
end

function M.layerUp(key)
    if not TRACKED[key] then return end
    heldKeys[key] = nil
    rerender()
end

function M.clearLayers()
    heldKeys = {}
    rerender()
end

return M
