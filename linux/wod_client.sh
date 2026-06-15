#!/usr/bin/env bash
# Default launcher for the bundled Linux release.
# Ensures the binary loads libraries shipped in ./lib before falling back to
# system paths, so libmpv and its recursive dependencies are resolved without
# requiring system-wide installation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="robomaster_custom_client_1"

export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec "${SCRIPT_DIR}/${BINARY_NAME}" "$@"
