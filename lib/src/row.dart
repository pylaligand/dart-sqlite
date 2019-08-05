// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

/// A row of data returned from a executing a SQL query.
///
/// Entries can be accessed in several ways:
///   * By index: `row[0]`
///   * By name: `row['title']`
///   * By name: `row.title`
///
/// Column names are not guaranteed unless a SQL AS clause is used.
abstract class Row {
  /// This row's offset into the result set.
  int get index;

  /// Returns the value from the specified column.
  ///
  /// [i] may be a column name or index.
  dynamic operator [](dynamic i);

  /// Returns the values in this row as a list.
  List toList();

  /// Returns the values in this row as a map keyed by column name.
  ///
  /// The map iterates in column order.
  Map<String, dynamic> toMap();
}
