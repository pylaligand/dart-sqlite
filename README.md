SQLite bindings for the Dart VM
============================================

[![Build status](https://travis-ci.org/pylaligand/dart-sqlite.svg?branch=master)](https://travis-ci.org/pylaligand/dart-sqlite)


## Installation

Add the library to your specs:
```
dependencies:
  sqlite: ^0.3.0
```

Add an extra step after `pub get` to download the native libraries:
```
pub get && pub run sqlite:install --package-root .
```


## Documentation

See [the examples](example/) for how to use the library and the
[pub.dartlang.org](https://pub.dartlang.org/packages/sqlite) page for the API
documentation.


## Legal stuff

Copyright 2012 Google Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
