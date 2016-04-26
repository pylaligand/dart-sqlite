// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart-ext:../dart_sqlite';

// Note: this import is required to allow the native code to instantiate and
// throw exceptions.
//ignore: unused_import
import 'exceptions.dart';

//
// Database
//

/// Opens the database at [path] and returns its handle.
dynamic newDatabase(String path) native 'New';

/// Closes a previously open database.
void closeDatabase(dynamic handle) native 'Close';

/// Returns the version of the sqlite library.
String version() native 'Version';

//
// Request
//

/// Creates a new native statement.
dynamic prepareStatement(dynamic db, String query) native 'PrepareStatement';

/// Closes the native statement.
void closeStatement(dynamic statement) native 'CloseStatement';

/// Binds values to the statement.
void bindValues(dynamic statement, List params) native 'Bind';

/// Runs the next evaluation step on the statement and returns a list of column
/// values, except when it's done in which case it returns the number of
/// affected rows.
dynamic evaluateStatement(dynamic statement) native 'Step';

/// Returns the list of column names for the results of the given statement.
List<String> getColumnInfo(dynamic statement) native 'ColumnInfo';
