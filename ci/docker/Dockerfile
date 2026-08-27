# =============================================================================
# Stage: toolbox-base -- installs tools AND downloads the Trivy DB ONCE.
#                         Shared by all three pipelines.
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base

ENV DEBIAN_FRONTEND=noninteractive

# install maven,npm... if you want accurate scanning for SCA tools like Trivy and OSV-Scanner
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ci/setup-tools.sh /app/ci/setup-tools.sh
RUN chmod +x /app/ci/setup-tools.sh \
    && bash /app/ci/setup-tools.sh --install-tool \
        trivy,osv-scanner,hadolint,opengrep,semgrep-rules

COPY ci/ /app/ci/
RUN chmod +x /app/ci/docker/entrypoints/*.sh

# --- DB download folded in here, so it only ever runs once per base image ---
ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
RUN trivy image --download-db-only --cache-dir "${TRIVY_CACHE_DIR}" \
 && trivy image --download-java-db-only --cache-dir "${TRIVY_CACHE_DIR}"


# =============================================================================
# Stage: sast-toolbox -- OpenGrep only, no Trivy DB used but it's already
#                          in the base layer so no extra cost, no rebuild.
# =============================================================================
FROM toolbox-base AS sast-toolbox

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/sast_scan.py"]


# =============================================================================
# Stage: sca-toolbox -- Trivy + OSV-Scanner + Maven/Node/Go...etc
# =============================================================================
FROM toolbox-base AS sca-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends \
     && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENTRYPOINT ["/app/ci/docker/entrypoints/sca-entrypoint.sh"]


# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Docker CLI
# =============================================================================
FROM toolbox-base AS container-scan-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/container_scan.py"]