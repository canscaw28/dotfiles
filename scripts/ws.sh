#!/bin/bash
# Workspace operations helper for AeroSpace
# Called from Karabiner-Elements shell_command via T layer
#
# Usage: ws.sh <operation> [workspace]
# Operations:
#   focus       Switch to workspace on the currently focused monitor
#   focus-1     Focus workspace on monitor 1
#   focus-2     Focus workspace on monitor 2 (falls back to monitor 1)
#   focus-3     Focus workspace on monitor 3 (falls back to monitor 1)
#   focus-4     Focus workspace on monitor 4 (falls back to monitor 1)
#   move        Move focused window to workspace (stay on current)
#   move-focus  Move focused window to workspace, follow it on current monitor
#   swap        Swap current workspace with selected workspace between monitors
#   swap-follow Swap workspaces, then focus the selected workspace
#   swap-monitors  Swap workspaces between current and next monitor
#   move-monitor   Move focused window to next monitor
#   move-monitor-focus  Move focused window to next monitor and follow
#   move-monitor-yank   Move focused window to next monitor, yank that workspace back
#   swap-windows   Swap all windows between focused workspace and target workspace
#   push-windows   Move all windows from focused workspace to target workspace
#   pull-windows   Pull all windows from target workspace to focused workspace

# Karabiner shell_command runs with minimal PATH; ensure homebrew is available
export PATH="/opt/homebrew/bin:$PATH"

trap '' PIPE  # Ignore SIGPIPE — aerospace CLI gets spurious broken pipes under rapid invocation

# --- Lock and queue infrastructure ---

LOCKFILE="/tmp/aerospace-lock.pid"
QUEUE_DIR="/tmp/ws-queue"
DEBUG_LOG="/tmp/ws-debug.log"
_WS_DEBUG=${WS_DEBUG:-0}
_ms() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time' 2>/dev/null || date +%s; }
_START_TS=$(perl -MTime::HiRes=time -e 'printf "%.6f", time' 2>/dev/null || date +%s)
debug() { [[ $_WS_DEBUG -eq 1 ]] || return 0; printf '%s [%d] %s\n' "$(_ms)" $$ "$*" >> "$DEBUG_LOG" 2>/dev/null; }

_LOCK_HOLDER=0
trap '_ec=$?; [[ $_LOCK_HOLDER -eq 1 ]] && rm -f "$LOCKFILE"; [[ $_WS_DEBUG -eq 1 ]] && debug "EXIT code=$_ec"' EXIT

acquire_lock() {
    # Symlink-based lock: ln -s creates symlink atomically (target=PID in one syscall).
    # No window where the file exists but content is empty, unlike echo > file.
    if ln -s $$ "$LOCKFILE" 2>/dev/null; then
        _LOCK_HOLDER=1
        return 0
    fi
    # Lock exists — check if holder is alive
    local holder
    holder=$(readlink "$LOCKFILE" 2>/dev/null) || return 1
    [[ "$holder" =~ ^[0-9]+$ ]] || { rm -f "$LOCKFILE"; return 1; }
    if ! kill -0 "$holder" 2>/dev/null; then
        rm -f "$LOCKFILE"
        return 1  # Stale lock removed, caller should retry
    fi
    return 1  # Lock held by live process
}

enqueue() {
    local op="$1" ws="$2"
    mkdir -p "$QUEUE_DIR"
    local tmp
    tmp=$(mktemp "$QUEUE_DIR/.tmp.XXXXXX")
    printf '%s %s\n' "$op" "$ws" > "$tmp"
    # Use start timestamp as filename so ls sorts in keypress order.
    # _START_TS is captured at script entry (microsecond precision) before
    # any lock contention delays, so it reflects actual keypress ordering.
    mv "$tmp" "$QUEUE_DIR/${_START_TS}-$$"
}

# --- AeroSpace state cache ---
# During drain cycles we hold the lock, so no external process can change
# AeroSpace state. Query once and track in memory to avoid redundant CLI calls.

_CACHED=0
_C_FOCUSED_MON=""
_C_MONITORS=()

