#!/bin/bash
# Save window-to-workspace mapping for state preservation across AeroSpace restarts
aerospace list-windows --all --format '%{app-name}|%{window-title}|%{workspace}' > ~/.aerospace-window-state
