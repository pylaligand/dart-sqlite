#!/bin/bash

set -e

./build.sh
dartanalyzer --lints --fatal-warnings --fatal-hints lib/*.dart test/*.dart
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  echo "Bypassing tests on Mac OS..."
else
  pub run test
fi
