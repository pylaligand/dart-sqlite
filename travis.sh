#!/bin/bash

set -e -o pipefail

make build
make analyze
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  echo "Bypassing tests on Mac OS..."
else
  make example
  make test
fi

output=`make format`
if echo $output | grep "Formatted"; then
  echo "Formatting issues!"
  exit 314
fi
