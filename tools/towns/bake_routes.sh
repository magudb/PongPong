#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# The harness supplies the isolated user profile and performs the import scan.
TRAETOPPEN_BAKE_ROUTES=1 exec tests/run_playtest.sh --strict --no-boot --only=towns_routes "$@"
