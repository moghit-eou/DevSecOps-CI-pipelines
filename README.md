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

## Usage

The Makefile is the only interface. Each target builds its pipeline's image on first
use (cached after) and runs an ephemeral `docker run --rm`. SARIF findings land in the
**project directory you pass to `PROJECT`** -- for SAST this is mandatory because the
SARIF output is written there.

```bash
# SAST -- scan source code, SARIF lands in PROJECT
make sast PROJECT=./test-mip-maven

# SCA -- resolve deps, generate SBOM, scan. ECOSYSTEM = maven | npm | golang | generic | none
make sca PROJECT=./test-mip-maven ECOSYSTEM=maven

# Container Scanning -- IMAGE must be built first
#   SCAN_TYPE=sast -> lints the Dockerfile
#   SCAN_TYPE=sca  -> scans the image (CVEs)
make container-scan IMAGE=platform-backend:local SCAN_TYPE=sast PROJECT=./test-mip-maven
make container-scan IMAGE=platform-backend:local SCAN_TYPE=sca
```

| Target | Required | Description |
|---|---|---|
| `make sast` | `PROJECT` | OpenGrep SAST. SARIF written to `PROJECT` |
| `make sca` | `PROJECT`, `ECOSYSTEM` | Trivy + OSV-Scanner on the SBOM. `ECOSYSTEM` selects the CycloneDX generator |
| `make container-scan` | `IMAGE`, `SCAN_TYPE` | `sast` lints the Dockerfile; `sca` scans the image |
| `make clean` | — | Removes SARIF outputs and the `mip-toolbox:*` images |

## Container Scanning

`make container-scan` is two scans in one pipeline (`ci/container_scan.py`):

- **`SCAN_TYPE=sast`** -- Hadolint + OpenGrep lint the `Dockerfile` in `PROJECT`.
- **`SCAN_TYPE=sca`** -- Trivy + OSV-Scanner scan the *already-built image*.

```bash
docker build -t app:local ./test-mip-maven                       # build first
make container-scan IMAGE=app:local SCAN_TYPE=sast PROJECT=./test-mip-maven
make container-scan IMAGE=app:local SCAN_TYPE=sca
```

The `sca` image scan needs your host Docker socket, so the image must exist on the host
before running.

## SCA: choosing your ecosystem + installing its runtime in the Dockerfile

The `ECOSYSTEM` you pick decides how the SBOM gets generated inside the SCA container:

| `ECOSYSTEM` | Method | Installed where |
|---|---|---|
| `maven` | `cyclonedx-maven-plugin` | must install `maven` in the image |
| `npm` | `@cyclonedx/cyclonedx-npm` | must install `node` in the image |
| `golang` | `cyclonedx-gomod` | must install `go` in the image |
| `generic` / `auto` | Trivy filesystem scan (less accurate) | no extra tools needed |
| `none` | skipped | no SBOM generated |

**Add your runtime to the image.** Edit `ci/docker/Dockerfile` and install whatever
build tool your ecosystem needs -- these are NOT preinstalled:

```dockerfile
FROM toolbox-base AS sca-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo python3 python3-pip maven nodejs \
    && rm -rf /var/lib/apt/lists/*
```

Want another ecosystem (gradle, rust, python, ...)? Add a `case` branch to
`ci/setup-tools.sh` (next to the `maven`/`npm`/`golang` blocks) the same way, install
the runtime in the Dockerfile above, then:

```bash
make sca PROJECT=./my-service ECOSYSTEM=gradle
```


## How to run (via Makefile)
 
Only the `Makefile` targets are covered here (they wrap `toolbox.sh` for you).
 
1. **Check the env files first.** Each pipeline reads its runtime config from `ci/docker/env/` (details in the section below):
   * `sast.env`
   * `sca.env`
   * `container-scan.env`
2. **If you want accurate SCA scanning for a specific ecosystem**, install that ecosystem's build tool in `ci/docker/Dockerfile`. See the SBOM/ecosystem section below for exactly where and how.
3. **Run one of the three commands.** `PROJECT` is the directory being scanned, and it's also where the SARIF report ends up:
```bash
   make sast PROJECT=./my-service
   make sca PROJECT=./my-service ECOSYSTEM=maven
   make container-scan IMAGE=my-service:local SCAN_TYPE=sca PROJECT=./my-service
```
 
```bash
   make clean   # removes local SARIF reports and the built toolbox images
```
 
> **Note on first run:** the first `make` call triggers a Docker build of the base image stage, which downloads the full Trivy vulnerability database. This makes the first run noticeably slower. Every run after that reuses cached layers and starts almost instantly.
 
4. **Install a SARIF viewer** in your editor (e.g. the "SARIF Viewer" VS Code extension) to browse the CVEs and findings from the generated `.sarif` files directly, instead of reading raw JSON.
## SBOM / ecosystem configuration (SCA)
 
SBOM generation is handled in `ci/setup-tools.sh` and controlled by the `ECOSYSTEM` / `SBOM_ECOSYSTEM` value:
 
