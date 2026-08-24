#!/bin/bash
###############################################################################
# toolbox.sh
#
# Local Docker toolbox for the three security pipelines (sast, sca,
# container-scan). This is the direct replacement for hand-rolled commands
# like:
#
#   docker run -d --name toolbox -v "$PWD/MIP-backend-test:/workspace" \
#     -w /workspace image:test sleep infinity
#   docker exec -it toolbox bash
#
# ...which breaks down once you have three pipelines that each want
# different tools installed and different (sometimes colliding) env vars in
# the same "toolbox" container. Instead, each pipeline gets:
#   - its own image (built from a distinct target in ci/docker/Dockerfile)
#   - its own env file (ci/docker/env/<pipeline>.env)
#   - its own ephemeral `docker run`, scoped to one project directory
#
# USAGE
#   ./toolbox.sh build [sast|sca|container-scan|all]
#   ./toolbox.sh sast   <project-dir>            # e.g. ./mip-backend-golang
#   ./toolbox.sh sca    <project-dir>
#   ./toolbox.sh container-scan <project-dir> [image-name]
#   ./toolbox.sh shell  <pipeline> <project-dir> # drop into a debug shell
#
# EXAMPLES
#   ./toolbox.sh build all
#   ./toolbox.sh sast ./mip-backend-golang
#   ./toolbox.sh sca ./mip-backend-maven
#   ./toolbox.sh container-scan ./mip-backend-maven platform-backend:local
#   ./toolbox.sh shell sca ./mip-backend-maven
#
# Every pipeline is a single `docker run --rm`, not a long-lived container
# you `docker exec` into -- there's nothing to forget to clean up, and two
# pipelines can run at once (e.g. in parallel terminal tabs) without their
# env vars ever touching each other, because they're two entirely separate
# containers/images.
###############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${REPO_ROOT}/ci/docker/Dockerfile"
ENV_DIR="${REPO_ROOT}/ci/docker/env"

usage() {
  sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

image_tag() { echo "mip-toolbox:${1}"; }
target_name() {
  case "$1" in
    sast) echo "sast-toolbox" ;;
    sca) echo "sca-toolbox" ;;
    container-scan) echo "container-scan-toolbox" ;;
    *) echo "Unknown pipeline: $1" >&2; exit 1 ;;
  esac
}

build_one() {
  local pipeline="$1"
  echo "[toolbox] Building $(image_tag "$pipeline") (target: $(target_name "$pipeline"))"
  docker build \
    -f "${DOCKERFILE}" \
    --target "$(target_name "$pipeline")" \
    -t "$(image_tag "$pipeline")" \
    "${REPO_ROOT}"
}

cmd_build() {
  local target="${1:-all}"
  if [[ "$target" == "all" ]]; then
    for p in sast sca container-scan; do build_one "$p"; done
  else
    build_one "$target"
  fi
}

require_project_dir() {
  local project_dir="$1"
  [[ -n "$project_dir" ]] || { echo "[toolbox] Missing <project-dir> argument" >&2; usage; }
  [[ -d "$project_dir" ]] || { echo "[toolbox] Not a directory: $project_dir" >&2; exit 1; }
}

run_pipeline() {
  local pipeline="$1" project_dir="$2"; shift 2
  require_project_dir "$project_dir"
  local abs_project_dir
  abs_project_dir="$(cd "$project_dir" && pwd)"
  local image
  image="$(image_tag "$pipeline")"

  docker image inspect "$image" >/dev/null 2>&1 || build_one "$pipeline"

  local run_args=(
    --rm
    -v "${abs_project_dir}:/workspace"
    -w /workspace
    --env-file "${ENV_DIR}/${pipeline}.env"
  )

  if [[ "$pipeline" == "container-scan" ]]; then
    if [[ ! -S /var/run/docker.sock ]]; then
      echo "[toolbox] ERROR: /var/run/docker.sock not found on this host." >&2
      echo "container-scan needs to 'docker build' the target image; it does" >&2
      echo "this via the host's Docker daemon (docker-outside-of-docker)." >&2
      exit 1
    fi
    local sock_gid
    sock_gid="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock)"
    run_args+=(
      -v /var/run/docker.sock:/var/run/docker.sock
      --group-add "${sock_gid}"
    )
    if [[ -n "${1:-}" ]]; then
      run_args+=(-e "IMAGE_NAME=$1")
    fi
  fi

  echo "[toolbox] Running ${pipeline} against ${abs_project_dir}"
  docker run "${run_args[@]}" "${image}"
}

cmd_shell() {
  local pipeline="$1" project_dir="$2"
  require_project_dir "$project_dir"
  local abs_project_dir image
  abs_project_dir="$(cd "$project_dir" && pwd)"
  image="$(image_tag "$pipeline")"
  docker image inspect "$image" >/dev/null 2>&1 || build_one "$pipeline"

  local run_args=(--rm -it -v "${abs_project_dir}:/workspace" -w /workspace --env-file "${ENV_DIR}/${pipeline}.env")
  if [[ "$pipeline" == "container-scan" && -S /var/run/docker.sock ]]; then
    run_args+=(-v /var/run/docker.sock:/var/run/docker.sock --group-add "$(stat -c '%g' /var/run/docker.sock)")
  fi
  docker run "${run_args[@]}" "${image}" bash
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    build) cmd_build "${1:-all}" ;;
    sast|sca) run_pipeline "$cmd" "${1:-}" ;;
    container-scan) run_pipeline "container-scan" "${1:-}" "${2:-}" ;;
    shell) cmd_shell "${1:-}" "${2:-}" ;;
    ""|-h|--help) usage ;;
    *) echo "[toolbox] Unknown command: $cmd" >&2; usage ;;
  esac
}

main "$@"
