SQLite bindings for the Dart VM
============================================

[![Build status](https://travis-ci.org/pylaligand/dart-sqlite.svg?branch=master)](https://travis-ci.org/pylaligand/dart-sqlite)

# Download

Try the [binary build](https://github.com/downloads/sam-mccall/dart-sqlite/v0.2.zip)
which should work on Mac, 64-bit Linux, and Windows.

You can also build it yourself, see below.

# Example
    #import('lib/sqlite.dart');
    var c = new sqlite.Database("/tmp/test.db");
    try {
        // Simple queries and statements
        Row results = c.first("SELECT ?+2, UPPER(?)", [3, "Hello"]);
        var five = results[0];
        var shouting = results[1];

        // Iterating over a result set
        var count = c.execute("SELECT * FROM posts LIMIT 10", callback: (row) {
            print("${row.title}: ${row.body}");
        });
        print("Showing ${count} posts.");

        // Reusing prepared statements
        var statement = c.prepare("INSERT INTO posts (title, body) VALUES (?,?)");
        try {
            statement.execute(["Hi", "Hello world"]);
            statement.execute(["Byte", "Goodbye cruel world"]);
        } finally {
            statement.close();
        }
    } finally {
        c.close();
    }

# Documentation

Yes! [Here's the dartdoc](http://sam-mccall.github.com/dart-sqlite/).

# Building (Linux/Mac)

You'll need:
  * Dart SDK
  * sqlite3-dev package
  * g++ toolchain.

Either edit build.sh to point to the SDK, or set the environment variable DART_SDK.

## Building the library

    ./build.sh

## Generating documentation

    ./build.sh doc

## Running tests

    ./build.sh test

# Building (Windows)

You'll need:

  * Dart SDK
  * dart.lib, the Dart native API library. You can obtain this by compiling Dart from source or grab [this version](https://github.com/downloads/sam-mccall/dart-sqlite/dart.lib) (last updated: 2012-04-24)
  * The [SQLite source code](http://www.sqlite.org/download.html) (the 'amalgamation')
  * Visual C++ 2008. The [free version](http://msdn.microsoft.com/en-us/express/future/bb421473) works fine.

Edit build.bat to point to the SDK and the SQLite sources.

## Building the library

Edit build.bat to specify where you extracted the SQLite and Dart sources.

    C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\vcvarsall.bat
    build

## Generating the documentation

    build doc

## Running tests

    build test

# Legal stuff
Copyright 2012 Google Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
