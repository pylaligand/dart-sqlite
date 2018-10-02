// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:mirrors';

import 'exceptions.dart';
import 'row.dart';

class RowMetadata {
  final List<String> columns;
  final Map<String, int> columnToIndex = <String, int>{};

  RowMetadata(this.columns) {
    for (int i = 0; i < columns.length; i++) {
      columnToIndex[columns[i]] = i;
    }
  }
}

class RowImpl implements Row {
  final RowMetadata _metadata;
  final List<dynamic> _data;

  @override
  final int index;

  RowImpl(this.index, this._metadata, this._data);

  @override
  dynamic operator [](dynamic i) {
    if (i is int) {
      return _data[i];
    } else {
      final int index = _metadata.columnToIndex[i];
      if (index == null) {
        throw new SqliteException('No such column $i');
      }
      return _data[index];
    }
  }

  @override
  List<Object> toList() => new List<Object>.from(_data);

  @override
  Map<String, Object> toMap() {
    final Map<String, Object> result = <String, Object>{};
    for (int i = 0; i < _data.length; i++) {
      result[_metadata.columns[i]] = _data[i];
    }
    return result;
  }

  @override
  String toString() => _data.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final String property = MirrorSystem.getName(invocation.memberName);
      final int index = _metadata.columnToIndex[property];
      if (index != null) {
        return _data[index];
      }
    }
    return super.noSuchMethod(invocation);
  }
}
