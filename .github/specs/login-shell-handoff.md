# Spec: bash login baseline with zsh handoff

Status: draft (saved 2026-08-09, not yet implemented)
Related issues: #80 (dependency taxonomy), #81 (per-host bash support), #83, #84

## Context

Supported shells (per README): zsh 5.9, bash 3.2 (macOS), bash 4.0+ (Fedora).

Facts established during the 2026-08-09 shell-compatibility review:

- Some tools read the login-shell entry from the passwd database directly
  (sshd for git/rsync/sftp, cron, `su`), rather than consulting `$SHELL`.
  That entry must therefore always name a shell that is guaranteed to exist.
- `bash` is the only shell present on every target host: macOS ships
  `/bin/bash` 3.2, Fedora/Bazzite ship bash 5, containers and rescue
  environments have bash.
- `zsh` is not guaranteed: it is preinstalled on macOS but optional on
  Fedora.
- Changing the passwd entry on Fedora normally means `chsh`, which lives in
  the `util-linux-user` package. Installing it was rejected: it adds a
  hard requirement for a one-time operation. (`sudo usermod -s` needs no
  new packages but still requires root, which is not always available.)
- `$SHELL` must never be set from `.zshenv`/`.zshrc`/`.bashrc`; it is
  normally set by `login(1)` from the passwd entry. The handoff below is
  the single sanctioned exception.

## Decision

1. The passwd login-shell entry stays `bash` on every host. It is the
   guaranteed-valid baseline for any tool that reads it directly.
2. Interactive login bash sessions hand off to zsh, when zsh is available,
   via `exec` at the end of `dot_bash_profile.tmpl`.
3. zsh is classified as an optional/recommended dependency, not required
   (feeds into #80).

## Implementation

Append to the end of `dot_bash_profile.tmpl`, after the `.bashrc` source
(everything after `exec` never runs):

```sh
# Hand off to zsh for interactive sessions when available.
# The passwd entry stays bash (guaranteed present on all hosts);
# $SHELL is updated to reflect the actual session shell.
if [[ $- == *i* ]] && command -v zsh >/dev/null 2>&1; then
    export SHELL="$(command -v zsh)"
    exec zsh -l
fi
```

Design notes:

- `command -v zsh`, not a hardcoded path: zsh lives at `/bin/zsh` (macOS),
  `/usr/bin/zsh` (Fedora), or `/opt/homebrew/bin/zsh` (Homebrew). Runtime
  lookup keeps one template valid on all hosts with no per-host chezmoi
  flag.
- `[[ $- == *i* ]]` restricts the handoff to interactive shells.
  Non-interactive login shells (`bash -l -c ...`, some ssh-based tooling)
  must stay in bash.
- The snippet is POSIX-plus-`[[ ]]`: valid on bash 3.2 and bash 5.x alike.
  No associative arrays (see #83).
- `dot_bashrc.tmpl` must NOT hand off: running `bash` deliberately from
  zsh, or tools spawning `bash -i`, should yield bash.
- `dot_zshrc.tmpl` is untouched.

## Platform notes

- macOS: `/bin/bash` is already in `/etc/shells`, so `chsh -s /bin/bash`
  is permitted where a passwd change is desired. Add
  `export BASH_SILENCE_DEPRECATION_WARNING=1` to `dot_bash_profile.tmpl`
  to suppress Apple's "default interactive shell is now zsh" login nag.
- Fedora/Bazzite: no new packages required. `/etc` is mutable on Atomic,
  so `sudo usermod -s /bin/bash "$USER"` remains an option where root
  exists, but this spec works with zero privileges.

## Consequences

- `getent passwd "$USER"` reports bash: always true, always safe for
  non-interactive tooling.
- `$SHELL` reports zsh when zsh exists, bash otherwise: always honest
  about the running session.
- Nothing in the stack ever points at a shell that is not installed.
- Known edge case: `bash -l` typed inside a zsh session hands back off to
  zsh. Acceptable; consistent with "login means zsh when available".

## Acceptance criteria

- [ ] Login shell with zsh installed results in a zsh session with
      `$SHELL` set to the resolved zsh path
- [ ] Login shell without zsh installed results in a bash session with no
      errors printed
- [ ] `bash -l -c 'echo hi'` stays in bash (no handoff)
- [ ] Verified on bash 3.2 (macOS `/bin/bash`) and bash 5.x (Fedora)
- [ ] `bash -n` passes on the rendered template
- [ ] README dependency list marks zsh as optional/recommended (with #80)
- [ ] Commit follows conventional commit spec

## Out of scope

- Automating passwd-entry changes (chsh/usermod) from chezmoi or CI
- Per-host chezmoi data flags for shell selection (runtime detection was
  chosen instead)
- The `10-droid.sh` bash 3.2 / zsh bugs (#83, #84); independent work