cache_state() {
    _C_FOCUSED_MON=$(aerospace list-monitors --focused --format '%{monitor-id}')
    _C_MONITORS=($(aerospace list-monitors --format '%{monitor-id}'))
    for _cm in "${_C_MONITORS[@]}"; do
        printf -v "_C_MON_WS_${_cm}" '%s' "$(aerospace list-workspaces --monitor "$_cm" --visible)"
    done
    _CACHED=1
}

# --- AeroSpace helpers ---

resolve_monitor() {
    local target=$1
    local monitors
    if [[ $_CACHED -eq 1 ]]; then
        monitors=("${_C_MONITORS[@]}")
    else
        monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    fi
    for mon in "${monitors[@]}"; do
        if [[ "$mon" == "$target" ]]; then
            echo "$target"
            return
        fi
    done
    echo "1"
}

next_monitor() {
    local current="$1"
    local monitors
    if [[ $_CACHED -eq 1 ]]; then
        monitors=("${_C_MONITORS[@]}")
    else
        monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    fi
    local count=${#monitors[@]}
    for i in "${!monitors[@]}"; do
        if [[ "${monitors[$i]}" == "$current" ]]; then
            echo "${monitors[$(( (i + 1) % count ))]}"
            return
        fi
    done
}

# Find which monitor a workspace is visible on (empty if not visible on any).
visible_on_monitor() {
    local ws="$1"
    if [[ $_CACHED -eq 1 ]]; then
        local var
        for mon in "${_C_MONITORS[@]}"; do
            var="_C_MON_WS_${mon}"
            if [[ "${!var}" == "$ws" ]]; then
                echo "$mon"
                return
            fi
        done
        return
    fi
    local monitors
    monitors=($(aerospace list-monitors --format '%{monitor-id}'))
    for mon in "${monitors[@]}"; do
        if [[ "$(aerospace list-workspaces --monitor "$mon" --visible)" == "$ws" ]]; then
            echo "$mon"
            return
        fi
    done
}

# Place the ~ buffer workspace on a specific monitor.
# ~ always creates on mon1; if a different monitor is needed, move it there.
BUFFER_WS='~'

place_buffer_on() {
    local mon="$1"
    aerospace workspace "$BUFFER_WS"; sleep 0.03
    if [[ "$mon" != "1" ]]; then
        aerospace move-workspace-to-monitor "$mon"; sleep 0.03
    fi
}

# Focus a workspace on a specific monitor.
# summon-workspace only works for hidden workspaces — for a workspace that's
# already visible on another monitor, it just redirects focus there and picks
# a random fallback for the source monitor. This helper detects that case and
# yanks the workspace to the target, leaving ~ on the source monitor.
focus_ws_on_monitor() {
    local target_mon="$1" ws="$2"
    local ws_mon buf_mon
    ws_mon=$(visible_on_monitor "$ws")

    if [[ "$ws_mon" == "$target_mon" ]]; then
        # Already on the target monitor, just focus it
        aerospace focus-monitor "$target_mon"
        [[ $_CACHED -eq 1 ]] && _C_FOCUSED_MON="$target_mon"
        return
    fi

    if [[ -z "$ws_mon" ]]; then
        # Hidden workspace — summon works correctly for these
        aerospace focus-monitor "$target_mon"; sleep 0.03
        aerospace summon-workspace "$ws"
        if [[ $_CACHED -eq 1 ]]; then
            # Previous ws on target_mon is now hidden; target_mon shows $ws
            printf -v "_C_MON_WS_${target_mon}" '%s' "$ws"
            _C_FOCUSED_MON="$target_mon"
        fi
        return
    fi

    # ws is visible on ws_mon, want it on target_mon, leave ~ on ws_mon.
    # These paths are complex — refresh cache fully afterward.
    buf_mon=$(visible_on_monitor "$BUFFER_WS")

    if [[ "$buf_mon" == "$target_mon" ]]; then
        # ~ occupies our target from a previous yank. Move ws there directly
        # (replaces ~, which gets GC'd). Then put fresh ~ on ws_mon.
        aerospace focus-monitor "$ws_mon"; sleep 0.03
        aerospace move-workspace-to-monitor "$target_mon"; sleep 0.03
        place_buffer_on "$ws_mon"
        aerospace workspace "$ws"
    else
        # Reclaim stale ~ to mon1 if it's stranded on another monitor (3+ monitors).
        if [[ -n "$buf_mon" && "$buf_mon" != "1" ]]; then
            aerospace focus-monitor "$buf_mon"; sleep 0.03
            aerospace move-workspace-to-monitor 1; sleep 0.03
        fi
        # Place ~ on ws_mon to hide ws, then summon ws to target.
        place_buffer_on "$ws_mon"
        aerospace focus-monitor "$target_mon"; sleep 0.03
        aerospace summon-workspace "$ws"
    fi
    [[ $_CACHED -eq 1 ]] && cache_state
}

# Swap two workspaces between monitors using summon-workspace.
# Args: $1=workspace_a $2=dest_monitor_a $3=workspace_b $4=dest_monitor_b
# ws_a starts on mon_b (the focused monitor), ws_b starts on mon_a.
#
# Uses ~ as an empty buffer workspace to avoid flashing existing workspaces
# during the swap. AeroSpace creates new workspaces on monitor 1, so ~ always
# lands there. summon-workspace pulls hidden workspaces to the focused monitor
# without disrupting the source monitor's visible workspace.
#
# AeroSpace occasionally drops commands in rapid succession, so swaps are
# verified and retried with a longer delay if needed.
swap_workspaces() {
    local ws_a="$1" mon_a="$2" ws_b="$3" mon_b="$4"

    # ~ buffer always lands on mon1, hiding whatever is visible there.
    # Determine which workspace is on mon1 vs the other monitor.
    local ws_on_1 ws_on_other other_mon
    if [[ "$mon_a" == "1" ]]; then
        ws_on_1="$ws_b"       # ws_b is on mon_a=1
        ws_on_other="$ws_a"   # ws_a is on mon_b
        other_mon="$mon_b"
    else
        ws_on_1="$ws_a"       # ws_a is on mon_b=1
        ws_on_other="$ws_b"   # ws_b is on mon_a
        other_mon="$mon_a"
    fi

    local D=0.05
    local attempt
    for attempt in 1 2; do
        # 1. Create ~ on mon1, hiding ws_on_1. Focus moves to mon1.
        aerospace workspace "$BUFFER_WS";  sleep "$D"
        # 2. Focus the other monitor, then summon ws_on_1 (hidden on mon1) there.
        aerospace focus-monitor "$other_mon";  sleep "$D"
        aerospace summon-workspace "$ws_on_1"; sleep "$D"
        # 3. Focus mon1 (showing ~), then summon ws_on_other (hidden on other mon).
        aerospace focus-monitor 1;             sleep "$D"
        aerospace summon-workspace "$ws_on_other"
        # 4. Focus back to the original monitor showing ws_b.
        aerospace workspace "$ws_b"

        # Verify: check both monitors show the expected workspaces
        local actual_a actual_b
        actual_a=$(aerospace list-workspaces --monitor "$mon_a" --visible)
        actual_b=$(aerospace list-workspaces --monitor "$mon_b" --visible)
        if [[ "$actual_a" == "$ws_a" && "$actual_b" == "$ws_b" ]]; then
            return 0
        fi
        # Failed — increase delay and retry
        D=0.1
    done
}

# --- Operation execution ---

execute_op() {
    case "$OP" in
        focus)
            focus_ws_on_monitor "$_C_FOCUSED_MON" "$WS"
            ;;
        focus-1)
            focus_ws_on_monitor "$(resolve_monitor 1)" "$WS"
            ;;
        focus-2)
            focus_ws_on_monitor "$(resolve_monitor 2)" "$WS"
            ;;
        focus-3)
            focus_ws_on_monitor "$(resolve_monitor 3)" "$WS"
            ;;
        focus-4)
            focus_ws_on_monitor "$(resolve_monitor 4)" "$WS"
            ;;
        move)
            aerospace move-node-to-workspace "$WS"
            ;;
        move-focus)
            # Move window to workspace, then pull that workspace to current monitor.
            CURRENT_MON="$_C_FOCUSED_MON"
            aerospace move-node-to-workspace "$WS"
            focus_ws_on_monitor "$CURRENT_MON" "$WS"
            ;;
        swap)
            # Swap current workspace with selected workspace between monitors.
            # Focus stays on current monitor (now showing the target workspace).
            CURRENT_WS=$(aerospace list-workspaces --focused)
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            TARGET_MONITOR=$(visible_on_monitor "$WS")

            if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
                swap_workspaces "$CURRENT_WS" "$TARGET_MONITOR" "$WS" "$CURRENT_MONITOR"
            fi
            ;;
        swap-follow)
            # Swap workspaces between monitors, then focus the selected workspace.
            CURRENT_WS=$(aerospace list-workspaces --focused)
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            TARGET_MONITOR=$(visible_on_monitor "$WS")

            if [ -n "$TARGET_MONITOR" ] && [ "$TARGET_MONITOR" != "$CURRENT_MONITOR" ]; then
                swap_workspaces "$CURRENT_WS" "$TARGET_MONITOR" "$WS" "$CURRENT_MONITOR"
            fi
            # Follow: focus the selected workspace (now on current monitor)
            aerospace workspace "$WS"
            ;;
        move-monitor)
            # Move focused window to the next monitor's visible workspace
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
            local _nm_var="_C_MON_WS_${NEXT_MONITOR}"
            NEXT_WS="${!_nm_var}"
            aerospace move-node-to-workspace "$NEXT_WS"
            ;;
        move-monitor-focus)
            # Move focused window to next monitor and follow it
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
            local _nm_var="_C_MON_WS_${NEXT_MONITOR}"
            NEXT_WS="${!_nm_var}"
            aerospace move-node-to-workspace "$NEXT_WS"
            aerospace workspace "$NEXT_WS"
            ;;
        move-monitor-yank)
            # Move window to next monitor, then yank that workspace to current monitor
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            NEXT_MONITOR=$(next_monitor "$CURRENT_MONITOR")
            local _nm_var="_C_MON_WS_${NEXT_MONITOR}"
            NEXT_WS="${!_nm_var}"
            aerospace move-node-to-workspace "$NEXT_WS"
            focus_ws_on_monitor "$CURRENT_MONITOR" "$NEXT_WS"
            ;;
        swap-windows)
            # Swap all windows between focused workspace and target workspace
            CURRENT_WS=$(aerospace list-workspaces --focused)
            CURRENT_WIDS=$(aerospace list-windows --workspace "$CURRENT_WS" --format '%{window-id}')
            TARGET_WIDS=$(aerospace list-windows --workspace "$WS" --format '%{window-id}')
            for wid in $CURRENT_WIDS; do
                aerospace move-node-to-workspace --window-id "$wid" "$WS"
            done
            for wid in $TARGET_WIDS; do
                aerospace move-node-to-workspace --window-id "$wid" "$CURRENT_WS"
            done
            aerospace workspace "$CURRENT_WS"
            ;;
        push-windows)
            # Move all windows from focused workspace to target workspace
            CURRENT_WS=$(aerospace list-workspaces --focused)
            WINDOW_IDS=$(aerospace list-windows --workspace "$CURRENT_WS" --format '%{window-id}')
            for wid in $WINDOW_IDS; do
                aerospace move-node-to-workspace --window-id "$wid" "$WS"
            done
            aerospace workspace "$CURRENT_WS"
            ;;
        pull-windows)
            # Pull all windows from target workspace to focused workspace
            CURRENT_WS=$(aerospace list-workspaces --focused)
            WINDOW_IDS=$(aerospace list-windows --workspace "$WS" --format '%{window-id}')
            for wid in $WINDOW_IDS; do
                aerospace move-node-to-workspace --window-id "$wid" "$CURRENT_WS"
            done
            ;;
        swap-monitors)
            # Swap workspaces between current and next monitor (wraps for >2)
            # Focus stays on current monitor (now showing the other workspace).
            CURRENT_WS=$(aerospace list-workspaces --focused)
            CURRENT_MONITOR="$_C_FOCUSED_MON"
            # For 2-monitor setups, inline the other monitor ID to save a command.
            if [[ "$CURRENT_MONITOR" == "1" ]]; then NEXT_MONITOR=2; else NEXT_MONITOR=1; fi
            local _nm_var="_C_MON_WS_${NEXT_MONITOR}"
            NEXT_WS="${!_nm_var}"
            swap_workspaces "$CURRENT_WS" "$NEXT_MONITOR" "$NEXT_WS" "$CURRENT_MONITOR"
            ;;
        *)
            echo "ws.sh: unknown operation '$OP'" >&2
            exit 1
            ;;
    esac
}

