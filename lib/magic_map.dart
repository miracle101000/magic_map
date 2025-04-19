import 'dart:convert';
import 'package:glob/glob.dart';

/// Custom exception for errors within the MagicMap class.
class MagicMapException implements Exception {
  final String message;
  MagicMapException(this.message);

  @override
  String toString() => 'MagicMapException: $message';
}

/// MagicMap provides advanced manipulation for deeply nested maps/lists.
/// It enables dot-path access, immutable updates, glob matching, and JSON handling.
class MagicMap {
  final dynamic _data;

  /// Constructs a MagicMap instance from any JSON-like structure (Map or List).
  MagicMap(dynamic data) : _data = _wrap(data);

  /// Wraps Map and List values recursively to support MagicMap features.
  static dynamic _wrap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _MagicMapImpl(value);
    } else if (value is List) {
      return value.map(_wrap).toList();
    }
    return value;
  }

  /// Unwraps internal structures back to raw Dart types (Map, List, primitive).
  static dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  /// Returns the raw structure as a Dart Map/List/primitive.
  dynamic get raw => _unwrap(_data);

  /// Sets a value at the specified dot-separated path (e.g., `user.profile.name`).
  /// Creates intermediate maps if needed.
  void set(String path, dynamic value) {
    final segments = path.split('.');
    dynamic current = raw;

    if (current is! Map<String, dynamic>) {
      throw MagicMapException("Root must be a Map for path operations");
    }

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (i == segments.length - 1) {
        current[segment] = value;
      } else {
        if (current[segment] is! Map<String, dynamic>) {
          current[segment] = <String, dynamic>{};
        }
        current = current[segment];
      }
    }
  }

  /// Gets a value at the specified dot-separated path.
  /// Throws a detailed error if the key is missing or the path is invalid.
  dynamic getPath(String path) {
    final segments = path.split('.');
    dynamic current = raw;
    final pathSegments = [];

    for (final segment in segments) {
      pathSegments.add(segment);
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) {
          throw MagicMapException(
            "Missing key '$segment' at path '${pathSegments.join('.')}'",
          );
        }
        current = current[segment];
      } else {
        throw MagicMapException(
          "Path segment '${pathSegments.join('.')}' is not a Map",
        );
      }
    }
    return current;
  }

  /// Finds values using a bash-style glob pattern across all nested paths.
  /// Example: `user.*.name` or `settings.**.enabled`
  List<dynamic> getWithGlob(String pattern) {
    final glob = Glob(pattern);
    final results = [];
    _collectMatches(raw, [], glob, results);
    return results.map(_wrap).toList();
  }

  /// Helper method to recursively traverse the structure and collect glob matches.
  void _collectMatches(
    dynamic current,
    List<String> path,
    Glob glob,
    List<dynamic> results,
  ) {
    if (current is Map<String, dynamic>) {
      current.forEach((key, value) {
        final newPath = List.of(path)..add(key);
        if (glob.matches(newPath.join('.'))) {
          results.add(value);
        }
        _collectMatches(value, newPath, glob, results);
      });
    } else if (current is List) {
      for (int i = 0; i < current.length; i++) {
        final newPath = List.of(path)..add('[$i]');
        _collectMatches(current[i], newPath, glob, results);
      }
    }
  }

  /// Returns a new MagicMap with the value updated at [path], leaving the original unmodified.
  MagicMap setImmutable(String path, dynamic value) {
    final cloned = jsonDecode(jsonEncode(raw)); // Deep clone
    final temp = MagicMap(cloned);
    temp.set(path, value);
    return temp;
  }

  /// Creates a MagicMap from a JSON string.
  factory MagicMap.fromJsonString(String jsonString) {
    return MagicMap(jsonDecode(jsonString));
  }

  /// Serializes the MagicMap to a JSON string.
  String toJsonString() {
    return jsonEncode(raw);
  }

  /// Forwards method/property access to the wrapped structure.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _data.noSuchMethod(invocation);
  }
}

/// Private class that supports dynamic property access to a wrapped Map.
class _MagicMapImpl {
  final Map<String, dynamic> _map;

  _MagicMapImpl(this._map);

  /// Recursively wraps nested values.
  dynamic _wrap(dynamic value) {
    if (value is Map<String, dynamic>) return _MagicMapImpl(value);
    if (value is List) return value.map(_wrap).toList();
    return value;
  }

  /// Recursively unwraps nested values back to native Dart types.
  dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  /// Supports dot notation access and assignment using Dart’s dynamic features.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = _symbolToString(invocation.memberName);

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

  /// Converts Dart Symbol to plain String.
  String _symbolToString(Symbol symbol) {
    return symbol.toString().split('"')[1];
  }
}
