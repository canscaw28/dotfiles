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

-- Palette: a quiet dark panel; accent blue is reserved for headers and chords.
local function rgba(r, g, b, a) return {red = r, green = g, blue = b, alpha = a or 1} end
local PANEL_BG = rgba(0.085, 0.09, 0.105, 0.97)
local PANEL_BORDER = rgba(1, 1, 1, 0.10)
local RULE = rgba(1, 1, 1, 0.08)
local TITLE_COLOR = rgba(1, 1, 1)
local ACCENT = rgba(0.50, 0.68, 1.0)
local GROUP_COLOR = rgba(0.56, 0.58, 0.64)
local LABEL_COLOR = rgba(0.91, 0.92, 0.95)
local SUB_COLOR = rgba(0.56, 0.58, 0.63)
local CAP_FACE = rgba(0.21, 0.22, 0.26)
local CAP_EDGE = rgba(0.11, 0.115, 0.14)
local CAP_BORDER = rgba(1, 1, 1, 0.13)
local CAP_TEXT = rgba(0.95, 0.96, 0.98)
local CHORD_FACE = rgba(0.17, 0.24, 0.38)
local CHORD_BORDER = rgba(0.50, 0.68, 1.0, 0.35)

local FONT = ".AppleSystemUIFont"
local FONT_MEDIUM = ".AppleSystemUIFontMedium"
local FONT_DEMI = ".AppleSystemUIFontDemi"
local FONT_BOLD = ".AppleSystemUIFontBold"
local FONT_KEY = ".AppleSystemUIFontMonospaced-Semibold"

-- Sizes. A row is one keycap tall plus breathing room; labels are centered
-- on the keycap face, not on the slot, so they line up with the glyph.
local PAD = 24
local TITLE_H = 54
local COL_W = 372
local COL_GUTTER = 32
local ROW_H = 30
local GROUP_GAP = 6     -- extra space between QWERTY row groups
local HEADER_H = 30
local HEADER_TOP = 12   -- space above a header that isn't first in its column
local CAP_H = 22
local CAP_MIN_W = 22
local CAP_PAD_X = 6     -- glyph inset for keycaps wider than the minimum
local CAP_GAP = 4
local CAP_RADIUS = 5
local LABEL_GAP = 12    -- keycap to label
local KEY_SIZE = 12
local LABEL_SIZE = 13.5
local HEADER_SIZE = 11.5
local TITLE_SIZE = 20

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

local function styled(text, font, size, color, extra)
    local attrs = {font = {name = font, size = size}, color = color}
    for k, v in pairs(extra or {}) do attrs[k] = v end
    return hs.styledtext.new(text, attrs)
end

local function textSize(st)
    return hs.drawing.getTextDrawingSize(st)
end

-- Draw styled text vertically centered on cy.
local function drawText(c, st, x, cy, w, align)
    local sz = textSize(st)
    if align then st = st:setStyle({paragraphStyle = {alignment = align}}) end
    c:appendElements({
        type = "text", text = st,
        frame = {x = x, y = cy - sz.h / 2, w = w or (sz.w + 4), h = sz.h + 2},
    })
end

-- The monospaced face has no ⇪/⌘/⇧, so symbols use the regular system font.
local function keyFont(glyph)
    return glyph:match("^[%w%p]+$") and FONT_KEY or FONT_DEMI
end

-- A keycap is at least square and grows to fit wide glyphs.
local function capWidth(glyph, size)
    return math.max(CAP_MIN_W * size / KEY_SIZE,
        textSize(styled(glyph, keyFont(glyph), size, CAP_TEXT)).w + 2 * CAP_PAD_X)
end

