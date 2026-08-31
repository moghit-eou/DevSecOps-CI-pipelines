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
# Each command is a single `docker run --rm` scoped to one project directory.
# Nothing to clean up, nothing shared between runs. Images build automatically
# on first use, and Docker layer caching makes reruns fast.
#
# container-scan sca inspects an image that already exists in the local Docker
# daemon, so build the image before running it.
#
# USAGE
#   ./toolbox.sh sast            <project-dir>
#   ./toolbox.sh sca             <project-dir> <ecosystem-type>
#   ./toolbox.sh container-scan  <image-name> <sast|sca> [project-dir]
#
# EXAMPLES
#   ./toolbox.sh sast ./test-golang
#   ./toolbox.sh sca ./test-maven maven
#   ./toolbox.sh container-scan platform-backend:local sast ./test-maven
#   ./toolbox.sh container-scan platform-backend:local sca
###############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${REPO_ROOT}/ci/docker/Dockerfile"
ENV_DIR="${REPO_ROOT}/ci/docker/env"
IMAGE_PREFIX="mip-toolbox"

# ci/setup-tools.sh pins x86-64 Linux release assets, so the toolbox images are
# always built and run as linux/amd64. On arm64 hosts (Apple Silicon) this runs
# under emulation, which also keeps findings comparable with the amd64 CI runner.
PLATFORM="linux/amd64"

# --- helpers ----------------------------------------------------------------

# Resolve the Docker socket from the active context rather than assuming /var/run/docker.sock.
docker_socket() {
  local endpoint
  endpoint="$(docker context inspect -f '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"

  case "$endpoint" in
    unix://*) endpoint="${endpoint#unix://}" ;;
    *)        endpoint="/var/run/docker.sock" ;;
  esac

  # Fail here rather than letting Docker create an empty directory at the mount
  # point, which surfaces later as an unhelpful "cannot connect to daemon".
  if [[ ! -S "$endpoint" ]]; then
    echo "[toolbox] No Docker socket at ${endpoint}." >&2
    echo "[toolbox] Docker Desktop: enable Settings > Advanced > 'Allow the default Docker socket to be used'." >&2
    exit 1
  fi

  printf '%s' "$endpoint"
}

abs_path() {
  local dir="${1}"
  if [[ ! -d "$dir" ]]; then
    echo "[toolbox] No such directory: ${dir}" >&2
    exit 1
  fi
  (cd "$dir" && pwd)
}

usage() {
  cat >&2 <<'EOF'
Usage:
  ./toolbox.sh sast            <project-dir>
  ./toolbox.sh sca             <project-dir> <ecosystem-type>
  ./toolbox.sh container-scan  <image-name> <sast|sca> [project-dir]

Examples:
  ./toolbox.sh sast ./test-golang
  ./toolbox.sh sca ./test-maven maven
  ./toolbox.sh container-scan platform-backend:local sast ./test-maven
  ./toolbox.sh container-scan platform-backend:local sca
EOF
  exit 1
}

build_stage() {
  local target="$1" tag="$2"
  docker build --platform "$PLATFORM" -f "$DOCKERFILE" --target "$target" -t "$tag" "$REPO_ROOT" >/dev/null
}

# --- one function per pipeline ----------------------------------------------

run_sast() {
  local project_dir="${1:?Usage: toolbox.sh sast <project-dir>}"
  local tag="${IMAGE_PREFIX}:sast"
  build_stage sast-toolbox "$tag"
  docker run --rm --platform "$PLATFORM" \
    -v "$(abs_path "$project_dir"):/workspace" \
    --env-file "${ENV_DIR}/sast.env" \
    "$tag"
}

run_sca() {
  local project_dir="${1:?Usage: toolbox.sh sca <project-dir> <ecosystem-type>}"
  local ecosystem="${2:?Usage: toolbox.sh sca <project-dir> <ecosystem-type>}"
  local tag="${IMAGE_PREFIX}:sca"
  build_stage sca-toolbox "$tag"
  docker run --rm --platform "$PLATFORM" \
    -v "$(abs_path "$project_dir"):/workspace" \
    --env-file "${ENV_DIR}/sca.env" \
    -e "SBOM_ECOSYSTEM=${ecosystem}" \
    "$tag"
}

run_container_scan() {
  local image_name="${1:?Usage: toolbox.sh container-scan <image-name> <sast|sca> [project-dir]}"
  local scan_type="${2:?Usage: toolbox.sh container-scan <image-name> <sast|sca> [project-dir]}"
  local project_dir="${3:-.}"
  local tag="${IMAGE_PREFIX}:container-scan"

  case "$scan_type" in
    sast|sca) ;;
    *) echo "[toolbox] scan-type must be 'sast' or 'sca', got: $scan_type" >&2; exit 1 ;;
  esac

  build_stage container-scan-toolbox "$tag"

  if [[ "$scan_type" == "sast" ]]; then
    # Scans the Dockerfile, needs the project dir mounted, no socket.
    docker run --rm --platform "$PLATFORM" \
      -v "$(abs_path "$project_dir"):/workspace" \
      --env-file "${ENV_DIR}/container-scan.env" \
      "$tag" --scan-type sast
  else
    # Scans the already-built image, needs the socket.
    docker run --rm --platform "$PLATFORM" \
      -v "$(docker_socket):/var/run/docker.sock" \
      -v "$(abs_path "$project_dir"):/workspace" \
      --env-file "${ENV_DIR}/container-scan.env" \
      "$tag" --scan-type sca --image "$image_name"
  fi
}

# --- entrypoint -------------------------------------------------------------

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
