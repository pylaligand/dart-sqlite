# Copyright 2012 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License")
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

DART_VERSION := $(shell dart --version 2>&1)
MACOS_ARCH :=
LINUX_ARCH :=
ifneq ($(findstring 32,$(lastword $(DART_VERSION))),)
  MACOS_ARCH = i386
  LINUX_ARCH = 32
else ifneq ($(findstring 64,$(lastword $(DART_VERSION))),)
  MACOS_ARCH = x86_64
  LINUX_ARCH = 64
else
  $(error Unsupported architecture in $(DART_VERSION))
endif

PLATFORM := $(shell uname -s)
G++_OPTIONS :=
GCC_OPTIONS :=
ifeq ($(PLATFORM),Darwin)
  G++_OPTIONS = -arch $(MACOS_ARCH)
  GCC_OPTIONS = -Wl,-install_name,libdart_sqlite.dylib,-undefined,dynamic_lookup -o lib/src/libdart_sqlite.dylib
else ifeq ($(PLATFORM),Linux)
  G++_OPTIONS = -m$(LINUX_ARCH)
  GCC_OPTIONS = -Wl,-soname,libdart_sqlite.so -o lib/src/libdart_sqlite.so
else
  $(error Unsupported platform $(PLATFORM))
endif

DART_FILES := \
  example/*.dart \
  lib/*.dart \
  lib/src/*.dart \
  test/*.dart \
  tool/*.dart

.PHONY: *
all: build

check-dart-sdk:
ifndef DART_SDK
	$(error The DART_SDK environment variable must be set!)
endif

build: check-dart-sdk
	mkdir -p out
	g++ -fPIC -I $(DART_SDK)/include -c lib/src/dart_sqlite.cc $(G++_OPTIONS) -o out/dart_sqlite.o
	gcc -shared $(GCC_OPTIONS) out/dart_sqlite.o -lsqlite3

test: check-dart-sdk build
	$(DART_SDK)/bin/pub run test

example: check-dart-sdk build
	$(DART_SDK)/bin/dart example/statements.dart

analyze: check-dart-sdk
	$(DART_SDK)/bin/dartanalyzer --fatal-lints --fatal-hints --fatal-warnings $(DART_FILES)

docs:
ifeq ($(shell which dartdoc),)
	$(error Dartdoc needs to be installed first!)
endif
	dartdoc

format: check-dart-sdk
	$(DART_SDK)/bin/dartfmt -w $(DART_FILES)

dart_files:
	@echo $(DART_FILES)

clean:
	rm -rf out
	find . -name *.so -o -name *.dylib | xargs rm

help:
	@echo "Targets:"
	@echo " build			Build the library"
	@echo " test			Run the unit tests"
	@echo " example		Run the examples"
	@echo " analyze		Run the Dart analyzer"
	@echo " docs			Generate the documentation"
	@echo " format			Format all Dart files"
