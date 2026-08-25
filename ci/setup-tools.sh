#!/bin/bash
set -e          # stop the pipeline if any command fails
set -o pipefail # Prevents silent pipeline successes if the curl download drops
set -u          # treat unset variables as an error

trap 'echo "[setup-tools] ERROR: command failed (exit $?) at line $LINENO: $BASH_COMMAND" >&2' ERR

# Tool versions and the SHA256 of the release asset we download.
# The "# renovate:" markers let Renovate bump version and checksum together
# (see renovate.json). When overriding a *_VERSION via env, the matching
# *_SHA256 must be overridden as well or verification will fail.

# renovate: datasource=github-release-attachments depName=aquasecurity/trivy
TRIVY_VERSION="${TRIVY_VERSION:-v0.71.1}"
TRIVY_SHA256="${TRIVY_SHA256:-3cbae37cd440cd8676e5ce9207fe460b5641c7579a17e9d00f8894928c41a88d}"

# renovate: datasource=github-release-attachments depName=google/osv-scanner
OSV_SCANNER_VERSION="${OSV_SCANNER_VERSION:-v2.4.0}"
OSV_SCANNER_SHA256="${OSV_SCANNER_SHA256:-15314940c10d26af9c6649f150b8a47c1262e8fc7e17b1d1029b0e479e8ed8a0}"

# renovate: datasource=github-release-attachments depName=opengrep/opengrep
OPENGREP_VERSION="${OPENGREP_VERSION:-v1.25.0}"
OPENGREP_SHA256="${OPENGREP_SHA256:-9ac4aebb47ba3f7b0d8fc641ac8749cb6c2f253f616131a67d9631e00d4bea33}"

# renovate: datasource=github-tags depName=semgrep/semgrep-rules
SEMGREP_RULES_REF="${SEMGREP_RULES_REF:-40b8c63f75dc7c22c8a77482d73bfb864b146f7e}"
SEMGREP_RULES_DIR="semgrep-rules"

# renovate: datasource=github-release-attachments depName=hadolint/hadolint
HADOLINT_VERSION="${HADOLINT_VERSION:-v2.14.0}"
HADOLINT_SHA256="${HADOLINT_SHA256:-6bf226944684f56c84dd014e8b979d27425c0148f61b3bd99bcc6f39e9dc5a47}"

# renovate: datasource=npm depName=@cyclonedx/cyclonedx-npm
CYCLONEDX_NPM_VERSION="${CYCLONEDX_NPM_VERSION:-6.0.0}"

