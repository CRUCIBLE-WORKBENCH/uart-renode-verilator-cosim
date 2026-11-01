# Shared paths and checks for the renode-RTL-cosim scripts. Source, don't run.

DEMO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUTPUT_DIR="${DEMO_DIR}/output"
UPSTREAM_DIR="${OUTPUT_DIR}/upstream"
BUILD_DIR="${OUTPUT_DIR}/apb3uart"
MODEL_PATH="${BUILD_DIR}/verilated"

# shellcheck source=../upstream.env
. "${DEMO_DIR}/upstream.env"

die() {
    echo "error: $*" >&2
    exit 1
}

require_linux_x64() {
    [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] \
        || die "this demo is measured on Linux x86_64 only (found $(uname -s) $(uname -m))"
}

# Host prerequisites the upstream CMake recipe needs. Crucible does not ship
# these; it checks for them so a missing one fails here, not mid-build.
require_host_tools() {
    local missing=()
    local t
    for t in "$@"; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    [ "${#missing[@]}" -eq 0 ] \
        || die "missing host prerequisite(s): ${missing[*]} (install them with your system package manager)"
}

# Print "<version> <install root>" for a tool bound in the active Crucible
# environment, as resolved by igny itself.
igny_tool_root() {
    igny tool show "$1" --json | python3 -c '
import json, pathlib, sys
r = json.load(sys.stdin).get("resolved") or {}
if not r.get("runnable"):
    sys.exit("%s is not runnable here: %s" % (sys.argv[1], r.get("reason")))
print(r["version"], pathlib.Path(r["executable"]).parent.parent)
' "$1"
}

# The version crucible.lock pins for a tool in the active environment.
locked_version() {
    python3 -c '
import json, sys
lock = json.load(open(sys.argv[1]))
env = next(e for e in lock["environments"] if e["name"] == lock["active_environment"])
print(next(t["version"] for t in env["tools"] if t["name"] == sys.argv[2]))
' "${DEMO_DIR}/crucible.lock" "$1"
}

# Resolve a tool and refuse to continue unless igny resolves the locked version.
resolve_locked_tool() {
    local name="$1" want got root
    want="$(locked_version "$name")" || die "crucible.lock has no entry for $name"
    read -r got root < <(igny_tool_root "$name") || die "igny could not resolve $name; run 'igny workspace sync' first"
    [ "$got" = "$want" ] \
        || die "$name $got is bound here but crucible.lock pins $want; run 'igny workspace sync'"
    echo "$root"
}

require_igny_env() {
    [ -n "${CRUCIBLE_ENV:-}" ] \
        || die "run this through Crucible so the locked tools are on PATH: igny run ./scripts/$(basename -- "$0")"
}
