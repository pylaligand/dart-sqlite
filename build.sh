#!/bin/bash
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
