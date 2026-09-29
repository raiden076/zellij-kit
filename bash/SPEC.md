# SPEC.md

## §G — Goal

Home-directory server management. Dotfiles tracked in git (`~/dotfiles`), deployed via symlinks. Modular — each concern (shell env, session mgmt, tooling) is a self-contained unit with own invariants.

## §C — Constraints

| id | constraint |
|----|-----------|
| C1 | bash-only, no ncurses/tui libs |
| C2 | all dotfiles in `~/dotfiles` git repo, deployed via symlinks |
| C3 | single-file impl per concern, no external config |
| C4 | no root required — user-space only |
| C5 | idempotent — re-running any setup is safe |

## §M — Modules

| id | name | status | description |
|----|------|--------|-------------|
| M1 | session-selector | stable | zellij session picker on SSH/ET login |
| M2 | dotfiles-deploy | planned | symlink farm bootstrap from `~/dotfiles` |
| M3 | shell-env | planned | PATH, completions, prompt, atuin, ble.sh |
| M4 | tool-install | planned | bun, cargo, nvm, starship conventions |
M5 | zellij-config | stable | minimal UI, tmux-like keybinds, pane splits in `~/.config/zellij` |
M6 | status-bar | removed | status bar dropped for v1 — bare layout, no tab-bar, no hint pane |

## §I — Interfaces

| id | surface |
|----|---------|
| I.login | `.bash_profile` guard → calls `session-selector.sh` |
| I.zellij-list | `zellij list-sessions` — enumerate running sessions |
| I.zellij-attach | `zellij attach <name>` (attach), `zellij -s <name>` (spawn) |
| I.zellij-config | `~/.config/zellij/config.kdl` — runtime config (keybinds, UI, behavior) |
| I.zellij-layout | `~/.config/zellij/layouts/*.kdl` — pane layouts |
I.help | `~/.config/zellij/help.sh` — keybind cheatsheet triggered by `?` |

## §V — Invariants

| id | invariant |
|----|----------|
| V1 | selector exits cleanly on invalid input (no hang, no orphan) |
| V2 | session names auto-generated (timestamp or sequential) if user doesn't pick |
| V3 | dead sessions filtered via exit-code check from `zellij list-sessions` |
| V4 | spawning new session launches `$SHELL` or `/bin/bash` inside zellij |
| V5 | selector runs only on remote login (SSH_TTY or SSH_CONNECTION w/o SSH_TTY) AND shell is interactive |
| V6 | each session gets human-readable name (auto or user-chosen) |
V7 | zellij config preserves minimal UI: pane_frames false, simplified_ui true, default_layout "default"; bare layout (no status bar); single layout file `default.kdl`
| V8 | keybinds clear-defaults=true + explicit binds ∀ needed actions (no default keybinds leaked) |
| V9 | pane split binds exist: d/r/s for splits; arrow keys for focus; no hjkl |
| V10 | locked mode default + Ctrl+g toggle to normal mode |
| V11 | `?` in all modes except locked opens floating help pane with keybind cheatsheet; `?` passes through in locked |
V12 | no WASM plugins loaded; `simplified_ui true` strips arrows/shadows; `?` opens floating keybind help via `help.sh`; esc → locked, enter → normal

## §T — Tasks

| id | status | description | deps |
|----|--------|-------------|------|
| T1 | x | create `~/.local/bin/session-selector.sh` — menu loop, list/attach/spawn via zellij | V1,V2,V3,V4,V6,I.zellij-list,I.zellij-attach |
| T2 | x | add `.bash_profile` guard — call selector on SSH/ET login | V5,I.login |
| T3 | x | test: SSH in → see menu → attach existing | T1,T2 |
T4 | x | test: SSH in → spawn new → verify zellij session created | T1,T2
T5 | x | test: local terminal → selector does NOT run | T2,V5
| T6 | x | restore keybinds to `config.kdl` — keep minimal UI, add pane/tab/resize/move modes | V7,V8,V9,V10,I.zellij-config |
T7 | x | verify pane split: Ctrl+g → Ctrl+p → d/r; arrow keys move focus | T6,V9
T8 | x | verify tab nav: Ctrl+g → Ctrl+t → left/right switches tabs | T6
T9 | x | verify resize: Ctrl+g → Ctrl+n → arrows grow, H/J/K/L shrink | T6
T10 | x | verify no wasm plugins loaded; `?` help works; esc returns to locked | V11,V12
T11 | x | verify `?` opens help in normal/pane/tab/resize; `?` passes through to shell in locked | V11
T12 | x | enable simplified_ui true in config.kdl; bare layout (no status plugins, no tab-bar) | V12,I.zellij-layout
T13 | x | verify: zellij session → bare panes only, no arrows/shadows, no wasm, ? help floats, esc → locked | T12,V12

