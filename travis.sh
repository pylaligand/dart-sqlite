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

output=`make dart_files | xargs dartfmt -n`
if [[ -n "$output" ]]; then
  echo "Some files are not properly formatted:"
  echo $output
  echo "Please run 'make format'"
  exit 314
fi
