/// JavaScript-style dot access for deeply nested maps and lists.
///
/// The two public types are [MagicMap] (wraps a `Map<String, dynamic>`) and
/// [MagicList] (wraps a `List<dynamic>`). Both are *views* over plain Dart
/// collections: reading a nested map or list returns another view over the
/// same underlying data, and every write goes straight through to it.
///
/// ```dart
/// final data = MagicMap({'user': {'name': 'Alice', 'tags': ['a', 'b']}});
/// final d = data as dynamic;
/// print(d.user.name);          // Alice
/// d.user.tags[1] = 'z';        // writes through
/// print(data.getPath('user.tags.1')); // z
/// ```
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

/// Thrown by [MagicMap] and [MagicList] for invalid input or operations.
class MagicMapException implements Exception {
  /// Human readable description of the problem.
  final String message;

  /// The path being operated on when the problem occurred, if any.
  final String? path;

  /// Creates an exception with a [message] and an optional [path].
  const MagicMapException(this.message, [this.path]);

  @override
  String toString() =>
      'MagicMapException: $message${path != null ? ' (at path: $path)' : ''}';
}

/// Signature of the `replacer` callback accepted by
/// [MagicMap.toJsonString] and [MagicList.toJsonString].
///
/// It mirrors the replacer of JavaScript's `JSON.stringify`: it is invoked
/// top-down for the root (with key `''`), then for every map entry (with the
/// entry key) and every list element (with the index as a string). Whatever it
/// returns is what gets encoded. Return [MagicMap.omit] to drop a map entry;
/// an omitted list element is encoded as `null`.
typedef JsonReplacer = Object? Function(String key, Object? value);

class _Omit {
  const _Omit();

  @override
  String toString() => 'MagicMap.omit';
}

class _Missing {
  const _Missing();
}

/// Sentinel returned by the raw lookups when a path does not exist.
const _missing = _Missing();

final RegExp _digitsRe = RegExp(r'^\d+$');
final RegExp _symbolRe = RegExp(r'^Symbol\("(.*)"\)$');

// ---------------------------------------------------------------------------
// Path handling
// ---------------------------------------------------------------------------

/// Splits a path such as `user.tags[0].name` into segments.
///
/// String segments are map keys, `int` segments are list indices, and the
/// string `'*'` may come from a `[*]` wildcard. A dot or `[` can be escaped
/// with a backslash to use it literally inside a key. Never throws: anything
/// that is not a well-formed `[digits]` or `[*]` is treated as literal text.
List<Object> _parsePath(String path) {
  final segments = <Object>[];
  final buffer = StringBuffer();
  var pending = false;
  final n = path.length;
  var i = 0;
  while (i < n) {
    final c = path[i];
    if (c == r'\' && i + 1 < n) {
      buffer.write(path[i + 1]);
      pending = true;
      i += 2;
      continue;
    }
    if (c == '.') {
      if (pending) {
        segments.add(buffer.toString());
        buffer.clear();
      }
      pending = true;
      i++;
      continue;
    }
    if (c == '[') {
      final close = path.indexOf(']', i);
      if (close > i + 1) {
        final inner = path.substring(i + 1, close);
        final index = _digitsRe.hasMatch(inner) ? int.tryParse(inner) : null;
        if (index != null || inner == '*') {
          if (buffer.isNotEmpty) {
            segments.add(buffer.toString());
            buffer.clear();
          }
          pending = false;
          segments.add(index ?? '*');
          i = close + 1;
          continue;
        }
      }
    }
    buffer.write(c);
    pending = true;
    i++;
  }
  if (pending) segments.add(buffer.toString());
  return segments;
}

