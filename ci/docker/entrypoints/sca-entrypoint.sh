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
#   docker run --rm -v "$PWD/mip-backend-maven:/workspace" -w /workspace \
#     --env-file ci/docker/env/sca.env mip-toolbox:sca
#
# Any extra args are passed straight through, so you can also drop into a
# shell for debugging:
#   docker run --rm -it -v "$PWD/mip-backend-maven:/workspace" -w /workspace \
#     mip-toolbox:sca bash
###############################################################################
set -euo pipefail

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
  exec "$@"
fi

echo "[sca-entrypoint] Resolving Maven dependencies in $(pwd)"
mvn -B -ntp dependency:resolve -q

echo "[sca-entrypoint] Generating SBOM (${SBOM_ECOSYSTEM:-maven})"
bash /app/ci/setup-tools.sh --sbom-ecosystem "${SBOM_ECOSYSTEM:-maven}"

echo "[sca-entrypoint] Running SCA scan"
exec python3 /app/ci/sca_scan.py "$@"
# Todo : the commands should be based on the ecosystem type, for example if the ecosystem is maven then run the maven commands, if the ecosystem is npm then run the npm commands, if the ecosystem is python then run the python commands, if the ecosystem is golang then run the golang commands, etc.