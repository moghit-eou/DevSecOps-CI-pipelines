# =============================================================================
# Stage: toolbox-base -- shared by all three pipelines
# =============================================================================
FROM ubuntu:24.04 AS toolbox-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git sudo python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ci/ /app/ci/
RUN chmod +x /app/ci/setup-tools.sh /app/ci/docker/entrypoints/*.sh


# =============================================================================
# Stage: sast-toolbox -- OpenGrep only
# =============================================================================
FROM toolbox-base AS sast-toolbox

RUN bash /app/ci/setup-tools.sh --install-tool opengrep,semgrep-rules

WORKDIR /workspace
ENTRYPOINT ["python3", "/app/ci/sast_scan.py"]



# =============================================================================
# Stage: sca-toolbox -- Trivy + OSV-Scanner + Maven (for SBOM generation)
# =============================================================================
FROM toolbox-base AS sca-toolbox

#Todo for later 

# =============================================================================
# Stage: container-scan-toolbox -- Trivy + OSV-Scanner + OpenGrep + Hadolint
#                                    + Docker CLI (docker-outside-of-docker)
# =============================================================================
FROM toolbox-base AS container-scan-toolbox
# Todo for later 
