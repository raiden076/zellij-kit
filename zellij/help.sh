#!/bin/bash
# zellij-kit component — uninstall.sh only removes files carrying this marker.
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

ANY
  Ctrl+g      toggle locked / normal
  Esc         back to locked
  Enter       back to normal

EOF
read -n1 -s -r -p "press any key..."
