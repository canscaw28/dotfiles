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

-- Palette: a translucent graphite panel. Color is reserved for the chord
-- keycaps; everything else is a step on one neutral ramp.
local function rgba(r, g, b, a) return {red = r, green = g, blue = b, alpha = a or 1} end
local function gray(v, a) return rgba(v, v, v * 1.06, a) end
local PANEL_TOP = gray(0.135, 0.90)
local PANEL_BOTTOM = gray(0.095, 0.90)
local PANEL_BORDER = gray(1, 0.10)
local PANEL_HIGHLIGHT = gray(1, 0.07)   -- 1px lit edge along the top
local SHADOW_COLOR = rgba(0, 0, 0, 0.55)
local RULE = gray(1, 0.07)
local TITLE_COLOR = gray(0.97)
local SUBTITLE_COLOR = gray(0.56)
local HEADER_COLOR = gray(0.60)
local GROUP_COLOR = gray(0.42)
local LABEL_COLOR = gray(0.90)
local SUB_COLOR = gray(0.52)
local CAP_TOP = gray(0.285)
local CAP_BOTTOM = gray(0.215)
local CAP_EDGE = rgba(0, 0, 0, 0.45)
local CAP_BORDER = gray(1, 0.09)
local CAP_SHINE = gray(1, 0.10)
local CAP_TEXT = gray(0.92)
local ACCENT = rgba(0.56, 0.71, 1.0)
local CHORD_TOP = rgba(0.27, 0.40, 0.72, 0.55)
local CHORD_BOTTOM = rgba(0.19, 0.29, 0.56, 0.55)
local CHORD_BORDER = rgba(0.56, 0.71, 1.0, 0.30)
local INLINE_TRIG = rgba(0.56, 0.71, 1.0)

local FONT = ".AppleSystemUIFont"
local FONT_MEDIUM = ".AppleSystemUIFontMedium"
local FONT_DEMI = ".AppleSystemUIFontDemi"
local FONT_BOLD = ".AppleSystemUIFontBold"
local FONT_KEY = ".AppleSystemUIFontMonospaced-Medium"

-- Base metrics in points, scaled per screen by show(): about 0.9x on a
-- MacBook, smaller on shorter displays. Labels are centered on the keycap
-- face, not the slot, so they line up with the glyph.
local BASE = {
    MARGIN = 40,        -- room around the panel for its shadow
    PAD = 22,
    TITLE_H = 58,
    COL_W = 336,
    COL_GUTTER = 34,
    ROW_H = 27,
    GROUP_GAP = 5,      -- extra space between QWERTY row groups
    HEADER_H = 27,
    HEADER_TOP = 14,    -- space above a header that isn't first in its column
    CAP_H = 20,
    CAP_MIN_W = 20,
    CAP_PAD_X = 5.5,    -- glyph inset for keycaps wider than the minimum
    CAP_GAP = 3,
    CAP_RADIUS = 4.5,
    LABEL_GAP = 11,
    KEY_SIZE = 11,
    LABEL_SIZE = 12.5,
    HEADER_SIZE = 10,
    TITLE_SIZE = 17,
    SUBTITLE_SIZE = 11.5,
    CHORD_SIZE = 9,
    TITLE_CHORD_SIZE = 11,
    RADIUS = 16,
}
local m = {}

local function setScale(screenH)
    local s = math.max(0.78, math.min(0.92, screenH / 1200))
    for k, v in pairs(BASE) do m[k] = v * s end
end
setScale(1100)

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
            sub = shifted ~= "" and ("⇧ " .. shifted) or nil, pairs = true,
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