## §B — Bug Log

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2025-05-09 | V5 guard only checked SSH_TTY, missed Eternal Terminal (ET_SESSION) | Expand guard: SSH_TTY OR ET_SESSION |
| B2 | 2025-05-09 | Selector runs after .bashrc, shows first prompt before menu | Move guard before .bashrc source |
| B3 | 2025-05-09 | read -r keypresses ignored — terminal buffering | Use read -n1 from /dev/tty |
| B4 | 2025-05-09 | `zellij -s name -- $SHELL` — double-dash args not valid for zellij spawn | Remove `-- $SHELL`, zellij uses $SHELL by default |
| B5 | 2025-05-09 | ET sets no ET_SESSION var; real fingerprint is SSH_CONNECTION + no SSH_TTY | Guard checks SSH_TTY OR (SSH_CONNECTION AND !SSH_TTY) |
| B6 | 2025-05-09 | Selector re-ran inside zellij (bash_profile sourced again) | Check $ZELLIJ env var, skip selector if set |
| B7 | 2025-05-09 | zellij list-sessions output has \r — name parsed with trailing \r | Strip \r from parsed session names |
| B8 | 2025-05-09 | zellij colors session names with ANSI escapes → parsed name includes escape codes → attach fails | Pipe through sed to strip ANSI before parsing |

| B9 | 2026-05-09 | keybinds block left empty after migration to minimal UI | restore explicit keybinds from backup; keep clear-defaults=true; `?` help via floating Run with close_on_exit; `?` bound in shared_except "locked" only; compact-bar tooltip "Ctrl h" for phone-friendly hint toggle |
| B10 | 2026-05-09 | compact-bar tooltip incorrectly bound to F1 (inaccessible on phone); `?` incorrectly excluded from normal mode | change tooltip key to Ctrl+h; move `?` from shared_except "locked" "normal" to shared_except "locked" |
B11 | 2026-05-09 | zjstatus WASM plugin broken: renders only green line, no content | replaced with tab-bar + simplified_ui; later removed entirely for bare layout (B12)
B12 | 2026-05-09 | tab-bar + hint pane added noise on phone; ESC/? behavior inconsistent | stripped to bare layout; help via floating `?` pane only; esc → locked from all modes
| B13 | 2026-08-24 | zellij via `cargo binstall` lives in ~/.cargo/bin, not on PATH when selector execs (before .bashrc); `exec zellij` fails "not found" | selector resolves zellij across PATH + ~/.cargo/bin + kit bin; bash_profile sources ~/.cargo/env before the guard
| B14 | 2026-09-29 | verify.sh "no absolute home paths" grepped `/home/` in the *rendered* config, which always contains the host's own `$ZDIR/help.sh` → `--check` could never go green on a host with $HOME under /home (seen on arch-phone: 29 pass / 1 fail, that check being the only failure) | new `foreign_home_paths` helper allows exactly the rendered `$ZDIR/help.sh` and flags any other `/home/...` path (negative-tested with a foreign config path)
| B15 | 2026-09-29 | V3 dead-session filter matched only the legacy `[Dead]`/`[Exit]` markers; zellij 0.39+ prints `(EXITED - attach to resurrect)` → the SSH picker offered month-old sessions (arch-phone: 3 dead + 1 live) that resolve to nothing with `session_serialization false` | filter also matches `*EXITED*`, keeping the legacy markers for older zellij; verified: menu lists live sessions only, `n` spawns a kit-configured session, numeric choice attaches to the listed one |
