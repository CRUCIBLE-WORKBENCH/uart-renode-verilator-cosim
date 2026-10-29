#!/usr/bin/env bash
# Verilate the upstream APB3 UART RTL into a Renode co-simulation model:
#   igny run ./scripts/build.sh
# Output: output/apb3uart/libVtop.so, built against the locked Renode
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
[ -f "${verilator_sdk}/include/verilated.h" ] \
    || die "no Verilator runtime headers under ${verilator_sdk}"

"${DEMO_DIR}/scripts/fetch_upstream.sh"

rm -rf "$BUILD_DIR"
cmake -S "${UPSTREAM_DIR}/${UPSTREAM_SAMPLE}" -B "$BUILD_DIR" \
    -DUSER_RENODE_DIR="$renode_sdk" \
    -DUSER_VERILATOR_DIR="$verilator_sdk" \
    -DVERILATOR_BIN="${verilator_root}/tool_bin/verilator" \
    -DLIBOPENLIBM="${UPSTREAM_DIR}/lib/libopenlibm-Linux-x86_64.a"
CCACHE_DISABLE=1 cmake --build "$BUILD_DIR" --target libVtop -j "$(nproc)"

[ -f "$MODEL_PATH" ] || die "build finished without ${MODEL_PATH}"
echo "model: ${MODEL_PATH}"
