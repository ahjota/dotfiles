# dotfiles

> Life is like a hurricane here in Shellville  
> Needed me a toolchain to wrangle this shell hell  
> A syncing mystery with versioned history  
> Dotfiles! (Woo-oo!)  
> This repo's my attempt to repro  
> Dotfiles! (Woo-oo!)  
> Configs, options, run commands, and  
> profiles! (Woo-oo!)  

I'm in the process of migrating my [old dev repo](https://github.com/ahjota/dev/) here, as well as using some more advanced techniques that I have siloed on my work machine.

## Prerequisites

[homebrew](https://brew.sh/)
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

[antidote](https://getantidote.github.io/)
```sh
brew install antidote
```

I was previously using zinit. I was excited by the idea of its power, speed, and feature set, but trying to learn its syntax was a bear in 2022. Reflecting on this I am not enough of a power user to need its capabilities. After reading [the zsh-bench article](https://github.com/romkatv/zsh-bench) I've come to realize that other managers can be good enough. So I'm trying out antidote.

[chezmoi](https://www.chezmoi.io/)
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
```

This is a more interesting problem to me, keeping my dotfiles synced. I know a lot of folks use symlinks, but I am intrigued by the declarative template approach.
