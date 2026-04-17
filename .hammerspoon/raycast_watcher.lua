-- Raycast's command bar is a nonactivating NSPanel, so it doesn't change the
-- frontmost app. Karabiner's frontmost_application_if condition therefore still
-- matches the underlying app (e.g. iTerm) and applies app-specific overrides
-- to keys the user types into Raycast. This watcher mirrors Raycast's panel
-- visibility into the `raycast_active` Karabiner variable so those overrides
-- can be gated off via negative_conditions.

local M = {}

local KARABINER_CLI = "/usr/local/bin/karabiner_cli"

local function setActive(active)
    local value = active and 1 or 0
    hs.task.new(
        KARABINER_CLI,
        nil,
        { "--set-variables", string.format('{"raycast_active":%d}', value) }
    ):start()
end

setActive(false)

M.filter = hs.window.filter.new(false):setAppFilter("Raycast", { allowRoles = "*" })

local function activate() setActive(true) end
local function deactivate() setActive(false) end

M.filter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowVisible,
}, activate)

M.filter:subscribe({
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowNotVisible,
}, deactivate)

return M
