#!/bin/bash

#DART_SDK=$HOME/dart-sdk

if [ -z "$DART_SDK" ]; then
  DART_SDK="$HOME/dart-sdk"
fi

build() {
  SRCS="src/dart_sqlite.cc -lsqlite3"
  COPTS="-O2 -DDART_SHARED_LIB -I$DART_SDK/include -rdynamic -fPIC"
  OUTNAME="dart_sqlite"

  UNAME=`uname`
  if [[ "$UNAME" == "Darwin" ]]; then
    COPTS="$COPTS -dynamiclib -undefined suppress -flat_namespace"
    OUTNAME="lib$OUTNAME.dylib"
  else
    if [[ "$UNAME" != "Linux" ]]; then
      echo "Warning: Unrecognized OS $UNAME, this likely won't work"
    fi
    COPTS="$COPTS -shared"
    OUTNAME="lib$OUTNAME.so"
  fi
  echo g++ $COPTS $SRCS -o lib/$OUTNAME
  g++ $COPTS $SRCS -o lib/$OUTNAME
}

doc() {
  $DART_SDK/bin/dart $DART_SDK/lib/dartdoc/dartdoc.dart --mode=static lib/sqlite.dart && \
  rm -r docs/{dart_core,dart_coreimpl,dart-ext_dart_sqlite}{,.html} 2>/dev/null
  cp docs/sqlite.html docs/index.html
  # Hack: The library headers are all on one line, and sqlite is the last.
  find docs/ -name "*.html" | xargs sed -i "" 's/<h2>.*<h2>/<h2>/'
}

test() {
  build && \
  $DART_SDK/bin/dart test/test.dart
}

if [ -z "$1" ]; then
  build
else
  $1
fi
