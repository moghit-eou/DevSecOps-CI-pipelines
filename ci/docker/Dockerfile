FROM ubuntu:24.04 AS toolbox-base

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git sudo ca-certificates python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ci/*.py ci/*.sh ci/*.yaml ci/*.toml /app/ci/
RUN chmod +x /app/ci/setup-tools.sh

ENV TRIVY_IGNOREFILE=/app/ci/suppress_trivy.yaml \
    OSV_IGNOREFILE=/app/ci/suppress_osv_scanner.toml

RUN mkdir -p /workspace

FROM toolbox-base AS sca-toolbox

RUN apt-get update && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*
RUN cd /app/ci && ./setup-tools.sh --install-tool trivy,osv-scanner

COPY ci/docker/entrypoints/sca-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV SBOM_PATH=target/bom.json \
    TRIVY_SARIF_OUTPUT=trivy-app.sarif \
    OSV_SARIF_OUTPUT=osv-scanner-app.sarif \
    SCA_MERGED_SARIF_OUTPUT=SCA-app-merged.sarif \
    SBOM_ECOSYSTEM=maven

WORKDIR /workspace
ENTRYPOINT ["/app/entrypoint.sh"]