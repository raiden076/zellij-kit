#!/bin/bash
# zellij-kit component — uninstall.sh only removes files carrying this marker.
#
# B20: a floating pane can never be taller than the terminal hosting it, so a
# fixed cheatsheet loses its TOP sections on short terminals — at 22x46 (a size
# this phone's terminal has actually used) only PANE/ANY were visible, i.e. the
# exact sections a stuck user needs first. Render whatever fits the pane we are
# running in; the pane is a real pty, so ask it for its size.
rows="${LINES:-}"
if [[ ! "$rows" =~ ^[0-9]+$ ]]; then
    rows="$(stty size 2>/dev/null | awk '{print $1}')"
fi
[[ "$rows" =~ ^[0-9]+$ ]] || rows=24

if (( rows >= 36 )); then
    cat <<'EOF'

RESIZE  (Ctrl+n)
  arrows      grow pane edge
  H J K L     shrink pane edge
  + / -       grow / shrink uniform

TAB  (Ctrl+t)
  n           new tab
  x           close tab
  1 - 9       jump to tab N
  arrows      prev / next tab

PANE  (Ctrl+p)
  d           split down
  r           split right
  s           stacked pane
  x           close pane
  f           fullscreen toggle
  w           floating toggle
  arrows      move focus

SCROLL  (Ctrl+s)
  arrows      line / page scroll
  PageUp/Down page scroll
  u / d       half page
  Ctrl+c      jump to live bottom
  Ctrl+s      leave scroll mode

ANY
  Ctrl+g      toggle locked / normal
  Esc         back to locked
  Enter       back to normal

EOF
else
    # Compact form: <=6 short lines, so it survives wrap in a 46-column pane.
    cat <<'EOF'
ZELLIJ KEYS  (start locked; Ctrl+g unlocks)
Ctrl+p pane    d/r/s split  x close  f float
Ctrl+t tab     n new  x close  1-9 go to
Ctrl+n resize  arrows grow  HJKL shrink
Ctrl+s scroll  arrows/PageUp  Ctrl+c bottom
? help  Esc locked  Enter normal  Ctrl+d detach
EOF
fi
read -n1 -s -r -p "press any key..."
