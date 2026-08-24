# zellij-kit

Locked-mode minimal zellij: bare UI, `Ctrl-g` mode ladder (`p` pane / `t` tab / `n` resize), `?` floating help, plus an SSH-login session picker with bash hooks.

Prereqs: bash, zellij, ssh.

```sh
./install.sh            # copy install (backs up anything replaced)
./install.sh --link     # symlink farm install
./install.sh --check    # verify against SPEC invariants
./install.sh --uninstall
```

Design rationale in `bash/SPEC.md`.
