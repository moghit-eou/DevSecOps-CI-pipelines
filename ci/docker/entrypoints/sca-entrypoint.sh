#!/bin/bash
###############################################################################
# ci/docker/entrypoints/sca-entrypoint.sh
#
# Runs inside the `mip-toolbox:sca` image. Trivy/OSV-Scanner are already
# baked into the image (build time), but the SBOM has to be generated
# against whatever project is bind-mounted at /workspace at container-run
# time, so that step happens here instead of in the Dockerfile.
#
# Usage (see toolbox.sh for the full docker run wrapper):
#   docker run --rm -v "$PWD/mip-backend-maven:/workspace" \
#     --env-file ci/docker/env/sca.env -e SBOM_ECOSYSTEM=maven mip-toolbox:sca
###############################################################################
set -euo pipefail

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
  exec "$@"
fi

echo "[sca-entrypoint] Generating SBOM (ecosystem: ${SBOM_ECOSYSTEM:-maven})"
bash /app/ci/setup-tools.sh --sbom-ecosystem "${SBOM_ECOSYSTEM:-maven}"

echo "[sca-entrypoint] Running SCA scan"
exec python3 /app/ci/sca_scan.py "$@"