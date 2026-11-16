-- Detects when a nonactivating panel (NSPanel) has grabbed key focus without
-- activating its app — Raycast, Alfred, Spotlight, 1Password quick access, etc.
-- In that state, macOS routes keystrokes to the panel but NSWorkspace still
-- reports the underlying app as frontmost, so Karabiner's
-- frontmost_application_if conditions keep applying app-specific overrides
-- (e.g. iTerm's terminal sequences) to keys typed into the panel.
--
-- The signal is: hs.window.focusedWindow():application() differs from
-- hs.application.frontmostApplication(). That divergence is exactly the
-- defining property of a nonactivating panel — regular windows activate
-- their app when focused, so focused-window's app matches frontmost.
--
-- Mirrors the state into the `panel_active` Karabiner variable, consumed via
-- always_negative in karabiner/src/layers/default.yaml.

local M = {}

local KARABINER_CLI = "/usr/local/bin/karabiner_cli"

-- One karabiner_cli at a time: parallel ones can finish out of order, leaving
-- Karabiner stuck on a stale value that the unchanged-state check never
-- corrects. The running task is kept on M so it isn't garbage collected before
-- its callback fires, which would block every later send.
local sent, wanted = nil, nil

local function flush()
    if M.task or wanted == sent then return end
    local value = wanted
    M.task = hs.task.new(KARABINER_CLI, function()
        M.task = nil
        sent = value
        flush()
    end, { "--set-variables", string.format('{"panel_active":%d}', value and 1 or 0) })
    if not M.task:start() then M.task = nil end
end

local function setActive(active)
    wanted = active
    flush()
end

local function evaluate()
    local focused = hs.window.focusedWindow()
    local frontApp = hs.application.frontmostApplication()
    if not focused or not frontApp then
        setActive(false)
        return
    end
    local focusedApp = focused:application()
    if not focusedApp then
        setActive(false)
        return
    end
    setActive(focusedApp:bundleID() ~= frontApp:bundleID())
end

setActive(false)
evaluate()

-- Accept all window roles so NSPanels (AXSystemDialog, AXFloatingWindow, etc.)
-- aren't filtered out by the default "standard window only" filter.
M.filter = hs.window.filter.new(nil):setDefaultFilter({ allowRoles = "*" })
M.filter:subscribe({
    hs.window.filter.windowFocused,
    hs.window.filter.windowUnfocused,
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowVisible,
    hs.window.filter.windowNotVisible,
}, evaluate)

-- Redundant with window events but covers the case where a panel grabs key
-- focus without emitting a window-focus event Hammerspoon sees.
M.appWatcher = hs.application.watcher.new(function(_, eventType, _)
    if eventType == hs.application.watcher.activated
        or eventType == hs.application.watcher.deactivated then
        evaluate()
    end
end)
M.appWatcher:start()

return M