# renovate: datasource=github-releases depName=CycloneDX/cyclonedx-gomod
CYCLONEDX_GOMOD_VERSION="${CYCLONEDX_GOMOD_VERSION:-v1.12.0}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# --- Flag parsing -----------------------------------------------------
INSTALL_TOOL="none"
SBOM_ECOSYSTEM="none"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-tool)
      [[ $# -ge 2 ]] || { echo "[setup-tools] --install-tool requires a value (e.g. trivy,osv-scanner|all)" >&2; exit 1; }
      INSTALL_TOOL="$2"
      shift 2
      ;;
    --sbom-ecosystem)
      [[ $# -ge 2 ]] || { echo "[setup-tools] --sbom-ecosystem requires a value (e.g. maven|npm|none)" >&2; exit 1; }
      SBOM_ECOSYSTEM="$2"
      shift 2
      ;;
    *)
      echo "[setup-tools] Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

should_install() {
  [[ "$INSTALL_TOOL" == "all" || ",$INSTALL_TOOL," == *",$1,"* ]]
}

# Download a file and refuse to proceed unless its SHA256 matches the pinned one
download_and_verify() {
  local url="$1" dest="$2" sha256="$3"
  curl -fsSL --retry 3 "${url}" -o "${dest}"
  echo "${sha256}  ${dest}" | sha256sum -c -
}

# --- Trivy --------------------------------------------------------------
if should_install "trivy"; then
  echo "[setup-tools] Installing Trivy ${TRIVY_VERSION}"
  TRIVY_TARBALL="trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz"
  download_and_verify \
    "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/${TRIVY_TARBALL}" \
    "${TMP_DIR}/${TRIVY_TARBALL}" \
    "${TRIVY_SHA256}"
  sudo tar -xzf "${TMP_DIR}/${TRIVY_TARBALL}" -C /usr/local/bin trivy
  trivy --version
  echo "Trivy installed OK"
fi

# --- OSV Scanner ----------------------------------------------------------
if should_install "osv-scanner"; then
  echo "[setup-tools] Installing OSV Scanner ${OSV_SCANNER_VERSION}"
  download_and_verify \
    "https://github.com/google/osv-scanner/releases/download/${OSV_SCANNER_VERSION}/osv-scanner_linux_amd64" \
    "${TMP_DIR}/osv-scanner" \
    "${OSV_SCANNER_SHA256}"
  sudo install -m 0755 "${TMP_DIR}/osv-scanner" /usr/local/bin/osv-scanner
  osv-scanner --version
  echo "OSV Scanner installed OK"
fi

# --- OpenGrep -------------------------------------------------------------
if should_install "opengrep"; then
  echo "[setup-tools] Installing OpenGrep ${OPENGREP_VERSION}"
  download_and_verify \
    "https://github.com/opengrep/opengrep/releases/download/${OPENGREP_VERSION}/opengrep_manylinux_x86" \
    "${TMP_DIR}/opengrep" \
    "${OPENGREP_SHA256}"
  sudo install -m 0755 "${TMP_DIR}/opengrep" /usr/local/bin/opengrep
  opengrep --version
  echo "OpenGrep installed OK"
fi

# --- Semgrep community ruleset (cloned, not registry) ---------
if should_install "semgrep-rules"; then
  echo "[setup-tools] Cloning semgrep-rules @ ${SEMGREP_RULES_REF}"
  rm -rf "${SEMGREP_RULES_DIR}"
  git clone --quiet https://github.com/semgrep/semgrep-rules.git "${SEMGREP_RULES_DIR}"
  git -C "${SEMGREP_RULES_DIR}" checkout --quiet "${SEMGREP_RULES_REF}"
  echo "semgrep-rules ready at ${SEMGREP_RULES_DIR} (ref: ${SEMGREP_RULES_REF})"
fi

# --- Hadolint ---------------------------------------------------------
if should_install "hadolint"; then
  echo "[setup-tools] Installing Hadolint ${HADOLINT_VERSION}"
  download_and_verify \
    "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-linux-x86_64" \
    "${TMP_DIR}/hadolint" \
    "${HADOLINT_SHA256}"
  sudo install -m 0755 "${TMP_DIR}/hadolint" /usr/local/bin/hadolint
  hadolint --version
  echo "Hadolint installed OK"
fi

# --- SBOM generation ----------------------------------------------------
case "$SBOM_ECOSYSTEM" in
  maven)
    echo "Generating SBOM for Maven project"
    mvn -B -ntp dependency:resolve -q
    mvn -B -ntp org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom -q
    ;;
  npm)
    echo "Generating SBOM for NPM project"
    npx --yes "@cyclonedx/cyclonedx-npm@${CYCLONEDX_NPM_VERSION}" --output-file target/bom.json
    ;;
  golang|go)
    echo "Generating SBOM for Go project"
    mkdir -p target
    go install "github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@${CYCLONEDX_GOMOD_VERSION}"
    "$(go env GOPATH)/bin/cyclonedx-gomod" mod -json -output target/bom.json
    ;;
  generic)
    # Filesystem-based scan via Syft (not build-integrated), less accurate
    # than the plugins above, use only when no dedicated ecosystem case exists.
    # Add your own case above for a specific ecosystem/plugin if you need
    # better accuracy than this fallback provides.
    echo "Generating SBOM via generic filesystem scan (less accurate)"
    mkdir -p target
    syft . -o cyclonedx-json=target/bom.json
    ;;
  none)
    echo "No SBOM generation needed"
    ;;
  *)
    echo "Unknown SBOM_ECOSYSTEM: $SBOM_ECOSYSTEM" >&2
    exit 1
    ;;
esac
