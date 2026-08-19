# ci/Dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo ca-certificates python3 python3-pip python-is-python3 nodejs npm docker.io && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /repo
COPY platform-backend/ci/ ci/