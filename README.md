SQLite bindings for the Dart VM
============================================

[![Build status](https://travis-ci.org/pylaligand/dart-sqlite.svg?branch=master)](https://travis-ci.org/pylaligand/dart-sqlite)

# Installation

Add the library to your specs:
```
dependencies:
  sqlite: ^0.3.0
```

Add an extra step after `pub get` to download the native libraries:
```
pub get && pub run sqlite:install --package-root .
```

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

Yes! [Here's the dartdoc](http://pylaligand.github.com/dart-sqlite/).

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
