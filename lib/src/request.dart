// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:async';

import 'exceptions.dart';
import 'native.dart' as natives;
import 'row.dart';
import 'row_impl.dart';

/// Interface to issue a single request to a SQLite database.
class Request {
  /// Creates a new database request for the [sql] query.
  ///
  /// [db] must be the native handle to the database. Use [params] to specify
  /// values for placeholders in [sql].
  Request(dynamic db, String sql, {List params: const []})
      : this.sql = sql,
        this._params = params,
        _statement = natives.prepareStatement(db, sql);

  /// Handle to the native statement object.
  ///
  /// Null if the request is inactive.
  var _statement;

  /// The SQL query.
  ///
  /// May contain placeholders for values, to be specified when executing the
  /// request.
  final String sql;

  /// Values to bind to the statement.
  List _params;

  /// The number of rows affected by the request.
  ///
  /// Will only be available after all results have been streamed.
  int _affectedRows;

  /// Throws an exception if the request is not active.
  _ensureActive() {
    if (_statement == null) {
      throw SqliteException("Statement is closed");
    }
  }

  /// Closes this request and releases associated resources.
  ///
  /// This should be called exactly once for each instance created.
  /// After calling this method, attempting to execute the statement will throw
  /// [SqliteException].
  void _close() {
    _ensureActive();
    natives.closeStatement(_statement);
    _statement = null;
  }

  /// Issues the SQL query and streams the resulting rows.
  Stream<Row> query() {
    StreamController<Row> controller;
    RowMetadata rowMetadata;
    int index = 0;
    Timer timer;

    bool step() {
      var rawResult = natives.evaluateStatement(_statement);
      if (rawResult is int) {
        _affectedRows = rawResult;
        controller.close();
        return false;
      }
      final List result = rawResult;
      if (rowMetadata == null) {
        rowMetadata = RowMetadata(natives.getColumnInfo(_statement));
      }
      controller.add(RowImpl(index++, rowMetadata, result));
      return true;
    }

    void loop() {
      timer = Timer(Duration.zero, () {
        if (step()) {
          loop();
        }
      });
    }

    void start() {
      if (timer == null) {
        loop();
      }
    }

    void stop() {
      timer?.cancel();
      timer = null;
    }

    void finalize() {
      stop();
      _close();
    }

    _ensureActive();
    if (_params.isNotEmpty) {
      natives.bindValues(_statement, _params);
    }
    controller = StreamController(
        onListen: start, onPause: stop, onResume: start, onCancel: finalize);
    return controller.stream;
  }

  /// Executes the SQL query and returns the number of affected rows.
  Future<int> execute() {
    return query().length.then((_) => _affectedRows);
  }
}
