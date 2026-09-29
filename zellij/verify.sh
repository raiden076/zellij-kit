#!/bin/bash
# verify.sh — structural verification of the installed zellij-kit against bash/SPEC.md invariants
# Usage: zellij-kit/install.sh --check   (or run this file directly)
set -euo pipefail
ZDIR="$HOME/.config/zellij"
CFG="$ZDIR/config.kdl"
LYT="$ZDIR/layouts/default.kdl"
HELP="$ZDIR/help.sh"
PASS=0; FAIL=0

check() { local desc="$1"; shift; if "$@"; then echo "  PASS $desc"; PASS=$((PASS+1)); else echo "  FAIL $desc"; FAIL=$((FAIL+1)); fi }
check_neg() { local desc="$1"; shift; if "$@"; then echo "  FAIL $desc"; FAIL=$((FAIL+1)); else echo "  PASS $desc"; PASS=$((PASS+1)); fi }

echo "=== Minimal UI (V7) ==="
check "simplified_ui true" grep -q '^simplified_ui true$' "$CFG"
check "pane_frames false" grep -q '^pane_frames false$' "$CFG"
check "default_layout default" grep -q 'default_layout "default"' "$CFG"
check "mouse_mode true" grep -q '^mouse_mode true$' "$CFG"

echo "=== Bare layout, no chrome (V12, M6) ==="
check_neg "no tab-bar in default.kdl" grep -q 'zellij:tab-bar' "$LYT"
check_neg "no hint pane in default.kdl" grep -q 'C-g lock' "$LYT"
check_neg "no .wasm in layouts" grep -rq '\.wasm' "$ZDIR/layouts/"
check "help.sh present" test -f "$HELP"
check "help path points at HOME" grep -q "\"$HOME/.config/zellij/help.sh\"" "$CFG"
check "release-notes float off" grep -q '^show_release_notes false$' "$CFG"

echo "=== Scrollback reachable (V13) ==="
# clear-defaults=true unbinds zellij's built-in scroll mode; without explicit
# binds a fullscreen TUI that captures the mouse leaves no way to scroll back.
check "Ctrl s enters scroll mode" grep -q 'bind "Ctrl s" { SwitchToMode "scroll"; }' "$CFG"
check "scroll mode exits on Ctrl s" bash -c "grep -A16 'scroll {' \"$CFG\" | grep -q 'bind \"Ctrl s\" { SwitchToMode \"normal\"'"
check "ScrollToBottom bound (jump to live bottom)" grep -q 'ScrollToBottom' "$CFG"
check "PageScrollUp bound" grep -q 'PageScrollUp' "$CFG"
check_neg "Ctrl s not bound in locked mode" bash -c "grep -A3 'locked {' \"$CFG\" | grep -q 'Ctrl s'"

echo "=== Keybinds: clear-defaults + explicit (V8) ==="
check "clear-defaults=true" grep -q 'keybinds clear-defaults=true' "$CFG"

echo "=== Pane splits d/r/s + arrow focus, no hjkl (V9) ==="
check "d -> NewPane down" grep -q 'bind "d" { NewPane "down"' "$CFG"
check "r -> NewPane right" grep -q 'bind "r" { NewPane "right"' "$CFG"
check "s -> NewPane stacked" grep -q 'bind "s" { NewPane "stacked"' "$CFG"
check "left arrow move focus" grep -q 'bind "left" { MoveFocus "left"' "$CFG"
check "down arrow move focus" grep -q 'bind "down" { MoveFocus "down"' "$CFG"
check "up arrow move focus" grep -q 'bind "up" { MoveFocus "up"' "$CFG"
check "right arrow move focus" grep -q 'bind "right" { MoveFocus "right"' "$CFG"
check_neg "no hjkl focus binds" grep -Eq 'bind "[hjkl]" \{ MoveFocus' "$CFG"

echo "=== Locked default + Ctrl+g toggle (V10) ==="
check "default_mode locked" grep -q 'default_mode "locked"' "$CFG"
check "Ctrl g locked -> normal" bash -c "grep -A2 'locked {' \"$CFG\" | grep -q 'Ctrl g.*SwitchToMode \"normal\"'"
check "Ctrl g shared -> locked" bash -c "grep -A10 'shared_except \"locked\"' \"$CFG\" | grep -q 'bind \"Ctrl g\" { SwitchToMode \"locked\"'"

echo "=== ? help in all modes except locked (V11) ==="
check "? bound (shared_except locked)" bash -c "grep -A10 'shared_except \"locked\"' \"$CFG\" | grep -Fq 'bind \"?\"'"
check "? NOT excluded from normal mode" bash -c "grep 'shared_except \"locked\"' \"$CFG\" | grep -qv '\"normal\"'"

echo "=== Tab navigation ==="
check "left -> GoToPreviousTab" grep -q 'GoToPreviousTab' "$CFG"
check "right -> GoToNextTab" grep -q 'GoToNextTab' "$CFG"

echo "=== Resize ==="
check "arrows resize increase" grep -q 'Resize "Increase left"' "$CFG"
check "H/J/K/L resize decrease" grep -q 'Resize "Decrease left"' "$CFG"

echo "=== No lab-specific leftovers ==="
check_neg "no web_server" grep -q '^web_server true$' "$CFG"
# A naive `grep -q '/home/'` can never pass on a host whose $HOME lives under
# /home: install.sh renders the help pane path as an absolute $ZDIR/help.sh.
# What matters is that no OTHER machine's home path leaked into the config.
foreign_home_paths() {
    local extra
    extra="$(grep -oE '/home/[^"[:space:]]*' "$CFG" | sort -u | grep -vF "$ZDIR/help.sh" || true)"
    [[ -n "$extra" ]]
}
check_neg "no foreign home paths" foreign_home_paths

echo "=== Config parse ==="
if zellij setup --check 2>&1 | grep -q 'CONFIG FILE.*Well defined'; then echo "  PASS config parses"; PASS=$((PASS+1)); else echo "  FAIL config parse"; FAIL=$((FAIL+1)); fi

echo ""
echo "=== SUMMARY: $PASS passed, $FAIL failed ==="
exit $FAIL
