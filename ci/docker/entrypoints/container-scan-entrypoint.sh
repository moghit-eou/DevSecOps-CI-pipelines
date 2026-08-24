#!/bin/bash
###############################################################################
# ci/docker/entrypoints/container-scan-entrypoint.sh
#
# Runs inside the `mip-toolbox:container-scan` image. Builds the target
# project's own Docker image (via the host's Docker daemon, bind-mounted in
# as /var/run/docker.sock), then runs both scan types from
# ci/container_scan.py against it:
#   --scan-type sast  -> lints the Dockerfile itself (Hadolint + OpenGrep)
#   --scan-type sca   -> scans the built image (Trivy + OSV-Scanner)
#
# IMAGE_NAME and DOCKERFILE default below but are both overridable via env
# (see ci/docker/env/container-scan.env).
#
# Usage:
#   docker run --rm \
#     -v "$PWD/mip-backend-maven:/workspace" -w /workspace \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     --group-add "$(stat -c '%g' /var/run/docker.sock)" \
#     --env-file ci/docker/env/container-scan.env \
#     mip-toolbox:container-scan
###############################################################################
set -euo pipefail

if [[ "${1:-}" == "bash" || "${1:-}" == "sh" ]]; then
  exec "$@"
fi

DOCKERFILE="${DOCKERFILE:-Dockerfile}"
IMAGE_NAME="${IMAGE_NAME:-app:ci}"

if [[ ! -S /var/run/docker.sock ]]; then
  echo "[container-scan-entrypoint] ERROR: /var/run/docker.sock not found." >&2
  echo "This pipeline needs the host's Docker socket bind-mounted in:" >&2
  echo "  -v /var/run/docker.sock:/var/run/docker.sock" >&2
  echo "toolbox.sh does this automatically -- see toolbox.sh container-scan." >&2
  exit 1
fi

echo "[container-scan-entrypoint] Building ${IMAGE_NAME} from $(pwd)/${DOCKERFILE}"
docker build -f "${DOCKERFILE}" -t "${IMAGE_NAME}" .

echo "[container-scan-entrypoint] Running Dockerfile SAST scan (Hadolint + OpenGrep)"
sast_status=0
python3 /app/ci/container_scan.py --scan-type sast || sast_status=$?

echo "[container-scan-entrypoint] Running image SCA scan (Trivy + OSV-Scanner)"
sca_status=0
python3 /app/ci/container_scan.py --scan-type sca --image "${IMAGE_NAME}" || sca_status=$?

echo "[container-scan-entrypoint] Merging SARIF reports"
python3 /app/ci/container_scan.py \
  --merge-sarif "${TRIVY_SCA_SARIF_OUTPUT}" "${OSV_SCA_SARIF_OUTPUT}" \
                "${OPENGREP_SAST_SARIF_OUTPUT}" "${HADOLINT_SAST_SARIF_OUTPUT}" \
  --merge-output "${CONTAINER_SCAN_MERGED_SARIF_OUTPUT}"

if [[ "${sast_status}" -ne 0 || "${sca_status}" -ne 0 ]]; then
  echo "[container-scan-entrypoint] Gate failed (sast exit=${sast_status}, sca exit=${sca_status})" >&2
  exit 1
fi
