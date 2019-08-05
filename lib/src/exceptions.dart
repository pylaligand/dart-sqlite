// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/// Exception indicating a SQLite-related problem.
class SqliteException implements Exception {
  SqliteException(String message) : this._internal(message);

  SqliteException._internal(this.message);

  final String message;

  @override
  String toString() => "SqliteException: $message";
}

/// Exception indicating that a SQL statement failed to compile.
class SqliteSyntaxException extends SqliteException {
  SqliteSyntaxException._internal(String message, this.query)
      : super._internal(message);

  /// The SQL that was rejected by the SQLite library.
  final String query;

  @override
  String toString() => "SqliteSyntaxException: $message. Query: [$query]";
}
