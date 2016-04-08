#!/bin/bash

if [[ -z "$DART_SDK" ]]; then
  echo "Missing DART_SDK environment variable."
  exit 1
fi

build() {
  $DART_SDK/bin/pub get

  PLATFORM="$(uname -s)"
  DART_VERSION=$(dart --version 2>&1)
  case "$DART_VERSION" in
    (*32*)
      MACOS_ARCH="i386"
      LINUX_ARCH="32"
      ;;
    (*64*)
      MACOS_ARCH="x86_64"
      LINUX_ARCH="64"
      ;;
    (*)
      echo Unsupported dart architecture $DART_VERSION.  Exiting ... >&2
      exit 3
      ;;
  esac

  echo "Building extension for platform $PLATFORM/$MACOS_ARCH"
  case "$PLATFORM" in
    (Darwin)
      g++ -fPIC -I $DART_SDK/include -c src/dart_sqlite.cc -arch $MACOS_ARCH
      gcc -shared \
        -Wl,-install_name,libdart_sqlite.dylib,-undefined,dynamic_lookup \
        -o lib/libdart_sqlite.dylib \
        dart_sqlite.o \
        -lsqlite3
      ;;
    (Linux)
      g++ -fPIC -I $DART_SDK/include -c src/dart_sqlite.cc -m$LINUX_ARCH
      gcc -shared \
        -Wl,-soname,libdart_sqlite.so \
        -o lib/libdart_sqlite.so \
        dart_sqlite.o \
        -lsqlite3
      ;;
    (*)
      echo Unsupported platform $PLATFORM.  Exiting ... >&2
      exit 3
      ;;
  esac
}

doc() {
  $DART_SDK/bin/dart $DART_SDK/lib/dartdoc/dartdoc.dart --mode=static lib/sqlite.dart && \
  rm -r docs/{dart_core,dart_coreimpl,dart-ext_dart_sqlite}{,.html} 2>/dev/null
  cp docs/sqlite.html docs/index.html
  # Hack: The library headers are all on one line, and sqlite is the last.
  find docs/ -name "*.html" | xargs sed -i "" 's/<h2>.*<h2>/<h2>/'
}

test() {
  build && $DART_SDK/bin/pub run test
}

if [ -z "$1" ]; then
  build
else
  $1
fi
