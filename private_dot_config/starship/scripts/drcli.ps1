# Emit the DataRobot CLI version, or exit non-zero if `dr` is not the
# DataRobot CLI (e.g. a different `dr` executable is on PATH).
$version = (dr self version --short -ErrorAction SilentlyContinue | Out-String).Trim()

if ($version -match "^v\d+\.") {
    $version
} else {
    exit 1
}
