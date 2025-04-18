/// A wrapper that enables JavaScript-like dot-access on deeply nested
/// `Map<String, dynamic>` and `List` structures in Dart.
///
/// This is especially useful when working with dynamic or JSON data where
/// keys are not known at compile time. It allows accessing properties like:
///
/// ```dart
/// final data = MagicMap({
///   "user": {
///     "profile": {
///       "name": "Okolo",
///       "age": 24,
///     },
///   },
/// });
///
/// print(data.user.profile.name); // prints "Okolo"
/// print(data.user.profile.age);  // prints 24
/// print(data.user.profile.nonexistent); // returns null safely
///
class MagicMap {
  final dynamic _data;

  /// Constructs a [MagicMap] from any dynamic input.
  /// If the input is a [Map], it wraps it recursively.
  /// If it's a [List], each element is wrapped as well.
  MagicMap(dynamic data) : _data = _wrap(data);

  /// Recursively wraps Maps and Lists into MagicMap structures.
  static dynamic _wrap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _MagicMapImpl(value);
    } else if (value is List) {
      return value.map(_wrap).toList();
    }
    return value;
  }

  /// Returns the raw, unwrapped version of the original data.
  /// Useful for serialization or when passing data to other APIs.
  dynamic get raw => _unwrap(_data);

  /// Recursively unwraps any MagicMap structures into Maps or Lists.
  static dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  /// Delegates any undefined property/method access to the internal _data object.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _data.noSuchMethod(invocation);
  }
}

/// Private internal class that actually handles the dynamic access logic.
class _MagicMapImpl {
  final Map<String, dynamic> _map;

  _MagicMapImpl(this._map);

  /// Recursively wraps nested values.
  dynamic _wrap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _MagicMapImpl(value);
    } else if (value is List) {
      return value.map(_wrap).toList();
    }
    return value;
  }

  /// Recursively unwraps nested values into raw Dart types.
  dynamic _unwrap(dynamic value) {
    if (value is _MagicMapImpl) return value._map;
    if (value is List) return value.map(_unwrap).toList();
    return value;
  }

  /// Intercepts unknown getters and setters, enabling dot-access to Map keys.
  /// For getters, returns the wrapped value of the key (or null if not present).
  /// For setters, assigns a value to the map key.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = _symbolToString(invocation.memberName);

    if (invocation.isGetter) {
      if (!_map.containsKey(name)) return null;
      return _wrap(_map[name]);
    }

    if (invocation.isSetter) {
      final key = name.replaceFirst("=", "");
      _map[key] = _unwrap(invocation.positionalArguments.first);
      return null;
    }

    return super.noSuchMethod(invocation);
  }

  /// Converts a Dart [Symbol] to its string representation.
  String _symbolToString(Symbol symbol) {
    final str = symbol.toString(); // 'Symbol("name")'
    final match = RegExp('"(.*?)"').firstMatch(str);
    return match?.group(1) ?? '';
  }

  /// Converts this MagicMap to a standard [Map<String, dynamic>].
  Map<String, dynamic> toJson() => _map;
}
