#!/bin/bash
###############################################################################
# ci/docker/entrypoints/container-scan-entrypoint.sh
#
# Runs inside the `mip-toolbox:container-scan` image. Nothing to generate at
# runtime (unlike sca-entrypoint.sh's SBOM step) -- container_scan.py's own
# argparse CLI already handles --scan-type/--image/--merge-sarif, so this
# just forwards args to it.
#
# Usage (see toolbox.sh for the full docker run wrapper):
#   docker run --rm -v "$PWD/mip-backend-maven:/workspace" \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     --env-file ci/docker/env/container-scan.env \
#     mip-toolbox:container-scan --scan-type sca --image platform-backend:local
###############################################################################
set -euo pipefail

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
  exec "$@"
fi

exec python3 /app/ci/container_scan.py "$@"