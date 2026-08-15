# Conditionally Including Work Content in Dotfiles

Runbook for keeping work-related dotfile content (internal hostnames,
work-only aliases, IT-mandated scripts) out of non-work machines and out of
the public repo where appropriate.

## The gate variable: `.dr`

All work conditional logic keys off a single boolean, `data.dr`, set during
`chezmoi init`:

```toml
# .chezmoi.toml.tmpl
{{ $isDRDevMachine := promptBoolOnce . "hasDrDev" "Develop DataRobot on this machine" }}
# ...
[data]
dr = {{ $isDRDevMachine }}
```

On non-work machines, `dr = false`. Every work-specific pattern below checks
this flag. The variable name is `.dr` (short for DataRobot), not `.work`.

Reference: [Configuration file / Template data](https://www.chezmoi.io/reference/configuration-file/),
[`promptBoolOnce`](https://www.chezmoi.io/reference/templates/functions/#promptboolonce)

---

## Pattern 1: `promptStringOnce` for internal hostnames

**Use when:** a template needs an internal hostname that should not appear
in the repo.

The hostname is prompted at `chezmoi init` time, stored in the local config
(`~/.config/chezmoi/chezmoi.toml`), and referenced in templates as a
variable. The repo contains only `{{ .hostname }}`, never the value.

### Setup

Add a `promptStringOnce` entry, gated on `.dr` so non-work machines are
never prompted:

```toml
# .chezmoi.toml.tmpl
{{ $artifactoryHost := "" }}
{{- if $isDRDevMachine }}
{{- $artifactoryHost = promptStringOnce . "artifactoryHost" "DataRobot Artifactory hostname" }}
{{- end }}

[data]
artifactoryHost = {{ $artifactoryHost | quote }}
```

### Usage in templates

```ini
# dot_pip/pip.conf.tmpl
[install]
{{- if .dr }}
trusted-host = {{ .artifactoryHost }}
{{- end }}
index-url = https://pypi.org/simple
{{- if .dr }}
extra-index-url =
        https://{{ .artifactoryHost }}/artifactory/api/pypi/python-all/simple
{{- end }}
```

On non-work machines: `artifactoryHost` is `""`, the `{{- if .dr }}`
blocks are skipped, and the rendered file is a plain pip.conf with no work
references.

### Adding more hostnames

Extend the same pattern for each internal hostname:

```toml
{{- if $isDRDevMachine }}
{{- $artifactoryHost = promptStringOnce . "artifactoryHost" "Artifactory hostname" }}
{{- $jenkinsHost    = promptStringOnce . "jenkinsHost" "Jenkins hostname" }}
{{- $internalGitHost = promptStringOnce . "internalGitHost" "Internal Git hostname" }}
{{- end }}
```

Then reference `{{ .jenkinsHost }}`, `{{ .internalGitHost }}`, etc. in any
template. Each resolves to `""` on non-work machines.

**Limitation:** gets tedious with many hostnames. For dozens of hostnames
or content more complex than simple substitution, consider encryption
(Pattern 4) or a separate work repo (Pattern 5).

Reference: [`promptStringOnce`](https://www.chezmoi.io/reference/templates/functions/#promptstringonce),
[Template data](https://www.chezmoi.io/user-guide/templating/#template-data)

---

## Pattern 2: `.chezmoiignore` for work-only files

**Use when:** an entire file should only exist on work machines (work-only
aliases, work-specific scripts you author).

### Setup

Create the file in the chezmoi source tree as normal. Then add a gate in
`.chezmoiignore` so it is skipped on non-work machines:

```
# .chezmoiignore
{{- if not .dr }}
.shellrc.d/56-work-aliases.sh
.local/bin/work-only-script
{{- end }}
```

Patterns match **target paths** (e.g. `.shellrc.d/56-work-aliases.sh`, not
`dot_shellrc.d/56-work-aliases.sh`).

### Work-only aliases example

```sh
# dot_shellrc.d/56-work-aliases.sh
{{- if .dr }}
alias jenkins="open https://{{ .jenkinsHost }}"
alias drdep="dr deployment"
{{- end }}
```

The file is sourced by both bash and zsh (via the `~/.shellrc.d/` loop in
`dot_bashrc.tmpl` and `dot_zshrc.tmpl`). On non-work machines, the file
either doesn't exist (ignored by chezmoi) or renders to an empty file.

### Combining with Pattern 1

If the file contains internal hostnames, use `promptStringOnce` (Pattern 1)
for the hostname values and `.chezmoiignore` (Pattern 2) to suppress the
file entirely on non-work machines. The two patterns compose cleanly.

Reference: [`.chezmoiignore`](https://www.chezmoi.io/reference/special-files/chezmoiignore/)

---

## Pattern 3: `.chezmoiexternal` for IT-mandated scripts

**Use when:** scripts are authored by IT/engineering, live in a central
repo, and need to stay in sync independently of your dotfiles.

`.chezmoiexternal` pulls files from external sources directly to the target
directory. The content never enters your dotfiles repo. Use a `.tmpl`
extension on the external config to gate it on `.dr`.

### Setup

```toml
# .chezmoiexternal.toml.tmpl
{{- if .dr }}
[".local/bin/company-vpn-check"]
    type = "file"
    url = "https://internal-git/it-scripts/raw/main/company-vpn-check"
    refreshPeriod = "24h"

[".local/bin/onboarding-verify"]
    type = "file"
    url = "https://internal-git/it-scripts/raw/main/onboarding-verify"
    refreshPeriod = "168h"
{{- end }}
```

On work machines, chezmoi pulls these files to `~/.local/bin/` and refreshes
them at the specified interval. On non-work machines, the `{{- if .dr }}`
gate means the externals are not even declared.

Force a refresh with:

```sh
chezmoi --refresh-externals apply
```

### Limitations

- External files are **static** — no template processing. Cannot use
  `{{ .artifactoryHost }}` in them.
- `git-repo` type externals are managed by git, not chezmoi; their contents
  won't appear in `chezmoi diff` or `chezmoi dump`.
- For large archives, use a `run_onchange_` script instead (see warning in
  the chezmoi docs).

Reference: [Include files from elsewhere](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/),
[`.chezmoiexternal` format](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/)

---

## Pattern 4: age encryption (for future, more sensitive content)

**Use when:** work content is more sensitive than just hostnames — internal
tool names, infrastructure topology, API patterns — and you want it
cryptographically hidden in the repo while keeping a single repo.

### Setup

1. Generate an age key:

   ```sh
   chezmoi age-keygen --output="$HOME/key.txt"
   ```

2. Add encryption config to `.chezmoi.toml.tmpl`:

   ```toml
   encryption = "age"
   [age]
       identity = "{{ .chezmoi.homeDir }}/key.txt"
       recipient = "age1..."  # your public key from step 1
   ```

   `encryption` must be at the top level, before any `[section]`.

3. Add a file with encryption:

   ```sh
   chezmoi add --encrypt ~/.some-work-config
   ```

   The file is stored in the repo as `encrypted_...` (ASCII-armored
   ciphertext). `chezmoi edit` transparently decrypts before editing and
   re-encrypts on save.

### Key management

- The key file (`key.txt`) lives locally, never in the repo.
- Distribute it to work machines out-of-band (1Password, AirDrop, etc.).
- Losing the key means losing the ability to decrypt. Back it up.

### The dual-file pattern

You cannot have two source files mapping to the same target. To have a
plain file on non-work machines and an encrypted work version, use
`.chezmoiignore` to ensure only one is active per machine:

```
# .chezmoiignore
{{- if .dr }}.pip/pip.conf{{- end }}        # ignore plain on work machines
{{- if not .dr }}.pip/pip.conf{{- end }}    # ignore encrypted on non-work
```

- `dot_pip/pip.conf` — plain static file, basic config, no work content.
- `encrypted_dot_pip/pip.conf.tmpl` — encrypted, full work template.

Since `.chezmoiignore` removes one before the other is active, there is no
target conflict.

### When to use this over Patterns 1-2

- Content contains more than hostname substitution (embedded secrets,
  internal tool names, infrastructure details).
- You want the URL *paths* or alias *contents* hidden, not just the
  hostnames.
- You have a large volume of sensitive work content that makes
  `promptStringOnce` impractical.

Reference: [age encryption](https://www.chezmoi.io/user-guide/encryption/age/),
[Encryption overview](https://www.chezmoi.io/user-guide/encryption/)

---

## Pattern 5: Separate work repo (for future, large-scale separation)

**Use when:** you want complete repo-level separation — zero work content
in the public repo, not even encrypted ciphertext.

Chezmoi does not natively support multiple `sourceDir` values. Two
sub-approaches:

### 5a: Two chezmoi invocations

Keep the main repo for personal dotfiles. Create a private work repo in
chezmoi format. On work machines, run both:

```sh
chezmoi apply                              # personal dotfiles
chezmoi --source="$HOME/work-dotfiles" apply  # work dotfiles
```

The work repo contains only work-specific files. Both apply to the same
target, so the work repo's files overwrite the personal repo's for the same
targets. Coordinate which files each repo manages to avoid conflicts.

### 5b: `.chezmoiexternal` with `type = "git-repo"`

Pull a private work repo into a target subdirectory:

```toml
# .chezmoiexternal.toml.tmpl
{{- if .dr }}
[".local/share/work-tools"]
    type = "git-repo"
    url = "https://internal-git/work-dotfiles.git"
    refreshPeriod = "24h"
{{- end }}
```

Limitation: `git-repo` externals are managed by git, not chezmoi. Files
inside are not interpreted as chezmoi templates. Good for static scripts,
not for templated configs.

Reference: [Include files from elsewhere](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/),
[Configuration file / `sourceDir`](https://www.chezmoi.io/reference/configuration-file/)

---

## Decision matrix

| Content type                     | Sensitive part      | Pattern |
|----------------------------------|---------------------|---------|
| pip.conf with artifactory        | Hostname            | 1 (promptStringOnce) — already in place |
| Work-only aliases with hostnames | Hostname            | 1 + 2 (promptStringOnce + .chezmoiignore) |
| Work-only aliases (no hostnames) | None (just gate)    | 2 (.chezmoiignore) |
| IT-mandated scripts              | N/A (external)      | 3 (.chezmoiexternal) |
| Complex work configs with secrets | Content itself    | 4 (age encryption) |
| Large volume of work dotfiles    | Everything          | 5 (separate work repo) |

## Current state

As of this writing, the repo uses:

- **Pattern 1** for `artifactoryHost` in `dot_pip/pip.conf.tmpl` and
  `dot_Rprofile.tmpl`.
- **Pattern 2** in `.chezmoiignore` for `workspace/DataRobot` and
  `.claude/skills/tech-debt-epic`.
- `{{- if .dr }}` conditionals in `dot_zshrc.tmpl` for work shell setup
  (quantumrc, GPG, env script).

Patterns 3-5 are documented for future use but not yet implemented.
