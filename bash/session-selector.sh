#!/usr/bin/env bash
# session-selector.sh — zellij session picker for SSH/ET login
# zellij-kit component — uninstall.sh only removes files carrying this marker.
# V1 (clean exit), V2 (auto-name), V3 (filter dead), V4 (launch shell), V6 (human-readable names)
# B3 (read from /dev/tty), B4 (no -- args), B5 (session name \r stripping), B6 (ZELLIJ guard)

set -euo pipefail

# ── helpers ──────────────────────────────────────────────

auto_name() {
    printf 'sess-%s' "$(date +%Y%m%d-%H%M%S)"
}

# Read one keystroke from /dev/tty (B3: reliable input source)
read_key() {
    if [[ -t 0 ]]; then
        read -rsn1 "$@"
    else
        read -rsn1 "$@" < /dev/tty
    fi
}

# Read a full line from /dev/tty
read_line() {
    local var="$1"
    if [[ -t 0 ]]; then
        IFS= read -r "$var"
    else
        IFS= read -r "$var" < /dev/tty
    fi
}

# Locate zellij: PATH first, then common install dirs (cargo binstall, kit bin, system)
ZELLIJ_BIN=""
for c in "$(command -v zellij 2>/dev/null)" "$HOME/.cargo/bin/zellij" "$HOME/.local/bin/zellij" /usr/local/bin/zellij /usr/bin/zellij; do
    if [[ -n "$c" ]] && [[ -x "$c" ]]; then ZELLIJ_BIN="$c"; break; fi
done
if [[ -z "$ZELLIJ_BIN" ]]; then
    echo "zellij not found — install it (e.g. 'cargo binstall zellij'), then re-login." >&2
    exit 1
fi

strip_ansi() { sed $'s/\033\\[[0-9;]*[a-zA-Z]//g'; }

mapfile -t sessions < <(
    "$ZELLIJ_BIN" list-sessions 2>/dev/null | strip_ansi | while IFS= read -r line; do
        # Skip dead sessions (V3). zellij >=0.4x prints
        # "(EXITED - attach to resurrect)"; older releases used the bracketed
        # [Dead]/[Exit] markers — match every form, or the picker offers
        # month-old sessions that resolve to nothing with session_serialization
        # false (kit config).
        [[ "$line" == *EXITED* || "$line" == *"[Dead]"* || "$line" == *"[Exit]"* ]] && continue
        # Session name = first token, strip any trailing \r
        name="${line%% *}"
        name="${name%$'\r'}"
        [[ -n "$name" ]] && printf '%s\n' "$name"
    done || true
)
session_count=${#sessions[@]}

# ── menu ─────────────────────────────────────────────────

show_menu() {
    clear
    echo "=== Zellij Session Selector ==="
    echo ""

    if (( session_count > 0 )); then
        local i=1
        for s in "${sessions[@]}"; do
            printf '  \e[1m%s\e[0m) %s\n' "$i" "$s"
            ((i++))
        done
        echo ""
    else
        echo "  No active sessions."
        echo ""
    fi

    echo "  n) New session (custom name)"
    echo "  r) New session (random name)"
    echo "  q) Quit / close"
    echo ""
    printf "Choose: "
}

# ── main loop ────────────────────────────────────────────

while true; do
    show_menu

    choice=""
    read_key choice
    echo ""  # newline after keystroke echo

    case "$choice" in
        q)
            # V1: clean exit → closes SSH connection (we are exec'd from bash_profile)
            echo "Bye."
            exit 0
            ;;
        n)
            # V2 + V6: custom name
            printf "Session name: "
            user_name=""
            read_line user_name
            user_name="${user_name%$'\r'}"
            if [[ -z "$user_name" ]]; then
                echo "Empty name, aborting."
                continue
            fi
            exec "$ZELLIJ_BIN" -s "$user_name"
            ;;
        r)
            # V2 + V6: auto random name
            exec "$ZELLIJ_BIN" -s "$(auto_name)"
            ;;
        '')
            # V1: empty → re-prompt
            continue
            ;;
        [1-9]*)
            # Numeric choice — attach to existing session
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                continue
            fi
            if (( choice < 1 || choice > session_count )); then
                echo "Out of range."
                sleep 1
                continue
            fi
            target="${sessions[$((choice - 1))]}"
            exec "$ZELLIJ_BIN" attach "$target"
            ;;
        *)
            # Any other key → close connection
            echo "Bye."
            exit 0
            ;;
    esac
done