local function drawKeycap(c, x, cy, glyph, opts)
    opts = opts or {}
    local size = opts.size or KEY_SIZE
    local h = CAP_H * size / KEY_SIZE
    local w = capWidth(glyph, size)
    local y = cy - h / 2
    local r = {xRadius = CAP_RADIUS, yRadius = CAP_RADIUS}
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = CAP_EDGE,
        roundedRectRadii = r, frame = {x = x, y = y + 1.5, w = w, h = h},
    }, {
        type = "rectangle", action = "fill", fillColor = opts.face or CAP_FACE,
        roundedRectRadii = r, frame = {x = x, y = y, w = w, h = h},
    }, {
        type = "rectangle", action = "stroke", strokeWidth = 1,
        strokeColor = opts.border or CAP_BORDER,
        roundedRectRadii = r, frame = {x = x + 0.5, y = y + 0.5, w = w - 1, h = h - 1},
    })
    drawText(c, styled(glyph, keyFont(glyph), size, opts.color or CAP_TEXT), x, cy, w, "center")
    return w
end

-- Draw keys left to right from x; returns the total width.
local function drawKeys(c, x, cy, keys, opts)
    local cx = x
    for i, k in ipairs(keys) do
        if i > 1 then cx = cx + CAP_GAP end
        cx = cx + drawKeycap(c, cx, cy, k, opts)
    end
    return cx - x
end

local function keysWidth(keys, size)
    local w = 0
    for i, k in ipairs(keys) do
        w = w + capWidth(k, size or KEY_SIZE) + (i > 1 and CAP_GAP or 0)
    end
    return w
end

