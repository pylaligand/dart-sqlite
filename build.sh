#!/bin/bash

#DART_SOURCES=$HOME/dart
#DART_SDK=$HOME/dart-sdk

build() {
  if [ -z "$DART_SOURCES" ]; then
    DART_SOURCES="$HOME/dart"
  fi
  SRCS="src/dart_sqlite.cc -lsqlite3"
  COPTS="-O2 -DDART_SHARED_LIB -I$DART_SOURCES/runtime/include -rdynamic -fPIC -m32"
  OUTNAME="dart_sqlite"

  UNAME=`uname`
  if [[ "$UNAME" == "Darwin" ]]; then
    COPTS="$COPTS -dynamiclib -undefined suppress -flat_namespace"
    OUTNAME="$OUTNAME.dylib"
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
  if [ -z "$DART_SDK" ]; then
    DART_SDK="$HOME/dart-sdk"
  fi
  $DART_SDK/bin/dart $DART_SDK/lib/dartdoc/dartdoc.dart --mode=static lib/sqlite.dart && \
  rm -r docs/{dart_core,dart_coreimpl,dart-ext_dart_sqlite}{,.html} 2>/dev/null
  cp docs/sqlite.html docs/index.html
  # Hack: The library headers are all on one line, and sqlite is the last.
  find docs/ -name "*.html" | xargs sed -i 's/<h2>.*<h2>/<h2>/'
}

if [ -z "$1" ]; then
  build
else
  $1
fi
