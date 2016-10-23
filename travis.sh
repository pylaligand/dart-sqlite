#!/bin/bash

set -e -o pipefail

make build analyze test example

output=`make dart_files | xargs dartfmt -n`
if [[ -n "$output" ]]; then
  echo "Some files are not properly formatted:"
  echo $output
  echo "Please run 'make format'"
#  exit 314
fi
