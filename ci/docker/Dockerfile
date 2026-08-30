# =============================================================================
# Stage: toolbox-base -- OS-level deps + ci/ scripts only. No scanning
#                         tools installed here.
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ci/setup-tools.sh /app/ci/setup-tools.sh
RUN chmod +x /app/ci/setup-tools.sh


# =============================================================================
# Stage: toolbox-installer -- installs Trivy/OSV-Scanner/Hadolint/OpenGrep
#                              + semgrep-rules AND downloads the Trivy DB.
# =============================================================================
FROM toolbox-base AS toolbox-installer

RUN bash /app/ci/setup-tools.sh --install-tool \
        trivy,osv-scanner,hadolint,opengrep,semgrep-rules

ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
RUN trivy image --download-db-only --cache-dir "${TRIVY_CACHE_DIR}" \
 && trivy image --download-java-db-only --cache-dir "${TRIVY_CACHE_DIR}"


# =============================================================================
# Stage: sast-toolbox -- OpenGrep + semgrep-rules only
# =============================================================================
FROM toolbox-base AS sast-toolbox

COPY --from=toolbox-installer /usr/local/bin/opengrep /usr/local/bin/opengrep
COPY --from=toolbox-installer /app/semgrep-rules /app/semgrep-rules

COPY ci/ /app/ci/
RUN chmod +x /app/ci/setup-tools.sh /app/ci/docker/entrypoints/*.sh

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/sast_scan.py"]


# =============================================================================
# Stage: sca-toolbox -- Trivy + OSV-Scanner + Trivy DB + Maven/Node/Go...etc
# =============================================================================
FROM toolbox-base AS sca-toolbox

# install maven,npm... if you want accurate scanning for SCA tools like Trivy and OSV-Scanner
RUN apt-get update && apt-get install -y --no-install-recommends \
      maven \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolbox-installer /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=toolbox-installer /usr/local/bin/osv-scanner /usr/local/bin/osv-scanner
ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
COPY --from=toolbox-installer /app/trivy-db-cache /app/trivy-db-cache

COPY ci/ /app/ci/
RUN chmod +x /app/ci/setup-tools.sh /app/ci/docker/entrypoints/*.sh

WORKDIR /workspace
ENTRYPOINT ["/app/ci/docker/entrypoints/sca-entrypoint.sh"]


# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Trivy DB + Docker CLI
# =============================================================================
FROM toolbox-base AS container-scan-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

COPY --from=toolbox-installer /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=toolbox-installer /usr/local/bin/osv-scanner /usr/local/bin/osv-scanner
COPY --from=toolbox-installer /usr/local/bin/opengrep /usr/local/bin/opengrep
COPY --from=toolbox-installer /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=toolbox-installer /app/semgrep-rules /app/semgrep-rules
ENV TRIVY_CACHE_DIR=/app/trivy-db-cache
COPY --from=toolbox-installer /app/trivy-db-cache /app/trivy-db-cache

COPY ci/ /app/ci/
RUN chmod +x /app/ci/setup-tools.sh /app/ci/docker/entrypoints/*.sh

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/container_scan.py"]