/// Renders [segments] back into path syntax for error messages.
String _formatPath(List<Object> segments) {
  final sb = StringBuffer();
  for (final seg in segments) {
    if (seg is int) {
      sb.write('[$seg]');
    } else {
      final key = (seg as String)
          .replaceAll(r'\', r'\\')
          .replaceAll('.', r'\.')
          .replaceAll('[', r'\[');
      if (sb.isNotEmpty) sb.write('.');
      sb.write(key);
    }
  }
  return sb.toString();
}

/// The map key a segment denotes (`[3]` on a map means the key `'3'`).
String _asKey(Object segment) => segment is int ? '$segment' : segment as String;

/// The list index a segment denotes, or `null` if it is not a plain integer.
int? _asIndex(Object segment) {
  if (segment is int) return segment;
  final s = segment as String;
  return _digitsRe.hasMatch(s) ? int.tryParse(s) : null;
}

bool _isContainer(Object? value) => value is Map || value is List;

Object _emptyContainerFor(Object nextSegment) =>
    _asIndex(nextSegment) != null ? <dynamic>[] : <String, dynamic>{};

/// Returns the raw value at [segments] under [root], or [_missing].
Object? _rawGet(Object? root, List<Object> segments) {
  Object? current = root;
  for (final seg in segments) {
    if (current is Map) {
      final key = _asKey(seg);
      if (!current.containsKey(key)) return _missing;
      current = current[key];
    } else if (current is List) {
      final index = _asIndex(seg);
      if (index == null || index < 0 || index >= current.length) {
        return _missing;
      }
      current = current[index];
    } else {
      return _missing;
    }
  }
  return current;
}

/// Writes an already-normalized [value] at [segments] under [root], creating
/// intermediate maps and lists as needed.
void _rawSet(Object root, List<Object> segments, Object? value, String path) {
  if (segments.isEmpty) {
    throw MagicMapException('Path must not be empty', path);
  }
  Object current = root;
  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    final isLast = i == segments.length - 1;
    String here() => _formatPath(segments.sublist(0, i + 1));

    if (current is Map) {
      final key = _asKey(seg);
      if (isLast) {
        current[key] = value;
        return;
      }
      Object? next = current[key];
      if (next == null) {
        next = _emptyContainerFor(segments[i + 1]);
        current[key] = next;
      } else if (!_isContainer(next)) {
        throw MagicMapException(
          'Cannot descend into a ${next.runtimeType} at "${here()}"; '
          'expected a Map or List',
          path,
        );
      }
      current = next;
    } else if (current is List) {
      final index = _asIndex(seg);
      if (index == null) {
        throw MagicMapException(
          'Expected a list index at "${here()}" but got "$seg"',
          path,
        );
      }
      if (index < 0 || index > current.length) {
        throw MagicMapException(
          'Index $index is out of range for a list of length '
          '${current.length} at "${here()}"',
          path,
        );
      }
      if (isLast) {
        if (index == current.length) {
          current.add(value);
        } else {
          current[index] = value;
        }
        return;
      }
      Object? next = index < current.length ? current[index] : null;
      if (next == null) {
        next = _emptyContainerFor(segments[i + 1]);
        if (index == current.length) {
          current.add(next);
        } else {
          current[index] = next;
        }
      } else if (!_isContainer(next)) {
        throw MagicMapException(
          'Cannot descend into a ${next.runtimeType} at "${here()}"; '
          'expected a Map or List',
          path,
        );
      }
      current = next;
    } else {
      throw MagicMapException(
        'Cannot descend into a ${current.runtimeType} at "${here()}"',
        path,
      );
    }
  }
}

/// Removes the value at [segments] under [root]. Returns the removed raw
/// value, or [_missing] if nothing was there.
Object? _rawRemove(Object root, List<Object> segments, String path) {
  if (segments.isEmpty) {
    throw MagicMapException('Path must not be empty', path);
  }
  final parent = _rawGet(root, segments.sublist(0, segments.length - 1));
  final last = segments.last;
  if (parent is Map) {
    final key = _asKey(last);
    if (!parent.containsKey(key)) return _missing;
    return parent.remove(key);
  }
  if (parent is List) {
    final index = _asIndex(last);
    if (index == null || index < 0 || index >= parent.length) return _missing;
    return parent.removeAt(index);
  }
  return _missing;
}

// ---------------------------------------------------------------------------
// Wrapping / normalizing
// ---------------------------------------------------------------------------

