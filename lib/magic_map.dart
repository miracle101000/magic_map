import 'dart:convert';

// Custom exception for MagicMap errors
class MagicMapException implements Exception {
  final String message;
  final String? path;

  // Constructor to initialize the exception with a message and an optional path
  MagicMapException(this.message, [this.path]);

  // Override toString method to format the error message with optional path
  @override
  String toString() =>
      'MagicMapException: $message${path != null ? ' (at path: $path)' : ''}';
}

// The main MagicMap class for working with dynamic nested data
class MagicMap {
  // Holds the actual dynamic data, can be Map, List, or any other type
  final dynamic _data;

  // Constructor that wraps the data into a MagicMap
  MagicMap([dynamic data]) : _data = _wrap(data ?? <String, dynamic>{});

  // Helper method to wrap dynamic values into MagicMap or List
  static dynamic _wrap(dynamic value) {
    if (value is Map) {
      return _MagicMapImpl(value.cast<String, dynamic>());
    } else if (value is List) {
      return value.map(_wrap).toList();
    }
    return value; // Return primitive values directly
  }

  // Helper method to unwrap MagicMap or List into raw values
  static dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  // Getter to return the raw unwrapped data
  dynamic get raw => _unwrap(_data);

  // Method to set a value at a specific path (dot notation)
  void set(String path, dynamic value) {
    final segments = path.split('.');
    dynamic current = _data;

    // Ensure the root data is a Map (or _MagicMapImpl)
    if (current is! _MagicMapImpl) {
      throw MagicMapException("Root must be a Map for path operations", path);
    }

    current = current._map;

    // Traverse through the segments and set the value
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (i == segments.length - 1) {
        current[segment] = _wrap(value); // Set the final value
      } else {
        // Ensure that intermediate segments are Maps
        if (current[segment] == null ||
            current[segment] is! Map<String, dynamic>) {
          current[segment] = <String, dynamic>{};
        }
        current = current[segment]; // Continue traversing
      }
    }
  }

  // Method to get the value at a specific path with a default fallback
  dynamic getPath(String path, [dynamic defaultValue]) {
    try {
      final segments = path.split('.');
      dynamic current = _data;

      // Traverse through each segment of the path
      for (final segment in segments) {
        if (current is _MagicMapImpl) {
          current = current[segment];
        } else if (current is Map) {
          current = current[segment];
        } else {
          return defaultValue; // Return default value if path doesn't exist
        }

        if (current == null) return defaultValue;
      }
      return current; // Return the value if found
    } catch (_) {
      return defaultValue; // Return default in case of any error
    }
  }

  // Method to retrieve values matching a glob pattern (e.g., "*")
  List<dynamic> getWithGlob(String pattern) {
    final results = <dynamic>[];
    _globSearch(_data, pattern.split('.'), 0, results);
    return results;
  }

  // Recursive helper method to perform glob search
  void _globSearch(
    dynamic current,
    List<String> pattern,
    int depth,
    List<dynamic> results,
  ) {
    if (depth >= pattern.length) {
      results.add(current); // If pattern is fully matched, add to results
      return;
    }

    final segment = pattern[depth];

    if (current is _MagicMapImpl) {
      current = current._map;
    }

    if (current is Map) {
      if (segment == '*') {
        // If the segment is "*", search all values at this depth
        for (final value in current.values) {
          _globSearch(value, pattern, depth + 1, results);
        }
      } else if (current.containsKey(segment)) {
        // If the segment matches a key, recurse on it
        _globSearch(current[segment], pattern, depth + 1, results);
      }
    } else if (current is List) {
      if (segment == '*') {
        // If the segment is "*", search all items in the list
        for (final item in current) {
          _globSearch(item, pattern, depth + 1, results);
        }
      } else if (int.tryParse(segment) != null &&
          int.parse(segment) < current.length) {
        // If it's an index, recurse on the item at that index
        _globSearch(current[int.parse(segment)], pattern, depth + 1, results);
      }
    }
  }

  // Method to perform immutable updates by deep cloning the data
  MagicMap setImmutable(String path, dynamic value) {
    final newData = _deepClone(_data); // Create a deep copy of the data
    final tempMap = MagicMap(newData);
    tempMap.set(path, value); // Set the new value in the cloned data
    return tempMap;
  }

  // Helper method to deep clone the data recursively
  dynamic _deepClone(dynamic value) {
    if (value is _MagicMapImpl) {
      final newMap = <String, dynamic>{};
      value._map.forEach((key, val) {
        newMap[key] = _deepClone(val); // Recursively clone each value
      });
      return _MagicMapImpl(newMap);
    } else if (value is List) {
      return value.map(_deepClone).toList(); // Clone each list item
    } else if (value is Map) {
      final newMap = <String, dynamic>{};
      value.forEach((key, val) {
        newMap[key.toString()] = _deepClone(val); // Clone the key-value pair
      });
      return _MagicMapImpl(newMap);
    }
    return value; // Return primitive values as-is
  }

  // Method to convert the MagicMap to a JSON string
  String toJsonString([Object? Function(dynamic)? replacer, int indent = 0]) {
    final encoder =
        indent > 0
            ? JsonEncoder.withIndent(' ' * indent, replacer)
            : JsonEncoder(replacer);
    return encoder.convert(raw); // Convert the raw data to JSON
  }

  // Static method to create a MagicMap from a JSON string
  static MagicMap fromJsonString(String jsonString) {
    return MagicMap(jsonDecode(jsonString)); // Decode and wrap the JSON
  }

  // Operator override to get a value using the bracket notation (e.g., magicMap['key'])
  dynamic operator [](String key) {
    if (_data is _MagicMapImpl) {
      return _data[key]; // Access value from _MagicMapImpl
    }
    return null; // Return null if not a valid map
  }

  // Operator override to set a value using bracket notation (e.g., magicMap['key'] = value)
  void operator []=(String key, dynamic value) {
    if (_data is _MagicMapImpl) {
      _data[key] = value; // Set value in _MagicMapImpl
    } else {
      throw MagicMapException("Cannot set value on non-map root");
    }
  }

  // Fallback for undefined method calls (e.g., dynamic field access like magicMap.someKey)
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = _symbolToString(invocation.memberName);
    if (invocation.isGetter) {
      return _data[name]; // Return value for getter
    }

    if (invocation.isSetter) {
      final key = name.replaceAll('=', '');
      _data[key] = invocation.positionalArguments.first; // Set value for setter
      return null;
    }

    return super.noSuchMethod(invocation); // Fallback to default behavior
  }

  // Helper to convert a symbol to string (used for dynamic field access)
  static String _symbolToString(Symbol symbol) {
    return symbol.toString().replaceAll('Symbol("', '').replaceAll('")', '');
  }

  // Override toString to provide a string representation of the MagicMap
  @override
  String toString() => 'MagicMap($_data)';
}

// Internal class to represent a wrapped Map with additional capabilities
class _MagicMapImpl {
  final Map<String, dynamic> _map;

  _MagicMapImpl(this._map);

  // Operator override to access values using bracket notation
  dynamic operator [](String key) => _wrap(_map[key]);

  // Operator override to set values using bracket notation
  void operator []=(String key, dynamic value) {
    _map[key] = _unwrap(value);
  }

  // Helper method to wrap dynamic values into _MagicMapImpl or List
  dynamic _wrap(dynamic value) {
    if (value is Map) return _MagicMapImpl(value.cast<String, dynamic>());
    if (value is List) return value.map(_wrap).toList();
    return value;
  }

  // Helper method to unwrap MagicMapImpl into raw data
  dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  // Fallback for undefined method calls
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = MagicMap._symbolToString(invocation.memberName);

    if (invocation.isGetter) {
      return _wrap(_map[name]);
    }

    if (invocation.isSetter) {
      final key = name.replaceAll('=', '');
      _map[key] = _unwrap(invocation.positionalArguments.first);
      return null;
    }

    return super.noSuchMethod(invocation);
  }

  // Override toString to represent the map's string
  @override
  String toString() => _map.toString();
}