* **maven, npm, golang/go**: SBOM generated through the matching CycloneDX plugin (`cyclonedx-maven-plugin`, `@cyclonedx/cyclonedx-npm`, `cyclonedx-gomod`). These already have their build tools installed in the `sca-toolbox` stage.
* **your own ecosystem** (e.g. Gradle, Rust): needs two additions, shown below with Gradle as the example
* **generic/auto** (default fallback): uses Syft to scan the filesystem directly, works for any ecosystem but is less accurate than a dedicated plugin
* Whenever you pick a specific ecosystem other than generic, its build tool must be installed in the Dockerfile, otherwise SBOM generation will fail
### 1. Install the build tool, in `ci/docker/Dockerfile`, `sca-toolbox` stage
 
This is the stage that already installs `maven`, `nodejs npm`, and `golang-go`, add your new ecosystem's tool to the same line:
 
```dockerfile
# ci/docker/Dockerfile
 
FROM toolbox-base AS sca-toolbox
 
RUN apt-get update && apt-get install -y --no-install-recommends \
      maven nodejs npm golang-go \
      gradle \
    && rm -rf /var/lib/apt/lists/*     # <-- add your ecosystem's package here, e.g. gradle
```
 
### 2. Add the matching SBOM case, in `ci/setup-tools.sh`
 
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
 
## Environment variables
 
Each pipeline reads its config from an `.env` file in `ci/docker/env/`, mounted into the container with `--env-file`. This lets you tweak a pipeline's behavior without rebuilding the Docker image.
 
* **`sast.env`**
  * `SEMGREP_CONFIG_RULESETS`: which Semgrep/OpenGrep rule directories to scan with (space-separated)
  * `OPENGREP_SARIF_OUTPUT` / `OPENGREP_EXCLUDE`: where the SARIF report is written, and which paths to skip
* **`sca.env`**
  * `SBOM_ECOSYSTEM`: which ecosystem to generate the SBOM for (`maven`, `npm`, `golang`, your own, or `generic`/`none`)
  * `SBOM_PATH`: where the generated SBOM lands (default `target/bom.json`)
  * `TRIVY_IGNOREFILE` / `OSV_IGNOREFILE`: paths to the suppression files for known, accepted CVEs
  * `TRIVY_SARIF_OUTPUT` / `OSV_SARIF_OUTPUT` / `SCA_MERGED_SARIF_OUTPUT`: where each tool's report (and the merged report) is written
* **`container-scan.env`**
  * `IMAGE_NAME`: the image being scanned
  * `TRIVY_IGNOREFILE` / `OSV_IGNOREFILE`: same suppression files as above, reused here
  * `SEMGREP_CONFIG_RULESETS`: rule set used for the Dockerfile SAST pass
  * `TRIVY_SCA_SARIF_OUTPUT` / `OSV_SCA_SARIF_OUTPUT`: image-scan reports
  * `OPENGREP_SAST_SARIF_OUTPUT` / `HADOLINT_SAST_SARIF_OUTPUT`: Dockerfile lint reports
Any of these can also be overridden per run with `-e VAR=value` if you don't want to edit the file directly.

## Gate status reference

Two gate models, depending on whether a tool reports **CVE severity** or **rule severity**:

**CVSS-score gate** (Trivy, OSV-Scanner -- SCA and container SCA):
highest `security-severity` across all SARIF results:

| Status | Meaning | Blocks? |
|---|---|---|
| `PASSED` | < 5.0 | No |
| `WARNING` | 5.0–7.9 | No |
| `FAILED` | >= 8.0 | Yes |
| `ERROR` | tool crashed / SARIF missing | Yes |

**Rule-severity gate** (OpenGrep, Hadolint -- all SAST):
the tool's own error-severity threshold decides:

| Status | Meaning | Blocks? |
|---|---|---|
| `PASSED` | no error-severity findings | No |
| `FAILED` | error-severity findings present | Yes |
| `ERROR` | tool did not run correctly | Yes |

## Viewing SARIF results

Install the VS Code SARIF viewer extension, then open any `.sarif` file in your
project directory to see findings inline with file/line/severity.

## Suppressing a false positive

Applies to **Trivy** and **OSV-Scanner** (SCA and container SCA), via the shared
ignore files:

- `ci/suppress_trivy.yaml`
- `ci/suppress_osv_scanner.toml`

Examples:

```yaml
# ci/suppress_trivy.yaml -- Trivy
vulnerabilities:
  - id: CVE-2026-54515
    statement: "Affected function is dead code (CGO_ENABLED=0)."
    expires: 2026-09-30
```

```toml
# ci/suppress_osv_scanner.toml -- OSV-Scanner
[[IgnoredVulns]]
id = "GHSA-5jmj-h7xm-6q6v"
ignoreUntil = 2026-09-30
reason = "Vulnerable function is never called."
```

- Trivy: [Filtering and ignore files](https://trivy.dev/docs/latest/configuration/filtering/#trivyignoreyaml)
- OSV-Scanner: [Ignore vulnerabilities by ID](https://google.github.io/osv-scanner/configuration/#ignore-vulnerabilities-by-id)

OpenGrep / Hadolint findings are rule-level; suppress those at the rule itself.
