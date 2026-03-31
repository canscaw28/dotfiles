#!/bin/bash
# Cycle through input sources by clicking the input menu bar item
osascript -e '
tell application "System Events" to tell process "TextInputMenuAgent"
    tell menu bar item 1 of menu bar 2
        click
        tell menu 1
            set n to count of menu items
            repeat with i from 1 to n
                try
                    if (value of attribute "AXMenuItemMarkChar" of menu item i) is "✓" then
                        if i < n then
                            click menu item (i + 1)
                        else
                            click menu item 1
                        end if
                        exit repeat
                    end if
                end try
            end repeat
        end tell
    end tell
end tell
'
