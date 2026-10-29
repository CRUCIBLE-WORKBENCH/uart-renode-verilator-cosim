#!/usr/bin/env bash
# Run the co-simulation and judge it, with two controls that must fail:
#   igny run ./scripts/smoke.sh
# 1. the real model: every register read must match the RTL;
# 2. a missing model: the same script must be rejected;
# 3. a wrong expected byte: the checker must reject the good log.
# Exits 0 only if all three behave. Logs go to output/smoke/.
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/_common.sh"

require_linux_x64
require_igny_env
require_host_tools python3 timeout
[ -f "$MODEL_PATH" ] || die "no model at ${MODEL_PATH}; run 'igny run ./scripts/build.sh' first"

SMOKE_DIR="${OUTPUT_DIR}/smoke"
CHECK="${DEMO_DIR}/scripts/check_uart_log.py"
mkdir -p "$SMOKE_DIR"
cd "$DEMO_DIR"

run_renode() {  # <log> <monitor commands>
    timeout 120 renode --disable-xwt --plain --console -e "$2" >"$1" 2>&1 \
        || die "renode did not exit cleanly (see $1)"
}

failed=0
verdict() {  # <name> <want: pass|reject> <command...>
    local name="$1" want="$2"
    shift 2
    if "$@" >"${SMOKE_DIR}/${name}.check" 2>&1; then got=pass; else got=reject; fi
    if [ "$got" = "$want" ]; then
        echo "ok    ${name}: ${got}"
    else
        echo "FAIL  ${name}: ${got}, expected ${want}"
        failed=1
    fi
    sed 's/^/        /' "${SMOKE_DIR}/${name}.check"
}

run_renode "${SMOKE_DIR}/uart.log" "include @scripts/uart_cosim.resc; quit"
verdict rtl-model pass python3 "$CHECK" "${SMOKE_DIR}/uart.log"

run_renode "${SMOKE_DIR}/missing-model.log" \
    "\$model=@${SMOKE_DIR}/does-not-exist.so; include @scripts/uart_cosim.resc; quit"
verdict missing-model reject python3 "$CHECK" "${SMOKE_DIR}/missing-model.log"

verdict wrong-expected-byte reject python3 "$CHECK" "${SMOKE_DIR}/uart.log" \
    --expect "DATA rx 'Z'=0x0001005B"

[ "$failed" -eq 0 ] || die "co-simulation smoke failed"
echo "co-simulation smoke passed"
