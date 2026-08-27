# =============================================================================
# Stage: toolbox-base -- shared by all three pipelines
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base

ENV DEBIAN_FRONTEND=noninteractive

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


# =============================================================================
# Stage: db-downloader -- pulls Trivy DB once, isolated from the rest
# =============================================================================
FROM toolbox-base AS db-downloader

ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
RUN trivy image --download-db-only --cache-dir "${TRIVY_CACHE_DIR}" \
 && trivy image --download-java-db-only --cache-dir "${TRIVY_CACHE_DIR}"


# =============================================================================
# Stage: sast-toolbox -- OpenGrep only, no Trivy DB needed
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

ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
COPY --from=db-downloader /app/trivy-db-cache /app/trivy-db-cache

WORKDIR /workspace
ENTRYPOINT ["/app/ci/docker/entrypoints/sca-entrypoint.sh"]


# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Docker CLI
# =============================================================================
FROM toolbox-base AS container-scan-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
COPY --from=db-downloader /app/trivy-db-cache /app/trivy-db-cache

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/container_scan.py"]