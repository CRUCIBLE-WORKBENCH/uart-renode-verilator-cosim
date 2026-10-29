#!/usr/bin/env bash
# Fetch the pinned upstream commit into output/upstream and verify it.
# Re-running is cheap: an already-verified checkout is reused.
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/_common.sh"

require_host_tools git

verify_checkout() {
    [ "$(git -C "$UPSTREAM_DIR" rev-parse HEAD 2>/dev/null)" = "$UPSTREAM_COMMIT" ] \
        && [ -z "$(git -C "$UPSTREAM_DIR" status --porcelain --untracked-files=no)" ]
}

if [ -d "$UPSTREAM_DIR/.git" ] && verify_checkout; then
    echo "upstream: ${UPSTREAM_COMMIT} (cached)"
    exit 0
fi

rm -rf "$UPSTREAM_DIR"
mkdir -p "$UPSTREAM_DIR"
git -C "$UPSTREAM_DIR" init -q
git -C "$UPSTREAM_DIR" remote add origin "$UPSTREAM_URL"
git -C "$UPSTREAM_DIR" fetch -q --depth 1 origin "$UPSTREAM_COMMIT"
git -C "$UPSTREAM_DIR" -c advice.detachedHead=false checkout -q FETCH_HEAD

verify_checkout || die "upstream checkout is not ${UPSTREAM_COMMIT} or is modified"
echo "upstream: ${UPSTREAM_COMMIT} (fetched from ${UPSTREAM_URL})"
