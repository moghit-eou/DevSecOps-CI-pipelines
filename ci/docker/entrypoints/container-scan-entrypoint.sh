#!/bin/bash
set -euo pipefail

exec python3 /app/ci/container_scan.py "$@"