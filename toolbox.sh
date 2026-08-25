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
# sast/sca are a single `docker run --rm` scoped to one project directory.
# container-scan needs three (build image, sast, sca, merge is folded into
# the third run), since that's how container_scan.py's CLI is shaped.
# Nothing to clean up, nothing shared between runs. Images build
# automatically on first use -- Docker layer caching makes reruns fast.
#
# USAGE
#   ./toolbox.sh sast            <project-dir>
#   ./toolbox.sh sca             <project-dir> <ecosystem-type>
#   ./toolbox.sh container-scan  <project-dir> [image-name]
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
IMAGE_PREFIX="mip-toolbox"

usage() {
  cat >&2 <<'EOF'
Usage:
  ./toolbox.sh sast            <project-dir>
  ./toolbox.sh sca             <project-dir> <ecosystem-type>
  ./toolbox.sh container-scan  <image-name> <sast|sca> [project-dir]

Examples:
  ./toolbox.sh sast ./mip-backend-golang
  ./toolbox.sh sca ./mip-backend-maven maven
  ./toolbox.sh container-scan platform-backend:local sca
  ./toolbox.sh container-scan platform-backend:local sast ./mip-backend-maven
EOF
  exit 1
}

build_stage() {
  local target="$1" tag="$2"
  docker build -f "$DOCKERFILE" --target "$target" -t "$tag" "$REPO_ROOT" >/dev/null
}

# --- one function per pipeline ----------------------------------------------

run_sast() {
  local project_dir="${1:?Usage: toolbox.sh sast <project-dir>}"
  local tag="${IMAGE_PREFIX}:sast"
  build_stage sast-toolbox "$tag"
  docker run --rm \
    -v "$(cd "$project_dir" && pwd):/workspace" \
    --env-file "${ENV_DIR}/sast.env" \
    "$tag"
}

run_sca() {
  local project_dir="${1:?Usage: toolbox.sh sca <project-dir> <ecosystem-type>}"
  local ecosystem="${2:?Usage: toolbox.sh sca <project-dir> <ecosystem-type>}"
  local tag="${IMAGE_PREFIX}:sca"
  build_stage sca-toolbox "$tag"
  docker run --rm \
    -v "$(cd "$project_dir" && pwd):/workspace" \
    --env-file "${ENV_DIR}/sca.env" \
    -e "SBOM_ECOSYSTEM=${ecosystem}" \
    "$tag"
}

run_container_scan() {
  TODO: implement container-scan pipeline
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