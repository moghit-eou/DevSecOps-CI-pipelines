#!/bin/bash
set -euo pipefail

echo "[sca-entrypoint] Generating SBOM (ecosystem: ${SBOM_ECOSYSTEM})"
bash /app/ci/setup-tools.sh --sbom-ecosystem "${SBOM_ECOSYSTEM}"

echo "[sca-entrypoint] Running SCA scan"
exec python3 /app/ci/sca_scan.py "$@"