# --- Post-processing ---

per_op_post_process() {
    # Refresh workspace grid overlay after each op so it tracks workspace changes live
    /usr/local/bin/hs -c "require('ws_grid').showGrid()" 2>/dev/null &
}

# Full post-processing for the last operation in a drain cycle.
# Synchronous aerospace calls (move-mouse, list-monitors) go here instead of
# per_op_post_process to avoid adding ~100-200ms latency between each queued op.
final_post_process() {
    # Show workspace notification overlay
    NOTIFY_WS="$WS"
    NOTIFY_MON="$_C_FOCUSED_MON"
    case "$OP" in
        focus-[1-4])         NOTIFY_MON="${OP##focus-}" ;;
        swap-monitors)       NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$CURRENT_MONITOR" ;;
        move-monitor|move-monitor-focus) NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$NEXT_MONITOR" ;;
        move-monitor-yank) NOTIFY_WS="$NEXT_WS"; NOTIFY_MON="$CURRENT_MONITOR" ;;
    esac
    if [[ -n "$NOTIFY_WS" && "$OP" != "move" ]]; then
        /usr/local/bin/hs -c "require('ws_notify').show('$NOTIFY_WS', ${NOTIFY_MON:-0})" 2>/dev/null &
    fi

    # Move mouse to focused window
    aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null || true

    # Flash border around focused window (skip for focus — grid provides feedback)
    if [[ "$OP" != "focus" ]]; then
        /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    fi

    # Refresh workspace grid overlay if visible
    /usr/local/bin/hs -c "require('ws_grid').showGrid()" 2>/dev/null &

    # Save window state after every operation (for restore on restart)
    ~/.local/bin/save-ws-state.sh &
}

