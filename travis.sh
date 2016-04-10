#!/bin/bash

set -e

./build.sh
$DART_SDK/bin/dartanalyzer --lints --fatal-warnings --fatal-hints lib/*.dart test/*.dart
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
  echo "Bypassing tests on Mac OS..."
else
  $DART_SDK/bin/pub run test
fi
