#!/bin/bash
###############################################################################
# toolbox.sh
#
# Runs one of three security pipelines, each in its own purpose-built Docker
# image (built from a distinct target in ci/docker/Dockerfile):
#   sast              -> mip-toolbox:sast
#   sca               -> mip-toolbox:sca
#   container-scan    -> mip-toolbox:container-scan
#
# Every pipeline is a single `docker run --rm` scoped to one project
# directory. Nothing to clean up, nothing shared between runs. The image is
# built automatically on first use.
#
# USAGE
#   ./toolbox.sh sast            <project-dir>
#   ./toolbox.sh sca             <project-dir> <ecosystem-type>
#   ./toolbox.sh container-scan  [image-name]
#
# EXAMPLES
#   ./toolbox.sh sast ./mip-backend-golang
#   ./toolbox.sh sca ./mip-backend-maven maven
#   ./toolbox.sh container-scan ./mip-backend-maven platform-backend:local
###############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${REPO_ROOT}/ci/docker/Dockerfile"
ENV_DIR="${REPO_ROOT}/ci/docker/env"



# --- one function per pipeline ----------------------------------------------

run_sast() {
#todo
}

run_sca() {
  #todo
}

run_container_scan() {
 #todo
}

# --- entrypoint ---------------------------------------------------------

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    sast)            run_sast "$@" ;;
    sca)             run_sca "$@" ;;
    container-scan)  run_container_scan "$@" ;;
    ""|-h|--help)    usage ;;
    *) echo "[toolbox] Unknown command: $cmd" >&2; usage ;;
  esac
}

main "$@"