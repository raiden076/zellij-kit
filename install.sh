#!/usr/bin/env bash
# install.sh — zellij-kit installer
#
# Installs:  locked-mode minimal zellij config, bare layouts, ?-help cheatsheet,
#            SSH-login session selector, and the bash hooks that trigger it.
# Prereqs:   bash, zellij (warned, not required, at install time), ssh (for the hook).
#
# Usage:
#   ./install.sh              install (copies files; backs up anything it replaces)
#   ./install.sh --link       install as a symlink farm into ~/.config/zellij etc.
#   ./install.sh --check      run verify.sh against the installed setup
#   ./install.sh --uninstall  remove installed files + bash hooks (marker-guarded)
#   ./install.sh --help
#
# Idempotent: safe to re-run; never duplicates hooks or clobbers user edits.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="zellij-kit"                        # files/hooks carrying this are ours (config.kdl uses // comments)
HOOK_OPEN="# >>> zellij-kit >>>"
HOOK_CLOSE="# <<< zellij-kit <<<"

ZDIR="$HOME/.config/zellij"
BIN_DIR="$HOME/.local/bin"
BP="$HOME/.bash_profile"
BRC="$HOME/.bashrc"

# ── helpers ──────────────────────────────────────────────
say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

backup() { # backup <file> — no-op if absent; NEVER overwrites an earlier backup
    # Re-running install.sh used to `cp -a` over <file>.zellij.bak, so the second
    # run destroyed the only copy of the user's original file (B16). Keep the
    # first backup where uninstall expects it; park later states in numbered
    # siblings so nothing is ever lost.
    local f="$1" n=1
    [[ -e "$f" ]] || return 0
    if [[ ! -e "$f.zellij.bak" ]]; then
        cp -a "$f" "$f.zellij.bak"
        warn "backed up $f -> $f.zellij.bak"
        return 0
    fi
    while [[ -e "$f.zellij.bak.$n" ]]; do n=$((n+1)); done
    cp -a "$f" "$f.zellij.bak.$n"
    warn "kept original $f.zellij.bak; re-run state saved to $f.zellij.bak.$n"
}

is_ours() { # is_ours <file> — true if file exists and carries the kit marker
    [[ -f "$1" ]] && grep -qF "$MARKER" "$1" 2>/dev/null
}

install_file() { # install_file <src> <dst> <link: 0|1> <render: 0|1>
    local src="$1" dst="$2" link="$3" render="$4" tmp
    backup "$dst"
    mkdir -p "$(dirname "$dst")"
    if (( link )) && (( ! render )); then
        ln -sfn "$src" "$dst"
    elif (( render )); then
        tmp="$(mktemp)"
        sed "s|__HELP_SH__|$ZDIR/help.sh|g" "$src" > "$tmp"
        install -m 644 "$tmp" "$dst"
        rm -f "$tmp"
    else
        install -m 644 "$src" "$dst"
    fi
    say "installed $dst"
}

append_hook() { # append_hook <src> — marker-guarded append to ~/.bashrc
    local src="$1"
    if grep -qF "$HOOK_OPEN" "$BRC" 2>/dev/null; then
        say "$BRC already has zellij-kit hooks (skipped)"
        return
    fi
    backup "$BRC"
    {
        [[ -f "$BRC" ]] && cat "$BRC"
        printf '\n%s\n' "$HOOK_OPEN"
        cat "$src"
        printf '%s\n' "$HOOK_CLOSE"
    } > "$BRC.tmp" && mv "$BRC.tmp" "$BRC"
    say "appended hooks to $BRC"
}

remove_hook() {
    if grep -qF "$HOOK_OPEN" "$BRC" 2>/dev/null; then
        awk -v o="$HOOK_OPEN" -v c="$HOOK_CLOSE" '
            $0 == o { skip=1 }
            !skip { print }
            $0 == c { skip=0 }
        ' "$BRC" > "$BRC.tmp" && mv "$BRC.tmp" "$BRC"
        say "removed zellij-kit hooks from $BRC"
    else
        say "$BRC has no zellij-kit hooks (nothing to do)"
    fi
}

install_bash_profile() { # marker-guarded: never clobber a foreign .bash_profile
    if is_ours "$BP"; then
        say "$BP already installed by zellij-kit (skipped)"
        return
    fi
    backup "$BP"
    if (( LINK )); then
        ln -sfn "$KIT_DIR/bash/bash_profile" "$BP"
    else
        install -m 644 "$KIT_DIR/bash/bash_profile" "$BP"
    fi
    say "installed $BP (your old one, if any, is at $BP.zellij.bak)"
}

