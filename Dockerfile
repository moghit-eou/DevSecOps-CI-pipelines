# Dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo ca-certificates python3 maven && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ci/ .

# --- Shared / general ---
ENV TRIVY_IGNOREFILE=/app/suppress_trivy.yaml
ENV OSV_IGNOREFILE=/app/suppress_osv_scanner.toml

# --- SCA (sca_scan.py) ---
ENV SBOM_PATH=target/bom.json
ENV TRIVY_SARIF_OUTPUT=trivy-platform-backend.sarif
ENV OSV_SARIF_OUTPUT=osv-scanner-platform-backend.sarif
ENV SCA_MERGED_SARIF_OUTPUT=SCA-platform-backend-merged.sarif

# --- SAST (sast_scan.py) ---
ENV SEMGREP_CONFIG_RULESETS="/app/semgrep-rules/generic /app/semgrep-rules/problem-based-packs /app/semgrep-rules/bash /app/semgrep-rules/java auto /app/semgrep-rules/yaml /app/semgrep-rules/package_managers p/default"
ENV OPENGREP_EXCLUDE="*.sarif ci/ Dockerfile* .pre-commit-config.yaml docs/** README.md AGENTS.md"
ENV OPENGREP_SARIF_OUTPUT=sast-opengrep-app.sarif

# --- Container scan (container_scan.py) ---
ENV IMAGE_NAME=platform-backend:local
ENV TRIVY_SCA_SARIF_OUTPUT=sca-trivy-container.sarif
ENV OSV_SCA_SARIF_OUTPUT=sca-osv-container.sarif
ENV OPENGREP_SAST_SARIF_OUTPUT=sast-opengrep-dockerfile.sarif
ENV HADOLINT_SAST_SARIF_OUTPUT=sast-hadolint-dockerfile.sarif


ENV IMAGE_NAME=platform-backend:local


#TODO: passed the tools installation during the build stage 
RUN chmod +x setup-tools.sh && \
    ./setup-tools.sh --install-tool trivy,osv-scanner


WORKDIR /workspace