## Installed CLI tools

# https://gist.github.com/cynthiateeters/6868ca26c059a3106cd93736d33015af

{{ if .cliTools.ripgrep }}- **ripgrep** (`rg`) is installed — prefer over `grep` for shell searches{{ end }}
{{ if .cliTools.fd }}  - **fd** is installed — prefer over `find` for file finding by name/pattern{{ end }}
{{ if .cliTools.sd }}  - **sd** is installed — prefer over `sed` for find-and-replace in files{{ end }}
{{ if .cliTools.jq }}- **jq** is installed — use for JSON processing in shell pipelines{{ end }}
{{ if .cliTools.gnuParallel }}- **GNU parallel** is installed — use for concurrent shell tasks when beneficial{{ end }}