cmd_install() {
    say "installing zellij-kit into $HOME"
    if ! command -v zellij >/dev/null 2>&1 && [[ ! -x "$HOME/.cargo/bin/zellij" ]]; then
        warn "zellij not found — install it (e.g. 'cargo binstall zellij') and re-run"
    fi
    mkdir -p "$ZDIR/layouts" "$BIN_DIR"

    install_file "$KIT_DIR/zellij/config.kdl" "$ZDIR/config.kdl"      "$LINK" 1
    install_file "$KIT_DIR/zellij/help.sh"    "$ZDIR/help.sh"         "$LINK" 0
    install_file "$KIT_DIR/zellij/layouts/default.kdl" "$ZDIR/layouts/default.kdl" "$LINK" 0
    install_file "$KIT_DIR/zellij/layouts/zen.kdl"     "$ZDIR/layouts/zen.kdl"     "$LINK" 0

    install_file "$KIT_DIR/bash/session-selector.sh" "$BIN_DIR/session-selector.sh" "$LINK" 0
    chmod +x "$BIN_DIR/session-selector.sh" 2>/dev/null || true

    install_bash_profile
    append_hook "$KIT_DIR/bash/bashrc.zellij"

    say "done. SSH into this machine to see the session picker;"
    say "run '$0 --check' to verify the install."
}

cmd_uninstall() {
    say "uninstalling zellij-kit from $HOME"
    local f src
    for f in "$ZDIR/config.kdl" "$ZDIR/help.sh" "$ZDIR/layouts/default.kdl" "$ZDIR/layouts/zen.kdl" "$BIN_DIR/session-selector.sh"; do
        if is_ours "$f"; then rm -f "$f"; say "removed $f"; fi
        # drop self-backups from re-runs (byte-identical to kit source), keep foreign originals
        case "$f" in
            "$ZDIR/config.kdl")                 src="$KIT_DIR/zellij/config.kdl" ;;
            "$ZDIR/help.sh")                    src="$KIT_DIR/zellij/help.sh" ;;
            "$ZDIR/layouts/default.kdl")        src="$KIT_DIR/zellij/layouts/default.kdl" ;;
            "$ZDIR/layouts/zen.kdl")            src="$KIT_DIR/zellij/layouts/zen.kdl" ;;
            "$BIN_DIR/session-selector.sh")     src="$KIT_DIR/bash/session-selector.sh" ;;
        esac
        # drop self-backups from re-runs: rendered config (this home's help path) or
        # byte-identical copies of kit sources; keep foreign originals either way
        if [[ -f "$f.zellij.bak" ]]; then
            drop=false
            if [[ "$f" == "$ZDIR/config.kdl" ]]; then
                grep -qF "$ZDIR/help.sh" "$f.zellij.bak" 2>/dev/null && drop=true
            elif [[ -f "$src" ]] && cmp -s "$f.zellij.bak" "$src"; then
                drop=true
            fi
            if $drop; then rm -f "$f.zellij.bak"; say "dropped self-backup $f.zellij.bak"; fi
        fi
    done
    rmdir "$ZDIR/layouts" 2>/dev/null || true
    rmdir "$ZDIR" 2>/dev/null || true
    # restore .bash_profile only if we own it
    if is_ours "$BP"; then
        rm -f "$BP"
        say "removed $BP"
        if [[ -f "$BP.zellij.bak" ]]; then mv "$BP.zellij.bak" "$BP"; say "restored $BP from backup"; fi
    fi
    remove_hook
    rmdir "$BIN_DIR" 2>/dev/null || true   # only removes if empty (i.e. we created it)
    rmdir "$HOME/.local" 2>/dev/null || true
    rmdir "$HOME/.config" 2>/dev/null || true
    # drop an empty or whitespace-only .bashrc we created from scratch
    if [[ -f "$BRC" ]] && ! grep -q '[^[:space:]]' "$BRC" 2>/dev/null; then rm -f "$BRC"; fi
    say "done."
}

LINK=0
case "${1:-}" in
    --link)      LINK=1; cmd_install ;;
    --uninstall) cmd_uninstall ;;
    --check)     bash "$KIT_DIR/zellij/verify.sh" ;;
    --help|-h)
        cat <<'EOF'
zellij-kit install.sh — locked-mode minimal zellij + SSH session picker

  ./install.sh              install (copies; backs up replaced files)
  ./install.sh --link       install as symlink farm (config.kdl still rendered)
  ./install.sh --check      verify installed setup against SPEC invariants
  ./install.sh --uninstall  remove kit files + bash hooks (marker-guarded)

Prereqs: bash, zellij, ssh. Idempotent; never clobbers foreign hooks.
EOF
        ;;
    *)           cmd_install ;;
esac
