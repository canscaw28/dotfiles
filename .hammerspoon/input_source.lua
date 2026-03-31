local M = {}
M.saved = nil

function M.saveAndSwitchToEnglish()
    local current = hs.keycodes.currentSourceID()
    if current ~= "com.apple.keylayout.US" then
        M.saved = current
        hs.keycodes.currentSourceID("com.apple.keylayout.US")
    end
end

function M.restore()
    if M.saved then
        hs.keycodes.currentSourceID(M.saved)
        M.saved = nil
    end
end

function M.clearSaved()
    M.saved = nil
end

return M
