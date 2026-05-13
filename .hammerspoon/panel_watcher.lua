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

local lastState = nil

local function setActive(active)
    if active == lastState then return end
    lastState = active
    hs.task.new(
        KARABINER_CLI,
        nil,
        { "--set-variables", string.format('{"panel_active":%d}', active and 1 or 0) }
    ):start()
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
