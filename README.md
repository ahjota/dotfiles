# dotfiles

> Life is like a hurricane here in Shellville  
> Needed me a toolchain to wrangle this shell hell  
> A syncing mystery with versioned history  
> Dotfiles! (Woo-oo!)  
> This repo's my attempt to repro  
> Dotfiles! (Woo-oo!)  
> Configs, options, run commands, and  
> profiles! (Woo-oo!)  

## Prerequisites

[homebrew](https://brew.sh/)
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

[antidote](https://getantidote.github.io/)
```sh
brew install antidote
```

[chezmoi](https://www.chezmoi.io/)
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```

[atuin](https://atuin.sh)
```sh
curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
```

This installs atuin in `~/.atuin/bin`.

## Fonts

[Fira Code Nerd Font](https://www.nerdfonts.com/font-downloads)
```sh
brew install font-fira-code-nerd-font
```

## Prompt

[Starship](https://starship.rs/)
```sh
curl -sS https://starship.rs/install.sh | sh
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
