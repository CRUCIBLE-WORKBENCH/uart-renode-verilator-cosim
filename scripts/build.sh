#!/usr/bin/env bash
# Verilate the upstream APB3 UART RTL, hdl/sim.sv and Renode's DPI
# IntegrationLibrary into a co-simulation executable:
#   igny run ./scripts/build.sh
# Output: output/apb3uart/verilated, built against the locked Renode
# IntegrationLibrary and Verilator from this workspace's environment.
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/_common.sh"

require_linux_x64
require_igny_env
require_host_tools cmake make c++ perl python3 git

renode_root="$(resolve_locked_tool renode)"
verilator_root="$(resolve_locked_tool verilator)"
renode_sdk="${renode_root}/renode"
verilator_sdk="${verilator_root}/verilator/share/verilator"
[ -f "${renode_sdk}/plugins/IntegrationLibrary/integration-library.cmake" ] \
    || die "no Renode IntegrationLibrary under ${renode_sdk}"
[ -f "${verilator_sdk}/verilator-config.cmake" ] \
    || die "no Verilator CMake package under ${verilator_sdk}"

"${DEMO_DIR}/scripts/fetch_upstream.sh"

rm -rf "$BUILD_DIR"
VERILATOR_ROOT="$verilator_sdk" cmake -S "${DEMO_DIR}/hdl" -B "$BUILD_DIR" \
    -DUSER_RENODE_DIR="$renode_sdk" \
    -DUART_RTL="${UPSTREAM_DIR}/${UPSTREAM_SAMPLE}/Apb3UartCtrl.v"
VERILATOR_ROOT="$verilator_sdk" CCACHE_DISABLE=1 cmake --build "$BUILD_DIR" -j "$(nproc)"

[ -f "$MODEL_PATH" ] || die "build finished without ${MODEL_PATH}"
echo "model: ${MODEL_PATH}"
