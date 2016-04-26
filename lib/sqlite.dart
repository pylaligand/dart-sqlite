// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:async';

import 'src/exceptions.dart';
import 'src/native.dart' as natives;
import 'src/request.dart';
import 'row.dart';

export 'src/exceptions.dart';
export 'row.dart';

/// A connection to a SQLite database.
///
/// Each database must be [close]d after use.
class Database {
  /// Handle to the native database, managed by the native layer.
  var _db;

  /// The location on disk of the database file.
  final String path;

  /// Opens the specified database file, creating it if it doesn't exist.
  Database(this.path) {
    _db = natives.newDatabase(path);
  }

  /// Creates a new in-memory database, whose contents will not be persisted.
  Database.inMemory() : this(":memory:");

  /// Returns the version number of the SQLite library.
  static String get version => natives.version();

  @override
  String toString() => "<sqlite: $path>";

  /// Closes the database.
  ///
  /// This should be called exactly once for each instance created.
  /// After calling this method, all attempts to operate on the database
  /// will throw [SqliteException].
  void close() {
    _ensureOpen();
    natives.closeDatabase(_db);
    _db = null;
  }

  /// Executes [callback] in a transaction.
  ///
  /// If the callbacks throws an exception, the transaction will be rolled back
  /// and the exception propagated, otherwise the transaction will be committed.
  Future transaction(Future operation()) {
    _ensureOpen();
    return execute('BEGIN')
        .then((_) => operation())
        .then((_) => execute('COMMIT'))
        .catchError((error, stackTrace) {
      return execute('ROLLBACK')
          .then((_) => new Future.error(error, stackTrace));
    });
  }

  /// Executes the SQL query and returns the number of affected rows.
  ///
  /// If [sql] has placeholders, use [params] to specify its values.
  Future<int> execute(String sql, {List params: const []}) {
    _ensureOpen();
    return new Request(_db, sql, params: params).execute();
  }

  /// Issues a SQL query and streams the resulting rows.
  ///
  /// If [sql] has placeholders, use [params] to specify its values.
  Stream<Row> query(String sql, {List params: const []}) {
    _ensureOpen();
    return new Request(_db, sql, params: params).query();
  }

  /// Checks that the database is open and throws an exception if it isn't.
  _ensureOpen() {
    if (_db == null) {
      throw new SqliteException("Database is closed");
    }
  }
}