-- The title already shows the layer key, so a section's chord lists only
-- the mode keys held on top of it (Move mode: R, not T+R).
local function sectionItems(section, items, hideGroup, layer)
    local modes = {}
    for _, k in ipairs(section.chord or {}) do
        if k:lower() ~= layer then modes[#modes + 1] = k end
    end
    items[#items + 1] = {
        header = true, title = section.title, group = not hideGroup and section.group or nil,
        chord = table.concat(modes, "+"),
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
    local forApp, byApp = {}, false
    for _, s in ipairs(sections) do
        if not s.app or s.app == app then forApp[#forApp + 1] = s end
        if s.app then byApp = true end
    end
    if #forApp == 0 then forApp, byApp = sections, false end
    if not narrow then return forApp, false, byApp end

    local want = setKey(heldList(held))
    local forMode = {}
    for _, s in ipairs(forApp) do
        if setKey(s.chord or {}) == want then forMode[#forMode + 1] = s end
    end
    if #forMode == 0 then return forApp, false, byApp end
    return forMode, true, byApp
end

local APP_NAME = {chrome = "Chrome", iterm = "iTerm2", other = "other apps"}

local function hasModes(sections)
    for _, s in ipairs(sections) do
        if s.chord and #s.chord > 1 then return true end
    end
    return false
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
                    label = e.name, sub = e.domain ~= "" and e.domain or hint, twoLine = true,
                }
            end
        end
        -- The base layer has no peek chord; surface it under the index.
        for _, s in ipairs(sections) do sectionItems(s, items) end
        local chord = next(held) and displayChord(nil, held) or "⇪+?"
        local subtitle = narrowed and "Showing the held mode"
            or "Hold a layer key with / to see its bindings"
        return items, nil, "Hotkey Layers", chord, subtitle
    end

    local L = d.layers and d.layers[which]
    if not L then return nil, "No help for layer " .. tostring(which) end
    local sections, narrowed, byApp = pickSections(L.sections, held, app, #heldList(held) > 1)
    for _, s in ipairs(sections) do sectionItems(s, items, byApp, which:lower()) end
    local parts = {}
    if byApp then parts[#parts + 1] = "In " .. APP_NAME[app] end
    if narrowed then
        parts[#parts + 1] = "showing the held mode"
    elseif hasModes(sections) then
        parts[#parts + 1] = "hold a mode key to narrow"
    end
    local subtitle = table.concat(parts, " · ")
    subtitle = subtitle:sub(1, 1):upper() .. subtitle:sub(2)
    return items, nil, L.name, displayChord(which:lower(), held), subtitle
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
    if align then st = st:setStyle({paragraphStyle = {alignment = align, lineBreak = "clip"}}) end
    c:appendElements({
        type = "text", text = st,
        frame = {x = x, y = cy - sz.h / 2, w = w or (sz.w + 4), h = sz.h + 2},
    })
end

local function gradientRect(frame, top, bottom, radius)
    return {
        type = "rectangle", action = "fill", frame = frame,
        roundedRectRadii = {xRadius = radius, yRadius = radius},
        fillGradient = "linear", fillGradientColors = {top, bottom}, fillGradientAngle = -90,
    }
end

-- The monospaced face has no ⇪/⌘/⇧, so symbols use the regular system font.
local function keyFont(glyph)
    return glyph:match("^[%w%p]+$") and FONT_KEY or FONT_DEMI
end

-- A keycap is at least square and grows to fit wide glyphs.
local function capWidth(glyph, size)
    return math.max(m.CAP_MIN_W * size / m.KEY_SIZE,
        textSize(styled(glyph, keyFont(glyph), size, CAP_TEXT)).w + 2 * m.CAP_PAD_X)
end

local KEY_STYLE = {top = CAP_TOP, bottom = CAP_BOTTOM, border = CAP_BORDER, color = CAP_TEXT}
local CHORD_STYLE = {top = CHORD_TOP, bottom = CHORD_BOTTOM, border = CHORD_BORDER, color = ACCENT}

-- A keycap: a dark lip below, a softly lit face, a hairline border and a
-- brighter top edge, like light falling from above.
local function drawKeycap(c, x, cy, glyph, size, style)
    local h = m.CAP_H * size / m.KEY_SIZE
    local w = capWidth(glyph, size)
    local y = cy - h / 2
    local r = m.CAP_RADIUS * size / m.KEY_SIZE
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = CAP_EDGE,
        roundedRectRadii = {xRadius = r, yRadius = r},
        frame = {x = x, y = y + 1.5, w = w, h = h},
    }, gradientRect({x = x, y = y, w = w, h = h}, style.top, style.bottom, r), {
        type = "rectangle", action = "stroke", strokeWidth = 1, strokeColor = style.border,
        roundedRectRadii = {xRadius = r, yRadius = r},
        frame = {x = x + 0.5, y = y + 0.5, w = w - 1, h = h - 1},
    }, {
        type = "rectangle", action = "fill", fillColor = CAP_SHINE,
        frame = {x = x + r, y = y + 1, w = w - 2 * r, h = 1},
    })
    drawText(c, styled(glyph, keyFont(glyph), size, style.color), x, cy - 0.5, w, "center")
    return w
end

-- Draw keys left to right from x; returns the total width.
local function drawKeys(c, x, cy, keys, size, style)
    local cx = x
    for i, k in ipairs(keys) do
        if i > 1 then cx = cx + m.CAP_GAP end
        cx = cx + drawKeycap(c, cx, cy, k, size, style)
    end
    return cx - x
end

local function keysWidth(keys, size)
    local w = 0
    for i, k in ipairs(keys) do
        w = w + capWidth(k, size) + (i > 1 and m.CAP_GAP or 0)
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
    return styled(trig, FONT_DEMI, m.LABEL_SIZE, INLINE_TRIG)
end

-- Where the label would start after this trigger, relative to the column.
local function labelOffset(trig)
    local keys = trigCaps(trig)
    if keys then return keysWidth(keys, m.KEY_SIZE) + m.LABEL_GAP end
    return textSize(inlineTrig(trig)).w + m.LABEL_GAP
end

local function drawTrig(c, x, cy, trig)
    local keys = trigCaps(trig)
    if keys then
        drawKeys(c, x, cy, keys, m.KEY_SIZE, KEY_STYLE)
    else
        drawText(c, inlineTrig(trig), x, cy)
    end
end

local function stopAnim()
    if fallTimer then fallTimer:stop(); fallTimer = nil end
end

-- Ease the canvas from (alpha a0, y offset dy0) to (a1, dy1) over `steps`.
local function animate(a0, a1, dy0, dy1, steps, done)
    stopAnim()
    local step = 0
    fallTimer = hs.timer.doEvery(0.016, function()
        step = step + 1
        if not canvas then stopAnim(); return end
        local t = step / steps
        local e = 1 - (1 - t) * (1 - t)
        canvas:topLeft({x = targetX, y = targetY + dy0 + (dy1 - dy0) * e})
        canvas:alpha(a0 + (a1 - a0) * e)
        if step >= steps then
            stopAnim()
            if done then done() end
        end
    end)
end

local closing = false

local function startFall()
    closing = true
    animate(canvas and canvas:alpha() or 1, 0, 0, 8, 8, function()
        if canvas then canvas:delete(); canvas = nil end
    end)
end

function M.show(which, held)
    local wasVisible = canvas ~= nil and not closing
    closing = false
    stopAnim()
    if canvas then canvas:delete(); canvas = nil end

    local items, err, title, chord, subtitle = buildItems(which, held or {})
    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local sf = screen:frame()
    setScale(sf.h)

    if err then
        items = {{header = true, title = err}}
        title, chord, subtitle = "Help", "", nil
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
            local x = m.CAP_MIN_W + m.LABEL_GAP
            for j = sectionStart, i - 1 do x = math.max(x, items[j].textX) end
            for j = sectionStart, i - 1 do items[j].textX = x end
            sectionStart = i + 1
        else
            item.textX = labelOffset(item.trig)
        end
    end

    local function rowH(item)
        return item.twoLine and m.ROW_H * 1.55 or m.ROW_H
    end
    local function heightOf(item, atTop)
        if item.header then return m.HEADER_H + (atTop and 0 or m.HEADER_TOP) end
        return rowH(item) + ((item.gapBefore and not atTop) and m.GROUP_GAP or 0)
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

    local availH = sf.h * 0.82 - m.TITLE_H - m.PAD * 2
    local maxCols = math.max(1, math.floor((sf.w * 0.94 - m.PAD * 2 + m.COL_GUTTER) / (m.COL_W + m.COL_GUTTER)))
    local total = 0
    for i, sec in ipairs(sections) do total = total + sectionHeight(sec, i == 1) end
    local cols = math.max(1, math.min(maxCols, math.ceil(total / availH)))
    local target = total / cols

    local O = m.MARGIN
    local bodyY = O + m.PAD + m.TITLE_H
    local curCol, curY, maxColH = 0, 0, 0
    local function nextColumn()
        curCol = curCol + 1; curY = 0
    end
    for _, sec in ipairs(sections) do
        if curY > 0 and curCol < cols - 1
            and curY + sectionHeight(sec, false) > target + m.ROW_H then
            nextColumn()
        end
        for _, item in ipairs(sec) do
            local h = heightOf(item, curY == 0)
            if curY > 0 and curCol < cols - 1 and curY + h > availH then
                nextColumn(); h = heightOf(item, true)
            end
            item._x = O + m.PAD + curCol * (m.COL_W + m.COL_GUTTER)
            item._y = bodyY + curY + (h - (item.header and m.HEADER_H or rowH(item)))
            curY = curY + h
            if curY > maxColH then maxColH = curY end
        end
    end
    cols = curCol + 1

    local panelW = cols * m.COL_W + (cols - 1) * m.COL_GUTTER + m.PAD * 2
    local panelH = m.TITLE_H + maxColH + m.PAD * 2 - m.ROW_H * 0.2
    local canvasW, canvasH = panelW + 2 * O, panelH + 2 * O
    targetX = sf.x + (sf.w - canvasW) / 2
    targetY = sf.y + (sf.h - canvasH) / 2

    local c = hs.canvas.new({x = targetX, y = targetY, w = canvasW, h = canvasH})
    c:level(hs.canvas.windowLevels.overlay + 1)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    c:clickActivating(false)
    c:canvasMouseEvents(false)

    local panel = {x = O, y = O, w = panelW, h = panelH}
    local R = m.RADIUS
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = PANEL_BOTTOM, frame = panel,
        roundedRectRadii = {xRadius = R, yRadius = R},
        withShadow = true,
        shadow = {blurRadius = O * 0.75, color = SHADOW_COLOR, offset = {h = -O * 0.2, w = 0}},
    }, gradientRect(panel, PANEL_TOP, PANEL_BOTTOM, R), {
        type = "rectangle", action = "stroke", strokeWidth = 1, strokeColor = PANEL_BORDER,
        roundedRectRadii = {xRadius = R, yRadius = R},
        frame = {x = O + 0.5, y = O + 0.5, w = panelW - 1, h = panelH - 1},
    }, {
        type = "rectangle", action = "fill", fillColor = PANEL_HIGHLIGHT,
        frame = {x = O + R, y = O + 1, w = panelW - 2 * R, h = 1},
    })

    -- Title block: name and a one-line context note left, held chord right.
    local left = O + m.PAD
    local titleCY = O + m.PAD + m.TITLE_SIZE * 0.55
    drawText(c, styled(title, FONT_BOLD, m.TITLE_SIZE, TITLE_COLOR, {kerning = -0.2}),
        left, titleCY, panelW - m.PAD * 2)
    if subtitle and subtitle ~= "" then
        drawText(c, styled(subtitle, FONT, m.SUBTITLE_SIZE, SUBTITLE_COLOR),
            left, titleCY + m.TITLE_SIZE * 1.05, panelW - m.PAD * 2)
    end
    local chordKeys = splitChord(chord)
    if #chordKeys > 0 then
        local w = keysWidth(chordKeys, m.TITLE_CHORD_SIZE)
        drawKeys(c, O + panelW - m.PAD - w, titleCY + m.TITLE_SIZE * 0.35, chordKeys,
            m.TITLE_CHORD_SIZE, CHORD_STYLE)
    end
    c:appendElements({
        type = "rectangle", action = "fill", fillColor = RULE,
        frame = {x = left, y = O + m.PAD + m.TITLE_H - m.PAD * 0.75, w = panelW - m.PAD * 2, h = 1},
    })

    for _, item in ipairs(items) do
        local x, y = item._x, item._y
        if item.header then
            local cy = y + m.HEADER_H / 2 - 2
            local tracking = {kerning = 0.9}
            local label = styled((item.title or ""):upper(), FONT_DEMI, m.HEADER_SIZE, HEADER_COLOR, tracking)
            if item.group then
                label = styled(item.group:upper() .. "  /  ", FONT_DEMI, m.HEADER_SIZE, GROUP_COLOR, tracking) .. label
            end
            local keys = splitChord(item.chord)
            local chordW = #keys > 0 and keysWidth(keys, m.CHORD_SIZE) or 0
            drawText(c, label, x, cy, m.COL_W - chordW - 8)
            if #keys > 0 then drawKeys(c, x + m.COL_W - chordW, cy, keys, m.CHORD_SIZE, CHORD_STYLE) end
            c:appendElements({
                type = "rectangle", action = "fill", fillColor = RULE,
                frame = {x = x, y = y + m.HEADER_H - 4, w = m.COL_W, h = 1},
            })
        elseif item.twoLine then
            -- Two lines: name, then a muted description, around the keycap's center.
            local cy = y + rowH(item) / 2
            drawTrig(c, x, cy, item.trig)
            local w = m.COL_W - item.textX
            drawText(c, styled(item.label, FONT_MEDIUM, m.LABEL_SIZE, LABEL_COLOR),
                x + item.textX, cy - m.LABEL_SIZE * 0.58, w)
            drawText(c, styled(item.sub, FONT, m.SUBTITLE_SIZE, SUB_COLOR),
                x + item.textX, cy + m.LABEL_SIZE * 0.62, w)
        else
            local cy = y + m.ROW_H / 2
            drawTrig(c, x, cy, item.trig)
            if item.pairs then
                -- Symbol pairs: monospaced, shifted pair in its own column.
                drawText(c, styled(item.label, FONT_KEY, m.LABEL_SIZE, LABEL_COLOR), x + item.textX, cy)
                if item.sub then
                    drawText(c, styled(item.sub, FONT_KEY, m.LABEL_SIZE, SUB_COLOR),
                        x + item.textX + m.LABEL_SIZE * 4, cy)
                end
            else
                drawText(c, styled(item.label, FONT, m.LABEL_SIZE, LABEL_COLOR),
                    x + item.textX, cy, m.COL_W - item.textX)
            end
        end
    end

    canvas = c
    if wasVisible then
        c:alpha(1)
        c:show()
    else
        c:alpha(0)
        c:show()
        animate(0, 1, 6, 0, 9)
    end
end

function M.hide()
    if not canvas or closing then return end
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
