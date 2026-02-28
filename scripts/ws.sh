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

# Detach from Karabiner's process tree on first invocation.
# Karabiner SIGKILL's shell_command processes unpredictably (observed via
# orphaned tmp files in the queue dir). Re-exec into a new session so the
# original process exits in <1ms and the real work runs independently.
if [[ -z "$_WS_DETACHED" ]]; then
    export _WS_DETACHED=1
    "$0" "$@" &>/dev/null &
    exit 0
fi

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

BUFFER_WS='~'

# Focus a workspace on a specific monitor.
# summon-workspace only works for hidden workspaces — for a workspace that's
# already visible on another monitor, it just redirects focus there and picks
# a random fallback for the source monitor. This helper detects that case and
# swaps the two workspaces between monitors (both stay visible).
focus_ws_on_monitor() {
    local target_mon="$1" ws="$2"
    local ws_mon
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

    # ws is visible on ws_mon, want it on target_mon — swap the two
    # workspaces so both stay visible (old ws goes to ws_mon).
    # Uses ~ as a temporary buffer on mon1 to avoid AeroSpace picking
    # random fallback workspaces during the transition.
    local current_ws
    local var="_C_MON_WS_${target_mon}"
    current_ws="${!var}"

    # Determine which workspace is on mon1 vs the other monitor.
    local ws_on_1 ws_on_other other_mon
    if [[ "$target_mon" == "1" ]]; then
        ws_on_1="$current_ws"   # current_ws is on target_mon=1
        ws_on_other="$ws"       # ws is on ws_mon
        other_mon="$ws_mon"
    else
        ws_on_1="$ws"           # ws is on ws_mon=1
        ws_on_other="$current_ws" # current_ws is on target_mon
        other_mon="$target_mon"
    fi

    # 1. Create ~ on mon1, hiding ws_on_1. ~ never leaves mon1.
    aerospace workspace "$BUFFER_WS"; sleep 0.03
    # 2. Summon ws_on_1 (now hidden) to the other monitor, hiding ws_on_other.
    aerospace focus-monitor "$other_mon"; sleep 0.03
    aerospace summon-workspace "$ws_on_1"; sleep 0.03
    # 3. Summon ws_on_other (now hidden) to mon1, hiding ~ (GC'd).
    aerospace focus-monitor 1; sleep 0.03
    aerospace summon-workspace "$ws_on_other"
    # 4. Focus the target monitor showing the requested workspace.
    aerospace focus-monitor "$target_mon"
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
        focus-[1-4])
            # FOCUS_N_RESTORE_MON is pre-set from home file in drain_queue,
            # or captured from cache on first focus-N op in this batch.
            local _home_mon="${FOCUS_N_RESTORE_MON:-$_C_FOCUSED_MON}"
            [[ -z "$FOCUS_N_RESTORE_MON" ]] && FOCUS_N_RESTORE_MON="$_home_mon"
            # Re-persist home file if missing (TRANSITION deletes it, but more
            # focus-N ops may arrive in the same drain cycle). Without the file,
            # the next invocation writes the transient focused monitor (wrong).
            if [[ ! -f "$FOCUS_N_HOME_FILE" ]]; then
                echo "$_home_mon" > "$FOCUS_N_HOME_FILE"
                debug "HOME re-persisted $_home_mon after transition"
            fi
            local _target_mon
            _target_mon=$(resolve_monitor "${OP##focus-}")
            debug "FOCUS-N target_mon=$_target_mon ws=$WS home=$_home_mon restore=$FOCUS_N_RESTORE_MON cached_focus=$_C_FOCUSED_MON"
            focus_ws_on_monitor "$_target_mon" "$WS"
            # Restore focus to home monitor IMMEDIATELY after each op.
            # Karabiner SIGKILL's workers at any moment — deferring restore
            # to final_post_process means it often never runs.
            aerospace focus-monitor "$_home_mon"
            [[ $_CACHED -eq 1 ]] && _C_FOCUSED_MON="$_home_mon"
            debug "FOCUS-N restored to mon=$_home_mon"
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
    # Focus/move-focus ops: instant visual feedback (visitKey) fires from
    # Karabiner shell_command before ws.sh even starts — skip grid refresh
    # to avoid async query overwriting visitKey's state.
    # Move ops: window moves but workspace visibility doesn't change —
    # skip grid refresh to avoid async query overwriting grid state.
    # Non-focus ops: trigger full grid refresh.
    if [[ "$OP" != focus* && "$OP" != move* ]]; then
        /usr/local/bin/hs -c "require('ws_grid').showGrid()" 2>/dev/null &
    fi
}

