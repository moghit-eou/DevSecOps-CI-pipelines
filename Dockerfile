# Dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo ca-certificates python3 maven && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ci/ .

#Supressions for Trivy and OSV-Scanner
ENV TRIVY_IGNOREFILE=/app/suppress_trivy.yaml
ENV OSV_IGNOREFILE=/app/suppress_osv_scanner.toml


ENV IMAGE_NAME=platform-backend:local



RUN chmod +x setup-tools.sh && \
    ./setup-tools.sh --install-tool trivy,osv-scanner


WORKDIR /workspace