/// Deep-copies [value] into plain `Map<String, dynamic>` / `List<dynamic>`
/// containers so that the stored tree never contains views or narrowly typed
/// collections (which would make later writes throw type errors).
///
/// Views ([MagicMap] / [MagicList]) are unwrapped first. Map keys are
/// converted with `toString()`. Any other value is stored as-is.
Object? _normalize(Object? value, [Set<Object>? ancestors]) {
  Object? source = value;
  if (source is MagicMap) {
    source = source._map;
  } else if (source is MagicList) {
    source = source._list;
  }
  if (source is Map) {
    final seen = ancestors ?? Set<Object>.identity();
    if (!seen.add(source)) {
      throw const MagicMapException('Cannot store a cyclic structure');
    }
    final out = <String, dynamic>{};
    source.forEach((key, val) {
      out['$key'] = _normalize(val, seen);
    });
    seen.remove(source);
    return out;
  }
  if (source is List) {
    final seen = ancestors ?? Set<Object>.identity();
    if (!seen.add(source)) {
      throw const MagicMapException('Cannot store a cyclic structure');
    }
    final out = <dynamic>[for (final item in source) _normalize(item, seen)];
    seen.remove(source);
    return out;
  }
  return source;
}

/// Wraps a raw value for hand-out: maps become [MagicMap] views, lists become
/// [MagicList] views, everything else is returned unchanged.
dynamic _wrap(Object? value) {
  if (value is Map) {
    return MagicMap._view(
      value is Map<String, dynamic> ? value : value.cast<String, dynamic>(),
    );
  }
  if (value is List) return MagicList._view(value);
  return value;
}

// ---------------------------------------------------------------------------
// Glob matching
// ---------------------------------------------------------------------------

bool _hasWildcard(String s) => s.contains('*') || s.contains('?');

RegExp _globToRegExp(String glob) {
  final sb = StringBuffer('^');
  for (final rune in glob.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '*') {
      sb.write('.*');
    } else if (ch == '?') {
      sb.write('.');
    } else {
      sb.write(RegExp.escape(ch));
    }
  }
  sb.write(r'$');
  return RegExp(sb.toString(), dotAll: true);
}

/// Pre-compiles a parsed glob pattern: wildcard segments other than the
/// special `*` and `**` become [RegExp]s.
List<Object> _compileGlob(List<Object> segments) => [
  for (final seg in segments)
    if (seg is String && seg != '*' && seg != '**' && _hasWildcard(seg))
      _globToRegExp(seg)
    else
      seg,
];

