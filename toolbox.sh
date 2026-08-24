#!/bin/bash
set -e

if [ "$1" == "build" ] && [ "$2" == "sca" ]; then
  echo "Building mip-toolbox:sca"
  docker build -f ci/docker/Dockerfile --target sca-toolbox -t mip-toolbox:sca .
fi