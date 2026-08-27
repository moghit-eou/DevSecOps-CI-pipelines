# DevSecOps Security Pipelines

Reusable, security-focused CI pipelines built for GitHub Actions integration, developed as part of a GSoC project on reusable CI pipelines. Everything now runs fully inside Docker, no local tool installation required.

Automated security scanning, fully dockerized. Every pipeline runs in a dedicated
container built from `ci/docker/Dockerfile`, driven through the **Makefile**.

| Pipeline | Scans | Tools |
|---|---|---|
| **Container Scanning** | The built Docker image + the Dockerfile | Trivy, OSV-Scanner (image CVEs). Hadolint, OpenGrep (Dockerfile SAST) |
| **SCA** (Software Composition Analysis) | Application dependencies, via SBOM | Trivy, OSV-Scanner |
| **SAST** (Static Application Security Testing) | Application source code | OpenGrep |

The orchestrator scripts (`ci/*.py`) and `ci/setup-tools.sh` are unchanged from the
original native-runner implementation; only packaging and invocation changed (now Docker).

## Table of Contents

- [Repository Structure](#repository-structure)
- [Usage & Makefile](#usage)
- [Environment Variables](#environment-variables)
- [SCA: Ecosystem Configuration](#sca-ecosystem-configuration)
- [How to Run (via Makefile)](#how-to-run-via-makefile)
- [Gate Status Reference](#gate-status-reference)
- [Suppressing a False Positive](#suppressing-a-false-positive)
- [Related Resources](#related-resources)
- [License](#license)

## Repository Structure

```
├── ci/
│   ├── docker/
│   │   ├── entrypoints/
│   │   │   └── sca-entrypoint.sh
│   │   ├── env/
│   │   │   ├── container-scan.env
│   │   │   ├── sca.env
│   │   │   └── sast.env
│   │   ├── .dockerignore
│   │   └── Dockerfile
│   ├── suppress_trivy.yaml
│   ├── suppress_osv_scanner.toml
│   ├── parse_sarif.py
│   ├── sast_scan.py
│   ├── sca_scan.py
│   ├── setup-tools.sh
│   └── container_scan.py
├── toolbox.sh
└── Makefile
```

## Usage

The Makefile is the only interface. Each target builds its pipeline's image on first use (cached after) and runs an ephemeral `docker run --rm`.

`PROJECT` is the directory being scanned, and it is also where the SARIF report ends up. Specifying it is mandatory: it tells the pipeline both where to look for the code/Dockerfile to scan, and where to write the resulting `.sarif` output. For SAST specifically, the run will fail without it since the SARIF output has nowhere valid to land.

```bash
# SAST: scan source code, SARIF lands in PROJECT
make sast PROJECT=./test-mip-maven

# SCA: resolve deps, generate SBOM, scan. ECOSYSTEM = maven | npm | golang | generic | none
make sca PROJECT=./test-mip-maven ECOSYSTEM=maven

# Container Scanning: IMAGE must be built first
#   SCAN_TYPE=sast lints the Dockerfile
#   SCAN_TYPE=sca scans the image (CVEs)
make container-scan IMAGE=platform-backend:local SCAN_TYPE=sast PROJECT=./test-mip-maven
make container-scan IMAGE=platform-backend:local SCAN_TYPE=sca
```

| Target | Required | Description |
|---|---|---|
| `make sast` | `PROJECT` | OpenGrep SAST. SARIF written to `PROJECT` |
| `make sca` | `PROJECT`, `ECOSYSTEM` | Trivy + OSV Scanner on the SBOM. `ECOSYSTEM` selects the CycloneDX generator |
| `make container-scan` | `IMAGE`, `SCAN_TYPE` | `sast` lints the Dockerfile; `sca` scans the image |
| `make clean` | none | Removes SARIF outputs and the `mip-toolbox:*` images |

`make container-scan` is actually two scans in one pipeline (`ci/container_scan.py`):

- **`SCAN_TYPE=sast`**: Hadolint + OpenGrep lint the `Dockerfile` in `PROJECT`.
- **`SCAN_TYPE=sca`**: Trivy + OSV Scanner scan the already built image.

```bash
docker build -t app:local ./test-mip-maven                       # build first
make container-scan IMAGE=app:local SCAN_TYPE=sast PROJECT=./test-mip-maven
make container-scan IMAGE=app:local SCAN_TYPE=sca
```

> The `sca` image scan needs your host Docker socket, so the image must exist on the host before running.

## Environment Variables

Each pipeline reads its config from an `.env` file in `ci/docker/env/`, mounted into the container with `--env-file`. This lets you tweak a pipeline's behavior without rebuilding the Docker image. Any of these can also be overridden per run with `-e VAR=value` if you don't want to edit the file directly.

* **`sast.env`**
  * `SEMGREP_CONFIG_RULESETS`: which Semgrep/OpenGrep rule directories to scan with (space separated)
  * `OPENGREP_SARIF_OUTPUT` / `OPENGREP_EXCLUDE`: where the SARIF report is written, and which paths to skip
* **`sca.env`**
  * `TRIVY_IGNOREFILE` / `OSV_IGNOREFILE`: paths to the suppression files for known, accepted CVEs
  * `TRIVY_SARIF_OUTPUT` / `OSV_SARIF_OUTPUT` / `SCA_MERGED_SARIF_OUTPUT`: where each tool's report (and the merged report) is written
* **`container-scan.env`**
  * `TRIVY_IGNOREFILE` / `OSV_IGNOREFILE`: same suppression files as above, reused here
  * `SEMGREP_CONFIG_RULESETS`: rule set used for the Dockerfile SAST pass
  * `TRIVY_SCA_SARIF_OUTPUT` / `OSV_SCA_SARIF_OUTPUT`: image scan reports
  * `OPENGREP_SAST_SARIF_OUTPUT` / `HADOLINT_SAST_SARIF_OUTPUT`: Dockerfile lint reports

## SCA: Ecosystem Configuration

The `ECOSYSTEM` (a.k.a. `SBOM_ECOSYSTEM`) you pick decides how the SBOM gets generated inside the SCA container, in `ci/setup-tools.sh`:

| `ECOSYSTEM` | Method | Installed where |
|---|---|---|
| `maven` | `cyclonedx-maven-plugin` | already installed (`maven`) in `sca-toolbox` |
| `npm` | `@cyclonedx/cyclonedx-npm` | already installed (`nodejs npm`) in `sca-toolbox` |
| `golang` / `go` | `cyclonedx-gomod` | already installed (`golang-go`) in `sca-toolbox` |
| `generic` / `auto` (default fallback) | Syft filesystem scan (less accurate) | no extra tools needed, works for any ecosystem |
| `none` | skipped | no SBOM generated |

Whenever you pick a specific ecosystem other than `generic`, its build tool must be installed in the Dockerfile, otherwise SBOM generation will fail. Want another ecosystem (gradle, rust, python, etc)? Two additions are needed, shown below with Gradle as the example.

### 1. Install the build tool: `ci/docker/Dockerfile`, `toolbox-base` stage

Right now nothing is installed there. 

This stage is shared by every pipeline, including `make sca` and `make container-scan SCAN_TYPE=sca`, so add your ecosystem's build tool to it:

```dockerfile
# ci/docker/Dockerfile

FROM toolbox-base AS sca-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo python3 python3-pip \
      maven npm golang-go gradle ... \ # <--- add your ecosystem's package here, e.g. gradle, maven ...etc
    && rm -rf /var/lib/apt/lists/*     
```

### 2. Add the matching SBOM case: `ci/setup-tools.sh`

Add a new branch next to `maven`, `npm`, and `golang|go` in the `SBOM_ECOSYSTEM` case block:

```bash
# ci/setup-tools.sh

case "$SBOM_ECOSYSTEM" in
  maven)
    ...
    ;;
  npm)
    ...
    ;;
  golang|go)
    ...
    ;;
  gradle)
    echo "Generating SBOM for Gradle project"
    mkdir -p target
    # requires the CycloneDX Gradle plugin (org.cyclonedx.bom) configured in build.gradle
    gradle cyclonedxBom
    cp build/reports/bom.json target/bom.json
    ;;
  generic|auto)
    ...
    ;;
esac
```

```bash
make sca PROJECT=./my-service ECOSYSTEM=gradle
```

## How to Run (via Makefile)

Only the `Makefile` targets are covered here (they wrap `toolbox.sh` for you).

1. **Check the env files first.** Each pipeline reads its runtime config from `ci/docker/env/`: `sast.env`, `sca.env`, `container-scan.env` (details in [Environment Variables](#environment-variables)).
2. **If you want accurate SCA scanning for a specific ecosystem**, install that ecosystem's build tool in `ci/docker/Dockerfile`, see [SCA: Ecosystem Configuration](#sca-ecosystem-configuration).
3. **Run the relevant `make` target** (see [Usage & Container Scanning](#usage--container-scanning) above). Remember, `PROJECT` must point to the directory being scanned; that's also where the SARIF report ends up.
4. **Clean up when done:**
   ```bash
   make clean   # removes local SARIF reports and the built toolbox images
   ```

> **Note on first run:** the first `make` call triggers a Docker build of the base image stage, which downloads the full Trivy vulnerability database. This makes the first run noticeably slower. Every run after that reuses cached layers and starts almost instantly.

**Viewing results:** install a SARIF viewer in your editor (e.g. the "SARIF Viewer" VS Code extension) and open any `.sarif` file in your project directory to browse findings inline with file/line/severity, instead of reading raw JSON.

## Gate Status Reference

Two gate models, depending on whether a tool reports **CVE severity** or **rule severity**:

**CVSS score gate** (Trivy, OSV Scanner: SCA and container SCA): highest `security-severity` across all SARIF results:

| Status | Meaning | Blocks? |
|---|---|---|
| `PASSED` | < 5.0 | No |
| `WARNING` | 5.0 to 7.9 | No |
| `FAILED` | >= 8.0 | Yes |
| `ERROR` | tool crashed / SARIF missing | Yes |

**Rule severity gate** (OpenGrep, Hadolint: all SAST): the tool's own error severity threshold decides:

| Status | Meaning | Blocks? |
|---|---|---|
| `PASSED` | no error severity findings | No |
| `FAILED` | error severity findings present | Yes |
| `ERROR` | tool did not run correctly | Yes |

> The CVSS thresholds above (5.0 / 8.0) are not fixed; they're defined in `ci/parse_sarif.py` and can be adjusted there if your project needs stricter or looser gating.

## Suppressing a False Positive

Applies to **Trivy** and **OSV Scanner** (SCA and container SCA), via the shared ignore files:

- `ci/suppress_trivy.yaml`
- `ci/suppress_osv_scanner.toml`

Examples:

```yaml
# ci/suppress_trivy.yaml: Trivy
vulnerabilities:
  - id: CVE-2026-54515
    statement: "Affected function is dead code (CGO_ENABLED=0)."
    expires: 2026-09-30
```

```toml
# ci/suppress_osv_scanner.toml: OSV-Scanner
[[IgnoredVulns]]
id = "GHSA-5jmj-h7xm-6q6v"
ignoreUntil = 2026-09-30
reason = "Vulnerable function is never called."
```

OpenGrep / Hadolint findings are rule level; suppress those at the rule itself.

- Trivy: [Filtering and ignore files](https://trivy.dev/docs/latest/configuration/filtering/#trivyignoreyaml)
- OSV-Scanner: [Ignore vulnerabilities by ID](https://google.github.io/osv-scanner/configuration/#ignore-vulnerabilities-by-id)

## Related Resources

- **Live CI implementation**: see these pipelines wired up in a real project's GitHub Actions workflows: [Medical-Informatics-Platform/platform-backend/ci](https://github.com/Medical-Informatics-Platform/platform-backend/tree/master/ci)
- **GitHub Actions workflows**: the actual workflow files that call these pipelines: [Medical-Informatics-Platform/platform-backend/.github/workflows](https://github.com/Medical-Informatics-Platform/platform-backend/tree/master/.github/workflows)
- **EBRAIN DevSecOps Handbook**: full, detailed documentation for the EBRAIN community: [moghit-eou/EBRAIN-DevSecOps-handbook](https://github.com/moghit-eou/EBRAIN-DevSecOps-handbook)

## License

Free to use. No restrictions.