void _glob(Object? node, List<Object> pattern, int depth, List<dynamic> out) {
  if (depth == pattern.length) {
    out.add(_wrap(node));
    return;
  }
  final seg = pattern[depth];

  if (seg == '**') {
    // Match zero levels...
    _glob(node, pattern, depth + 1, out);
    // ...and then one more level, staying on the `**` segment.
    if (node is Map) {
      for (final value in node.values) {
        _glob(value, pattern, depth, out);
      }
    } else if (node is List) {
      for (final item in node) {
        _glob(item, pattern, depth, out);
      }
    }
    return;
  }

  if (node is Map) {
    if (seg == '*') {
      for (final value in node.values) {
        _glob(value, pattern, depth + 1, out);
      }
    } else if (seg is RegExp) {
      for (final entry in node.entries) {
        if (seg.hasMatch('${entry.key}')) {
          _glob(entry.value, pattern, depth + 1, out);
        }
      }
    } else {
      final key = _asKey(seg);
      if (node.containsKey(key)) {
        _glob(node[key], pattern, depth + 1, out);
      }
    }
  } else if (node is List) {
    if (seg == '*') {
      for (final item in node) {
        _glob(item, pattern, depth + 1, out);
      }
    } else if (seg is RegExp) {
      for (var i = 0; i < node.length; i++) {
        if (seg.hasMatch('$i')) _glob(node[i], pattern, depth + 1, out);
      }
    } else {
      final index = _asIndex(seg);
      if (index != null && index >= 0 && index < node.length) {
        _glob(node[index], pattern, depth + 1, out);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// JSON
// ---------------------------------------------------------------------------

Object? _applyReplacer(String key, Object? value, JsonReplacer replacer) {
  Object? replaced = replacer(key, value);
  if (identical(replaced, MagicMap.omit)) return MagicMap.omit;
  if (replaced is MagicMap) {
    replaced = replaced._map;
  } else if (replaced is MagicList) {
    replaced = replaced._list;
  }
  if (replaced is Map) {
    final out = <String, Object?>{};
    replaced.forEach((k, v) {
      final r = _applyReplacer('$k', v, replacer);
      if (!identical(r, MagicMap.omit)) out['$k'] = r;
    });
    return out;
  }
  if (replaced is List) {
    return <Object?>[
      for (var i = 0; i < replaced.length; i++)
        switch (_applyReplacer('$i', replaced[i], replacer)) {
          final r when identical(r, MagicMap.omit) => null,
          final r => r,
        },
    ];
  }
  return replaced;
}

String _encodeJson(
  Object? root,
  int indent,
  JsonReplacer? replacer,
  Object? Function(Object? nonEncodable)? toEncodable,
) {
  var data = replacer == null ? root : _applyReplacer('', root, replacer);
  if (identical(data, MagicMap.omit)) data = null;
  final encoder =
      indent > 0
          ? JsonEncoder.withIndent(' ' * indent, toEncodable)
          : JsonEncoder(toEncodable);
  return encoder.convert(data);
}

Object? _decodeJson(String jsonString) {
  try {
    return jsonDecode(jsonString);
  } on FormatException catch (e) {
    throw MagicMapException('Invalid JSON: ${e.message}');
  }
}

// ---------------------------------------------------------------------------
// Shared path API
// ---------------------------------------------------------------------------

/// Path-based operations shared by [MagicMap] and [MagicList].
mixin _PathOps {
  /// The underlying container (a `Map<String, dynamic>` or `List<dynamic>`).
  Object get _root;

  /// Returns the value at [path], or [defaultValue] if the path does not
  /// exist or holds `null`.
  ///
  /// Paths use dot notation with optional bracket indices:
  /// `user.tags.0`, `user.tags[0]` and `users[1].name` are all valid. A dot
  /// inside a key can be escaped as `\.`. Maps and lists come back as
  /// [MagicMap] / [MagicList] views over the same data. This method never
  /// throws; an empty path returns a view of the whole container.
  dynamic getPath(String path, [dynamic defaultValue]) {
    final found = _rawGet(_root, _parsePath(path));
    if (identical(found, _missing) || found == null) return defaultValue;
    return _wrap(found);
  }

  /// Whether [path] exists, even if the value stored there is `null`.
  bool hasPath(String path) =>
      !identical(_rawGet(_root, _parsePath(path)), _missing);

  /// Stores [value] at [path], creating intermediate containers as needed.
  ///
  /// A missing intermediate becomes a list when the following segment is an
  /// integer and a map otherwise. On a list, the index may be at most the
  /// current length (which appends). [value] is deep-copied into plain
  /// collections, so later changes to the original object do not affect the
  /// stored data.
  ///
  /// Throws [MagicMapException] for an empty path, a list index that is out
  /// of range or not an integer, or an attempt to descend into a value that is
  /// neither a map nor a list. Existing data is never silently replaced by an
  /// intermediate container.
  void set(String path, dynamic value) =>
      _rawSet(_root, _parsePath(path), _normalize(value), path);

  /// Removes the value at [path] and returns it (wrapped), or `null` if the
  /// path did not exist. Throws [MagicMapException] for an empty path.
  dynamic removePath(String path) {
    final removed = _rawRemove(_root, _parsePath(path), path);
    return identical(removed, _missing) ? null : _wrap(removed);
  }

  /// Returns every value whose path matches the glob [pattern].
  ///
  /// Within a segment `*` matches any run of characters and `?` a single
  /// character. A whole segment of `*` (or `[*]`) matches every key or index,
  /// and `**` matches any number of levels, including none. Results are in
  /// traversal order and wrapped like [getPath].
  List<dynamic> getWithGlob(String pattern) {
    final results = <dynamic>[];
    _glob(_root, _compileGlob(_parsePath(pattern)), 0, results);
    return results;
  }

  /// Encodes the data as JSON.
  ///
  /// [indent] greater than zero pretty-prints with that many spaces.
  /// [replacer] transforms or omits values before encoding (see
  /// [JsonReplacer]). [toEncodable] is passed to [JsonEncoder] and is called
  /// for values that are not natively encodable, such as `DateTime`.
  String toJsonString({
    int indent = 0,
    JsonReplacer? replacer,
    Object? Function(Object? nonEncodable)? toEncodable,
  }) => _encodeJson(_root, indent, replacer, toEncodable);
}

// ---------------------------------------------------------------------------
// MagicMap
// ---------------------------------------------------------------------------

/// A view over a `Map<String, dynamic>` with JavaScript-style member access.
///
/// Cast a [MagicMap] to `dynamic` to read and write keys as if they were
/// fields. Nested maps and lists are returned as [MagicMap] and [MagicList]
/// views over the same underlying data, so writes at any depth are visible
/// through every view and through [raw].
///
/// ```dart
/// final map = MagicMap({'user': {'name': 'Alice'}});
/// final d = map as dynamic;
/// d.user.name = 'Bob';
/// d.user.tags = ['a'];
/// d.user.tags.add('b');
/// print(map.raw); // {user: {name: Bob, tags: [a, b]}}
/// ```
///
/// The constructor deep-copies its input into fresh `Map<String, dynamic>`
/// and `List<dynamic>` containers. Keys are converted to strings. Because of
/// this, the original map passed in is never modified and writes never fail
/// with type errors, regardless of how the input literal was typed.
///
/// Member names that exist on this class (`raw`, `set`, `getPath`, and so
/// on) cannot be reached with dot access; use `map['key']` or
/// [getPath] for those keys.
class MagicMap with _PathOps {
  final Map<String, dynamic> _map;

  MagicMap._view(this._map);

  /// Creates a [MagicMap] holding a deep copy of [data].
  ///
  /// [data] may be `null` (an empty map), any [Map], or another [MagicMap].
  /// Throws [MagicMapException] for anything else or for cyclic input.
  factory MagicMap([Object? data]) {
    if (data == null) return MagicMap._view(<String, dynamic>{});
    if (data is MagicMap || data is Map) {
      return MagicMap._view(_normalize(data) as Map<String, dynamic>);
    }
    throw MagicMapException(
      'MagicMap requires a Map but got ${data.runtimeType}',
    );
  }

  /// Decodes [jsonString], which must contain a JSON object at its root.
  ///
  /// Throws [MagicMapException] if the text is not valid JSON or the root is
  /// not an object.
  factory MagicMap.fromJsonString(String jsonString) {
    final decoded = _decodeJson(jsonString);
    if (decoded is Map) return MagicMap(decoded);
    throw MagicMapException(
      'Expected a JSON object at the root but got '
      '${decoded == null ? 'null' : decoded.runtimeType}',
    );
  }

  /// Sentinel a [JsonReplacer] returns to drop an entry from the output.
  static const Object omit = _Omit();

  @override
  Object get _root => _map;

  /// The underlying map. It is live: modifying it modifies this [MagicMap].
  ///
  /// Keep any values you insert to plain `Map<String, dynamic>` and
  /// `List<dynamic>` containers so that later path operations keep working.
  Map<String, dynamic> get raw => _map;

  /// Returns [raw], which lets `jsonEncode` accept a [MagicMap] directly.
  Map<String, dynamic> toJson() => _map;

  /// Returns an independent deep copy.
  MagicMap clone() => MagicMap(_map);

  /// Returns a deep copy with [value] stored at [path]; this map is unchanged.
  MagicMap setImmutable(String path, dynamic value) =>
      clone()..set(path, value);

  /// The value stored under [key] (not a path), wrapped like [getPath].
  dynamic operator [](String key) => _wrap(_map[key]);

  /// Stores [value] under [key] (not a path).
  void operator []=(String key, dynamic value) {
    _map[key] = _normalize(value);
  }

  /// Handles `map.someKey` reads and `map.someKey = value` writes when the
  /// instance is used through a `dynamic` reference.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = _symbolName(invocation.memberName);
    if (invocation.isGetter) return _wrap(_map[name]);
    if (invocation.isSetter) {
      final key = name.endsWith('=') ? name.substring(0, name.length - 1) : name;
      _map[key] = _normalize(invocation.positionalArguments.first);
      return null;
    }
    return super.noSuchMethod(invocation);
  }

  static String _symbolName(Symbol symbol) {
    final text = symbol.toString();
    return _symbolRe.firstMatch(text)?.group(1) ?? text;
  }

  /// Two views are equal when they wrap the same underlying map.
  @override
  bool operator ==(Object other) =>
      other is MagicMap && identical(other._map, _map);

  @override
  int get hashCode => identityHashCode(_map);

  @override
  String toString() => _map.toString();
}

// ---------------------------------------------------------------------------
// MagicList
// ---------------------------------------------------------------------------

/// A [List] view over a `List<dynamic>` whose elements are wrapped on read.
///
/// Instances are real lists, so iteration, `length`, `add`, `[]=`, spreads
/// and the rest of the [List] API all work and write through to the
/// underlying data. Elements that are maps or lists come back as [MagicMap]
/// and [MagicList] views.
class MagicList extends ListBase<dynamic> with _PathOps {
  final List<dynamic> _list;

  MagicList._view(this._list);

  /// Creates a [MagicList] holding a deep copy of [items].
  ///
  /// Throws [MagicMapException] for cyclic input.
  factory MagicList([Iterable<Object?>? items]) {
    final source =
        items == null
            ? <dynamic>[]
            : items is MagicList
            ? items._list
            : items.toList();
    return MagicList._view(_normalize(source) as List<dynamic>);
  }

  /// Decodes [jsonString], which must contain a JSON array at its root.
  ///
  /// Throws [MagicMapException] if the text is not valid JSON or the root is
  /// not an array.
  factory MagicList.fromJsonString(String jsonString) {
    final decoded = _decodeJson(jsonString);
    if (decoded is List) return MagicList(decoded);
    throw MagicMapException(
      'Expected a JSON array at the root but got '
      '${decoded == null ? 'null' : decoded.runtimeType}',
    );
  }

  @override
  Object get _root => _list;

  /// The underlying list. It is live: modifying it modifies this [MagicList].
  List<dynamic> get raw => _list;

  /// Returns [raw], which lets `jsonEncode` accept a [MagicList] directly.
  List<dynamic> toJson() => _list;

  /// Returns an independent deep copy.
  MagicList clone() => MagicList(_list);

  /// Returns a deep copy with [value] stored at [path]; this list is
  /// unchanged.
  MagicList setImmutable(String path, dynamic value) =>
      clone()..set(path, value);

  @override
  int get length => _list.length;

  @override
  set length(int newLength) {
    _list.length = newLength;
  }

  @override
  dynamic operator [](int index) => _wrap(_list[index]);

  @override
  void operator []=(int index, dynamic value) {
    _list[index] = _normalize(value);
  }

  @override
  void add(dynamic element) => _list.add(_normalize(element));

  @override
  void addAll(Iterable<dynamic> iterable) {
    final items = [for (final item in iterable) _normalize(item)];
    _list.addAll(items);
  }

  @override
  void insert(int index, dynamic element) =>
      _list.insert(index, _normalize(element));

  @override
  void insertAll(int index, Iterable<dynamic> iterable) {
    final items = [for (final item in iterable) _normalize(item)];
    _list.insertAll(index, items);
  }

  @override
  dynamic removeAt(int index) => _wrap(_list.removeAt(index));

  @override
  dynamic removeLast() => _wrap(_list.removeLast());

  @override
  void clear() => _list.clear();

  @override
  void sort([int Function(dynamic a, dynamic b)? compare]) {
    if (compare == null) {
      _list.sort();
    } else {
      _list.sort((a, b) => compare(_wrap(a), _wrap(b)));
    }
  }

  @override
  void shuffle([Random? random]) => _list.shuffle(random);

  /// Two views are equal when they wrap the same underlying list.
  @override
  bool operator ==(Object other) =>
      other is MagicList && identical(other._list, _list);

  @override
  int get hashCode => identityHashCode(_list);
}