local function splitChord(chord)
    local keys = {}
    for k in (chord or ""):gmatch("[^+]+") do keys[#keys + 1] = k end
    return keys
end

-- Short triggers get a keycap, "R+E" a row of keycaps; nil means anything
-- longer (e.g. "⌘ + Z"), which renders inline.
local function trigCaps(trig)
    if utf8.len(trig) and utf8.len(trig) <= 2 and not trig:find(" ") then return {trig} end
    return capKeys(trig)
end

local function inlineTrig(trig)
    return styled(trig, FONT_DEMI, LABEL_SIZE, ACCENT)
end

-- Where the label would start after this trigger, relative to the column.
local function labelOffset(trig)
    local keys = trigCaps(trig)
    if keys then return keysWidth(keys) + LABEL_GAP end
    return textSize(inlineTrig(trig)).w + LABEL_GAP
end

local function drawTrig(c, x, cy, trig)
    local keys = trigCaps(trig)
    if keys then
        drawKeys(c, x, cy, keys)
    else
        drawText(c, inlineTrig(trig), x, cy)
    end
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

local CHORD_OPTS = {size = 10.5, face = CHORD_FACE, border = CHORD_BORDER, color = ACCENT}
local TITLE_CHORD_OPTS = {size = 13, face = CHORD_FACE, border = CHORD_BORDER, color = ACCENT}

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
            local x = CAP_MIN_W + LABEL_GAP
            for j = sectionStart, i - 1 do x = math.max(x, items[j].textX) end
            for j = sectionStart, i - 1 do items[j].textX = x end
            sectionStart = i + 1
        else
            item.textX = labelOffset(item.trig)
        end
    end

    local function heightOf(item, atTop)
        if item.header then return HEADER_H + (atTop and 0 or HEADER_TOP) end
        return ROW_H + ((item.gapBefore and not atTop) and GROUP_GAP or 0)
    end

    -- Pack whole sections into columns so a section never splits; only one
    -- taller than the screen breaks mid-way.
    local sections = {}
    for _, item in ipairs(items) do
        if item.header or #sections == 0 then sections[#sections + 1] = {} end
        table.insert(sections[#sections], item)
    end
    local function sectionHeight(sec, atTop)
        local h = 0
        for i, item in ipairs(sec) do h = h + heightOf(item, atTop and i == 1) end
        return h
    end

    local availH = sf.h * 0.84 - TITLE_H - PAD * 2
    local maxCols = math.max(1, math.floor((sf.w * 0.96 - PAD * 2 + COL_GUTTER) / (COL_W + COL_GUTTER)))
    local total = 0
    for i, sec in ipairs(sections) do total = total + sectionHeight(sec, i == 1) end
    local cols = math.max(1, math.min(maxCols, math.ceil(total / availH)))
    local target = total / cols

    local bodyY = PAD + TITLE_H
    local curCol, curY, maxColH = 0, 0, 0
    local function nextColumn()
        curCol = curCol + 1; curY = 0
    end
    for _, sec in ipairs(sections) do
        if curY > 0 and curCol < cols - 1
            and curY + sectionHeight(sec, false) > target + ROW_H then
            nextColumn()
        end
        for _, item in ipairs(sec) do
            local h = heightOf(item, curY == 0)
            if curY > 0 and curCol < cols - 1 and curY + h > availH then
                nextColumn(); h = heightOf(item, true)
            end
            item._x = PAD + curCol * (COL_W + COL_GUTTER)
            item._y = bodyY + curY + (h - (item.header and HEADER_H or ROW_H))
            curY = curY + h
            if curY > maxColH then maxColH = curY end
        end
    end
    cols = curCol + 1

    local canvasW = cols * COL_W + (cols - 1) * COL_GUTTER + PAD * 2
    local canvasH = bodyY + maxColH + PAD - 4
    targetX = sf.x + (sf.w - canvasW) / 2
    targetY = sf.y + (sf.h - canvasH) / 2

    local c = hs.canvas.new({x = targetX, y = targetY, w = canvasW, h = canvasH})
    c:level(hs.canvas.windowLevels.overlay + 1)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    c:clickActivating(false)
    c:canvasMouseEvents(false)

    c:appendElements({
        type = "rectangle", action = "fill", fillColor = PANEL_BG,
        roundedRectRadii = {xRadius = 14, yRadius = 14},
    }, {
        type = "rectangle", action = "stroke", strokeWidth = 1, strokeColor = PANEL_BORDER,
        roundedRectRadii = {xRadius = 14, yRadius = 14},
        frame = {x = 0.5, y = 0.5, w = canvasW - 1, h = canvasH - 1},
    })

    -- Title: layer name left, held chord as keycaps right.
    local titleCY = PAD + 14
    drawText(c, styled(title, FONT_BOLD, TITLE_SIZE, TITLE_COLOR), PAD, titleCY, canvasW - PAD * 2)
    local chordKeys = splitChord(chord)
    if #chordKeys > 0 then
        local w = keysWidth(chordKeys, TITLE_CHORD_OPTS.size)
        drawKeys(c, canvasW - PAD - w, titleCY, chordKeys, TITLE_CHORD_OPTS)
    end
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = RULE,
        frame = {x = PAD, y = PAD + TITLE_H - 16, w = canvasW - PAD * 2, h = 1},
    })

    for _, item in ipairs(items) do
        local x, y = item._x, item._y
        if item.header then
            local cy = y + HEADER_H / 2 - 3
            local label = styled((item.title or ""):upper(), FONT_DEMI, HEADER_SIZE, ACCENT, {kerning = 0.6})
            if item.group then
                label = styled(item.group:upper() .. "  ·  ", FONT_DEMI, HEADER_SIZE, GROUP_COLOR, {kerning = 0.6}) .. label
            end
            local keys = splitChord(item.chord)
            local chordW = #keys > 0 and keysWidth(keys, CHORD_OPTS.size) or 0
            drawText(c, label, x, cy, COL_W - chordW - 8)
            if #keys > 0 then drawKeys(c, x + COL_W - chordW, cy, keys, CHORD_OPTS) end
            c:appendElements({
                type = "rectangle", action = "fill", fillColor = RULE,
                frame = {x = x, y = y + HEADER_H - 5, w = COL_W, h = 1},
            })
        else
            local cy = y + ROW_H / 2
            drawTrig(c, x, cy, item.trig)
            local label = styled(item.label, item.sub and FONT_MEDIUM or FONT, LABEL_SIZE, LABEL_COLOR)
            if item.sub and item.sub ~= "" then
                label = label .. styled("   " .. item.sub, FONT, LABEL_SIZE, SUB_COLOR)
            end
            drawText(c, label, x + item.textX, cy, COL_W - item.textX)
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
