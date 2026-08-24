# syntax=docker/dockerfile:1.7
###############################################################################
# ci/docker/Dockerfile
#
# One multi-stage Dockerfile, one build TARGET per pipeline:
#   toolbox-base        shared OS deps + non-root user + ci/ scripts (not
#                        run directly, just a common ancestor)
#   sast-toolbox         -> mip-toolbox:sast
#   sca-toolbox           -> mip-toolbox:sca
#   container-scan-toolbox -> mip-toolbox:container-scan
#
# WHY ONE FILE WITH TARGETS INSTEAD OF THREE FILES:
# The original repo had a single Dockerfile that installed every tool and
# declared every pipeline's ENV vars (SAST + SCA + container-scan) all at
# once -- IMAGE_NAME was even declared twice. Run that image for "just
# SAST" and it still drags around SCA/container-scan tools and env you
# don't want. Using `docker build --target <stage>` instead means:
#   - each target only RUNs the setup-tools.sh install for the tools it
#     needs -- smaller, faster, purpose-built images
#   - each target only declares ITS OWN env vars -- no cross-pipeline
#     collisions, no stale IMAGE_NAME/SARIF_OUTPUT leaking between pipelines
#   - Docker's build cache/order guarantees toolbox-base is always built
#     before its children (unlike separate untagged Dockerfiles, which
#     have no ordering guarantee between independent `docker build` calls)
#   - one file to keep in sync, three independent, minimal images to run
#
# Build context for every target below MUST be the REPO ROOT:
#   docker build -f ci/docker/Dockerfile --target sast-toolbox -t mip-toolbox:sast .
#
# toolbox.sh / docker-compose.yml / the Makefile all wrap this so you never
# have to type the raw `docker build` command by hand.
###############################################################################

# =============================================================================
# Stage: toolbox-base -- shared by all three pipelines
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        sudo \
        ca-certificates \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo -- setup-tools.sh installs binaries
# into /usr/local/bin via sudo, same as it does on GitHub-hosted runners.
# Non-root user with passwordless sudo -- setup-tools.sh installs binaries
# into /usr/local/bin via sudo, same as it does on GitHub-hosted runners.
#
# ubuntu:24.04 already ships a default "ubuntu" user/group at 1000:1000, so
# creating a new "toolbox" user at the same UID/GID would collide. Instead:
# remove any existing user/group already sitting on the target UID/GID, then
# create "toolbox" cleanly on top of it.
ARG TOOLBOX_UID=1000
ARG TOOLBOX_GID=1000
RUN existing_group="$(getent group "${TOOLBOX_GID}" | cut -d: -f1 || true)"; \
    [ -n "${existing_group}" ] && [ "${existing_group}" != "toolbox" ] && groupdel "${existing_group}" || true; \
    existing_user="$(getent passwd "${TOOLBOX_UID}" | cut -d: -f1 || true)"; \
    [ -n "${existing_user}" ] && [ "${existing_user}" != "toolbox" ] && userdel -r "${existing_user}" 2>/dev/null || true; \
    groupadd -g "${TOOLBOX_GID}" toolbox \
    && useradd -m -u "${TOOLBOX_UID}" -g "${TOOLBOX_GID}" -s /bin/bash toolbox \
    && echo "toolbox ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/toolbox \
    && chmod 0440 /etc/sudoers.d/toolbox

# Tooling lives at /app, never at /workspace: /workspace is the bind-mount
# point for the user's project source at `docker run` time and would shadow
# anything installed there at build time (e.g. a cloned semgrep-rules/ dir).
WORKDIR /app
COPY ci/*.py ci/*.sh ci/*.yaml ci/*.toml /app/ci/
RUN chmod +x /app/ci/setup-tools.sh

# Shared, pipeline-agnostic env vars ONLY. Anything pipeline-specific is set
# in that pipeline's own stage below, never here.
ENV TRIVY_IGNOREFILE=/app/ci/suppress_trivy.yaml \
    OSV_IGNOREFILE=/app/ci/suppress_osv_scanner.toml \
    PYTHONUNBUFFERED=1

RUN mkdir -p /workspace && chown -R toolbox:toolbox /app /workspace

# =============================================================================
# Stage: sast-toolbox -- OpenGrep only
# =============================================================================
FROM toolbox-base AS sast-toolbox

USER root
RUN cd /app/ci && ./setup-tools.sh --install-tool opengrep,semgrep-rules \
    && chown -R toolbox:toolbox /app/ci
USER toolbox

# Consumed by ci/sast_scan.py
ENV SEMGREP_CONFIG_RULESETS="/app/ci/semgrep-rules/generic /app/ci/semgrep-rules/problem-based-packs /app/ci/semgrep-rules/bash /app/ci/semgrep-rules/java auto /app/ci/semgrep-rules/yaml /app/ci/semgrep-rules/package_managers p/default" \
    OPENGREP_EXCLUDE="*.sarif ci/ Dockerfile* .pre-commit-config.yaml docs/** README.md AGENTS.md" \
    OPENGREP_SARIF_OUTPUT=sast-opengrep-app.sarif

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/sast_scan.py"]

# =============================================================================
# Stage: sca-toolbox -- Trivy + OSV-Scanner + Maven (for SBOM generation)
# =============================================================================
FROM toolbox-base AS sca-toolbox

USER root
RUN apt-get update && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*
RUN cd /app/ci && ./setup-tools.sh --install-tool trivy,osv-scanner
COPY ci/docker/entrypoints/sca-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown -R toolbox:toolbox /app
USER toolbox

# Consumed by ci/sca_scan.py. SBOM generation happens at container-run time
# (see entrypoint.sh) since it needs the mounted project's pom.xml.
ENV SBOM_PATH=target/bom.json \
    TRIVY_SARIF_OUTPUT=trivy-app.sarif \
    OSV_SARIF_OUTPUT=osv-scanner-app.sarif \
    SCA_MERGED_SARIF_OUTPUT=SCA-app-merged.sarif \
    SBOM_ECOSYSTEM=maven

WORKDIR /workspace
ENTRYPOINT ["/app/entrypoint.sh"]

# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Docker CLI (docker-outside-of-docker)
# =============================================================================
FROM toolbox-base AS container-scan-toolbox

USER root

# Docker CLI only (no dockerd inside the container). The host's daemon
# socket is bind-mounted in at `docker run` time so `docker build` executed
# in here builds on, and is visible to, the host daemon.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

RUN cd /app/ci && ./setup-tools.sh --install-tool trivy,osv-scanner,opengrep,hadolint,semgrep-rules
COPY ci/docker/entrypoints/container-scan-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown -R toolbox:toolbox /app
USER toolbox

# Consumed by ci/container_scan.py
ENV IMAGE_NAME=app:ci \
    TRIVY_SCA_SARIF_OUTPUT=sca-trivy-container.sarif \
    OSV_SCA_SARIF_OUTPUT=sca-osv-container.sarif \
    SEMGREP_CONFIG_RULESETS="/app/ci/semgrep-rules/dockerfile auto" \
    OPENGREP_SAST_SARIF_OUTPUT=sast-opengrep-dockerfile.sarif \
    HADOLINT_SAST_SARIF_OUTPUT=sast-hadolint-dockerfile.sarif \
    CONTAINER_SCAN_MERGED_SARIF_OUTPUT=container-scan-merged.sarif

WORKDIR /workspace
ENTRYPOINT ["/app/entrypoint.sh"]
