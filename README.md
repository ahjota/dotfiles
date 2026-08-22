# dotfiles

> Life is like a hurricane here in Shellville  
> Needed me a toolchain to wrangle this shell hell  
> A syncing mystery with versioned history  
> Dotfiles! (Woo-oo!)  
> This repo's my attempt to repro  
> Dotfiles! (Woo-oo!)  
> Configs, options, run commands, and  
> profiles! (Woo-oo!)

## Supported Shells

- zsh 5.9
- bash 3.2 (required for MacOS Sonoma)
- bash 4.0 (Fedora)

## Prerequisites

### Required

[chezmoi](https://www.chezmoi.io/)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```

### Recommended

Package Manager: [Homebrew](https://brew.sh/)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Plugin Manager, zsh: [Antidote](https://getantidote.github.io/)

```sh
brew install antidote
```

Prompt: [Starship](https://starship.rs/)

```sh
curl -sS https://starship.rs/install.sh | sh
```

Shell History: [Atuin](https://atuin.sh)

```sh
# if it isn't already installed via homebrew, as it is in Bazzite-DX...
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
atuin setup
```

JSON Parser: jqlang/jq

```sh
brew install jq
```

### Optional

YAML Parser: mikefarah/yq

```sh
brew install yq
```

Environment Management: direnv

Faster Text Search: ripgrep

## Agent instructions

Global, cross-project agent guidance lives in `~/.agents/AGENTS.md` (chezmoi
source: [`dot_agents/AGENTS.md`](dot_agents/AGENTS.md)). This is a **personal
convention** — there is no cross-tool standard for a home/global instructions
location; the [agents.md](https://agents.md/) standard only covers
repository-root `AGENTS.md`. Each tool is wired to the canonical file:

- **Factory Droid** — reads `~/.agents/AGENTS.md` natively (it checks
  `~/.agents/` as a personal instruction directory).
- **Claude Code** — `~/.claude/CLAUDE.md` imports `@~/.agents/AGENTS.md`.
- **OpenCode** — `~/.config/opencode/AGENTS.md` is a chezmoi-managed symlink
  to `~/.agents/AGENTS.md`.
- **Zed** — `~/.config/zed/AGENTS.md` is a chezmoi-managed symlink to
  `~/.agents/AGENTS.md`.
- **Cursor / Bugbot / Obsidian** — no global-file support; use per-repo
  `AGENTS.md` / `.cursor/BUGBOT.md`.

### Syncing global rules into a repo

Repo-root `AGENTS.md` is the only standardized, tool-portable surface, so
`agents-sync` injects the global rules into a repo's `AGENTS.md` as a managed
block (between `<!-- BEGIN global agents -->` / `<!-- END global agents -->`
markers), preserving repo-specific content:

```sh
agents-sync                # inject/refresh into ./AGENTS.md
agents-sync /path/to/repo  # inject into another repo
agents-sync --check        # dry-run: exit 0 if in sync, 1 if stale/missing
agents-sync --remove       # strip the managed block
```

Re-running `agents-sync` refreshes the block without duplicating it.

## Fonts

[Fira Code Nerd Font](https://www.nerdfonts.com/font-downloads)

```sh
brew install font-fira-code-nerd-font
```

## App Preferences

### iTerm2

iTerm2 preferences are managed by chezmoi. Enable the `iterm2` data flag
during `chezmoi init` to have the preferences plist applied to
`~/Library/Preferences/com.googlecode.iterm2.plist`.

### Rectangle

[Rectangle](https://rectangleapp.com/) preferences are managed by chezmoi.
The preferences plist is applied to
`~/Library/Preferences/com.knollsoft.Rectangle.plist` on macOS.
A `run_onchange_` script relaunches Rectangle after the plist changes so the
new settings take effect immediately.

## Features

### Bash version probe

During `chezmoi init`, chezmoi will probe the current bash found in `PATH`
and persist its major version as `data.bashMajor` (or `0` if bash is N/A).

Use this data field to help determine whether to deploy a dotfile that
requires bash 4.0+ features (e.g. associative arrays) or to deploy one that
is portable.