# --- Queue drain ---

COLLAPSE_THRESHOLD=7

drain_queue() {
    cache_state
    while true; do
        local files=("$QUEUE_DIR"/[0-9]*)
        [[ -e "${files[0]}" ]] || return
        local next="${files[0]}"

        local line
        line=$(<"$next")
        local op="${line%% *}"
        local ws="${line#* }"

        # Collapse consecutive focus ops when the queue is deep (> threshold).
        # Small bursts execute fully so the user sees each transition.
        # Large backlogs skip intermediate focus ops to catch up quickly.
        if [[ "$op" == focus* ]]; then
            local depth=${#files[@]}
            if [[ "$depth" -gt "$COLLAPSE_THRESHOLD" ]]; then
                local peek="${files[1]:-}"
                if [[ -n "$peek" && -e "$peek" ]]; then
                    local peek_line
                    peek_line=$(<"$peek")
                    local peek_op="${peek_line%% *}"
                    if [[ "$peek_op" == focus* ]]; then
                        debug "SKIP $op $ws (queue depth $depth)"
                        rm -f "$next"
                        continue
                    fi
                fi
            fi
        fi

        OP="$op"
        WS="$ws"
        debug "DRAIN $OP $WS (from $(basename "$next"))"
        execute_op
        # Non-focus ops modify state in complex ways; refresh cache fully
        [[ "$OP" != focus* ]] && cache_state
        per_op_post_process
        rm -f "$next"
    done
}

# --- Main flow ---
# Every invocation enqueues its command first — this makes commands durable
# even if the executing process dies (Karabiner spawns processes that can be
# killed unpredictably). Then one process becomes the worker and drains the
# queue sequentially.

OP="${1:-}"
WS="${2:-}"

debug "START $OP $WS"
enqueue "$OP" "$WS"

if acquire_lock || acquire_lock; then
    debug "WORKER — draining"
    drain_queue
    final_post_process
    debug "DONE"
else
    # Lock held by another worker — it will drain our enqueued command.
    # Sleep briefly and retry in case the worker died before reaching our entry.
    sleep 0.15
    if acquire_lock; then
        debug "WORKER (retry) — draining"
        drain_queue
        final_post_process
        debug "DONE"
    fi
fi
