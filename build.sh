#!/bin/sh
if [ -z "$DART_SOURCES" ]; then
	DART_SOURCES="$HOME/dart"
fi
g++ -O2 -DDART_SHARED_LIB -I$DART_SOURCES/runtime/include src/dart_sqlite.cc -lsqlite3 -shared -rdynamic -fPIC -o lib/libdart_sqlite.so -m32
