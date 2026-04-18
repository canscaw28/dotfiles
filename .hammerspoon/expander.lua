-- expander.lua
-- Text expander that avoids macOS Text Replacement collisions.
--
-- Why this exists: in Chromium/Electron apps (Notion, etc.), macOS TR
-- commits its suggestion on ANY text mutation after the trigger, including
-- plain backspace. Espanso's Inject and Clipboard backends both delete the
-- trigger via backspace, which commits the TR bubble → doubled output.
--
-- Strategy:
--   1. Eventtap CONSUMES the final character of the trigger, so macOS TR
--      never sees the full trigger and never shows the bubble.
--   2. Remaining prefix is deleted via Option+Delete (word-delete), which
--      the user verified does NOT commit the TR bubble.
--   3. Replacement is pasted atomically via the clipboard.

local M = {}

local DOTFILES = os.getenv("HOME") .. "/dev/dotfiles"
local YAML_DIR = DOTFILES .. "/text-expander"
local YAML_FILES = {"base.yml", "personal.yml"}

local matches = {}
local maxTriggerLen = 0
local buffer = ""
local suppressing = false

-- ── YAML loader ─────────────────────────────────────────────────────────
-- Narrow format only: `- trigger: "X"` followed by `replace: "Y"`.
-- Single-line, double-quoted values. Ignores everything else.

local function loadYAML(path)
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()

    local pending = nil
    for line in content:gmatch("[^\n]+") do
        local t = line:match('^%s*%-%s*trigger:%s*"(.-)"%s*$')
        if t then
            pending = t
        elseif pending then
            local r = line:match('^%s*replace:%s*"(.-)"%s*$')
            if r then
                matches[pending] = r
                if #pending > maxTriggerLen then maxTriggerLen = #pending end
                pending = nil
            end
        end
    end
end

-- ── Placeholder substitution ────────────────────────────────────────────

local function substitute(replacement)
    replacement = replacement:gsub("{{date}}", function()
        return os.date("%Y-%m-%d")
    end)
    replacement = replacement:gsub("{{time}}", function()
        local t = os.date("%l:%M%p")
        return (t:gsub("^%s+", "")):lower()
    end)
    replacement = replacement:gsub("{{now}}", function()
        return os.date("%Y-%m-%d %H:%M")
    end)
    return replacement
end

-- ── Segment counter (determines Option+Delete repetitions) ──────────────
-- Option+Delete removes one "word chunk" per press. A chunk is a run of
-- word-chars or a run of non-word-chars.

local function countSegments(s)
    local segs, prev = 0, nil
    for i = 1, #s do
        local c = s:sub(i, i)
        local ty = c:match("[%w_]") and "w" or "p"
        if ty ~= prev then
            segs = segs + 1
            prev = ty
        end
    end
    return segs
end

-- ── Expansion ───────────────────────────────────────────────────────────

local function expand(trigger)
    local replacement = substitute(matches[trigger])
    -- We consumed the final trigger char; what's in the app is trigger[1..n-1].
    local prefix = trigger:sub(1, -2)
    local nDeletes = countSegments(prefix)

    suppressing = true
    buffer = ""

    -- Tiny delay so the consumed keyDown finishes propagating before we
    -- start injecting our own events.
    hs.timer.doAfter(0.02, function()
        for _ = 1, nDeletes do
            hs.eventtap.keyStroke({"alt"}, "delete", 0)
        end
        hs.timer.doAfter(0.03, function()
            local oldClip = hs.pasteboard.getContents()
            hs.pasteboard.setContents(replacement)
            hs.eventtap.keyStroke({"cmd"}, "v", 0)
            hs.timer.doAfter(0.15, function()
                if oldClip then
                    hs.pasteboard.setContents(oldClip)
                end
                suppressing = false
            end)
        end)
    end)
end

-- ── Eventtap ────────────────────────────────────────────────────────────

local function buildResetKeys()
    local r = {}
    for _, name in ipairs({
        "escape", "return", "padenter", "tab",
        "left", "right", "up", "down",
        "home", "end", "pageup", "pagedown",
    }) do
        local kc = hs.keycodes.map[name]
        if kc then r[kc] = true end
    end
    return r
end

local RESET_KEYS = buildResetKeys()
local DELETE_KC = hs.keycodes.map["delete"]

M.handler = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(event)
        if suppressing then return false end

        local keyCode = event:getKeyCode()
        local flags = event:getFlags()

        if RESET_KEYS[keyCode] then
            buffer = ""
            return false
        end

        -- Any non-shift modifier chord resets the buffer. Shift is OK
        -- (needed to type ; on some layouts, and for capitalization).
        if flags.cmd or flags.ctrl or flags.alt or flags.fn then
            buffer = ""
            return false
        end

        if keyCode == DELETE_KC then
            if #buffer > 0 then buffer = buffer:sub(1, -2) end
            return false
        end

        local chars = event:getCharacters(false) or ""
        if chars == "" or #chars > 1 then
            buffer = ""
            return false
        end

        buffer = buffer .. chars
        if #buffer > maxTriggerLen then
            buffer = buffer:sub(-maxTriggerLen)
        end

        for trigger, _ in pairs(matches) do
            if #trigger <= #buffer and buffer:sub(-#trigger) == trigger then
                expand(trigger)
                return true
            end
        end

        return false
    end
)

-- ── Public API ──────────────────────────────────────────────────────────

function M.reload()
    matches = {}
    maxTriggerLen = 0
    buffer = ""
    for _, fname in ipairs(YAML_FILES) do
        loadYAML(YAML_DIR .. "/" .. fname)
    end
end

function M.start()
    M.reload()
    M.handler:start()
end

function M.stop()
    if M.handler then M.handler:stop() end
end

M.watcher = hs.pathwatcher.new(YAML_DIR, function()
    M.reload()
end)

M.start()
M.watcher:start()

return M
