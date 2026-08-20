FROM ubuntu:24.04

# Install base runtimes, build tools, and package managers
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git sudo ca-certificates python3 python3-pip python-is-python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY ci/ .


RUN chmod +x setup-tools.sh && \
    ./setup-tools.sh --install-tool all


WORKDIR /workspace