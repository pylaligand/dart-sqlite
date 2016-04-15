#!/bin/bash

set -e

make build
make analyze
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  echo "Bypassing tests on Mac OS..."
else
  make example
  make test
fi