# Full post-processing for the last operation in a drain cycle.
# Synchronous aerospace calls (move-mouse, list-monitors) go here instead of
# per_op_post_process to avoid adding ~100-200ms latency between each queued op.
final_post_process() {
    # Safety-net restore: each focus-N op already restores per-op, but if
    # the last op's restore was interrupted, this catches it.
    if [[ -n "$FOCUS_N_RESTORE_MON" ]]; then
        debug "RESTORE safety-net target=$FOCUS_N_RESTORE_MON"
        aerospace focus-monitor "$FOCUS_N_RESTORE_MON"
        [[ $_CACHED -eq 1 ]] && _C_FOCUSED_MON="$FOCUS_N_RESTORE_MON"
        rm -f "$FOCUS_N_HOME_FILE"
    fi

    # Move mouse to focused window (skip for move — focus doesn't change,
    # and on an empty workspace this can trigger AeroSpace focus shift)
    if [[ "$OP" != "move" ]]; then
        aerospace move-mouse window-lazy-center 2>/dev/null || aerospace move-mouse monitor-lazy-center 2>/dev/null || true
    fi

    # Flash border around focused window (skip for focus — grid provides feedback)
    if [[ "$OP" != "focus" ]]; then
        /usr/local/bin/hs -c "require('focus_border').flash()" 2>/dev/null &
    fi

    # Refresh workspace grid overlay if visible (skip for focus/move-focus —
    # visitKey provides instant feedback; the async query here races with
    # visitKey and can overwrite its state with stale AeroSpace data.
    # Skip for move — workspace visibility doesn't change.)
    if [[ "$OP" != focus* && "$OP" != move* ]]; then
        /usr/local/bin/hs -c "require('ws_grid').showGrid()" 2>/dev/null &
    fi

    # Save window state after every operation (for restore on restart)
    ~/.local/bin/save-ws-state.sh &
}

# --- Queue drain ---

# Weight budget for collapse: total weight of kept focus ops must not
# exceed this. Normal focus=1, swap focus (visible on another mon)=2.
COLLAPSE_WEIGHT=5

# Operation weight for collapse. Non-focus ops return 0 (never collapsed).
# For focus ops, check if the target workspace is visible on another monitor
# (swap path = heavier). Uses the cached AeroSpace state.
op_weight() {
    local op="${1%% *}" ws="${1#* }"
    [[ "$op" != focus* ]] && echo 0 && return
    local ws_mon
    ws_mon=$(visible_on_monitor "$ws")
    if [[ -n "$ws_mon" && "$ws_mon" != "$_C_FOCUSED_MON" ]]; then
        echo 2  # swap: 6 aerospace commands
    else
        echo 1  # summon or already-there: 1-2 commands
    fi
}

drain_queue() {
    cache_state
    FOCUS_N_RESTORE_MON=""
    # Read pre-saved home monitor for focus-N batch (written by first invocation
    # before any ops ran, so it reflects the user's actual focused monitor)
    if [[ -f "$FOCUS_N_HOME_FILE" ]]; then
        FOCUS_N_RESTORE_MON=$(<"$FOCUS_N_HOME_FILE")
        debug "HOME read $FOCUS_N_RESTORE_MON from file"
    fi
    while true; do
        local files=("$QUEUE_DIR"/[0-9]*)
        [[ -e "${files[0]}" ]] || return

        # Transition skip: when user switches from focus-N to another op
        # (released E and pressed a workspace key), stale focus-N entries
        # block the queue — each worker wastes its lifespan processing them
        # before reaching the user's actual intent. Purge all focus-N entries
        # that come BEFORE the first non-focus-N entry.
        local first_non_fn=-1
        for i in "${!files[@]}"; do
            local peek
            peek=$(<"${files[$i]}" 2>/dev/null) || continue
            if [[ "${peek%% *}" != focus-[1-4] ]]; then
                first_non_fn=$i
                break
            fi
        done
        if [[ $first_non_fn -gt 0 ]]; then
            for i in $(seq 0 $((first_non_fn - 1))); do
                local peek
                peek=$(<"${files[$i]}" 2>/dev/null) || continue
                debug "TRANSITION-SKIP ${peek%% *} ${peek#* } (non-focus-N ahead)"
                rm -f "${files[$i]}"
            done
            continue  # re-enumerate after purge
        fi

        # Collapse: when total weight of queued focus ops exceeds the
        # budget, bulk-skip excess from the front. Swap-focus ops count
        # as 2 (heavier); normal focus ops count as 1. Non-focus ops
        # (move, swap, push/pull-windows) have weight 0 and are never skipped.
        local depth=${#files[@]}
        if [[ "$depth" -gt 1 ]]; then
            # Compute total weight and per-file weights
            local total_weight=0
            local -a weights=()
            for f in "${files[@]}"; do
                local l=$(<"$f")
                local w
                w=$(op_weight "$l")
                weights+=("$w")
                ((total_weight += w))
            done
            if [[ "$total_weight" -gt "$COLLAPSE_WEIGHT" ]]; then
                local excess=$((total_weight - COLLAPSE_WEIGHT))
                local i=0
                for f in "${files[@]}"; do
                    [[ "$excess" -le 0 ]] && break
                    local w="${weights[$i]}"
                    if [[ "$w" -gt 0 ]]; then
                        local l=$(<"$f" 2>/dev/null)
                        debug "COLLAPSE skip ${l%% *} ${l#* } (weight=$w total=$total_weight budget=$COLLAPSE_WEIGHT)"
                        rm -f "$f"
                        ((excess -= w))
                    fi
                    ((i++))
                done
                continue  # re-enumerate after bulk skip
            fi
        fi

        local next="${files[0]}"
        local line
        line=$(<"$next")
        # Remove queue file IMMEDIATELY after reading. Workers get SIGKILL'd
        # at any moment — if the file persists, the next worker re-drains the
        # same entry, creating an infinite replay loop that blocks the queue.
        # Losing one op in a rapid burst is imperceptible; a 10s stuck entry
        # is catastrophic.
        rm -f "$next"
        OP="${line%% *}"
        WS="${line#* }"
        debug "DRAIN $OP $WS (from $(basename "${next}"))"
        # If user transitioned from focus-N to another op type (e.g. released E),
        # restore focus to home monitor IMMEDIATELY so subsequent ops use the
        # correct _C_FOCUSED_MON (orphaned focus-N entries corrupt it).
        if [[ "$OP" != focus-[1-4] && -n "$FOCUS_N_RESTORE_MON" ]]; then
            debug "TRANSITION restore to $FOCUS_N_RESTORE_MON before $OP"
            aerospace focus-monitor "$FOCUS_N_RESTORE_MON"; sleep 0.03
            cache_state
            FOCUS_N_RESTORE_MON=""
            rm -f "$FOCUS_N_HOME_FILE"
        fi
        # Capture source workspace before op (for action notifications)
        local _src_var="_C_MON_WS_${_C_FOCUSED_MON}"
        SOURCE_WS="${!_src_var}"
        execute_op
        # Non-focus ops modify state in complex ways; refresh cache fully
        [[ "$OP" != focus* ]] && cache_state
        per_op_post_process
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

# For focus-N ops, persist the user's home monitor to a file on the FIRST
# invocation (before any ops corrupt AeroSpace state). Later invocations see
# the file and skip writing. This survives Karabiner killing processes mid-op.
FOCUS_N_HOME_FILE="/tmp/ws-focus-n-home"
if [[ -f "$FOCUS_N_HOME_FILE" ]]; then
    # Remove stale file from a previous session that wasn't cleaned up.
    # 30s threshold: must survive gaps between bursts (user pauses, mode
    # transitions, slow AeroSpace) where workers get killed with focus
    # stranded on the wrong monitor. Only truly orphaned files (from a
    # previous session minutes ago) should expire.
    _home_age=$(( $(date +%s) - $(stat -f %m "$FOCUS_N_HOME_FILE") ))
    if [[ $_home_age -gt 30 ]]; then
        debug "HOME stale (${_home_age}s) — removing"
        rm -f "$FOCUS_N_HOME_FILE"
    elif [[ "$OP" == focus-[1-4] ]]; then
        # Touch to keep fresh during sustained use — prevents the staleness
        # check from expiring the file mid-session (which would cause the
        # next invocation to re-query and capture transient focus state).
        touch "$FOCUS_N_HOME_FILE"
    fi
fi
if [[ "$OP" == focus-[1-4] && ! -f "$FOCUS_N_HOME_FILE" ]]; then
    aerospace list-monitors --focused --format '%{monitor-id}' > "$FOCUS_N_HOME_FILE"
    debug "HOME wrote $(<"$FOCUS_N_HOME_FILE") to $FOCUS_N_HOME_FILE"
fi
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
