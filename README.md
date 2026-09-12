# magic_map

Safe, path-based, typed access to nested Dart maps and lists. Read deep
values with a default or a required type, write deep values without building
the intermediate containers yourself, query with glob patterns, make
immutable updates, and round-trip JSON. Think lodash `get` / `set` for Dart,
with the type checks you would otherwise write by hand.

Pure Dart with no dependencies, so it works in Flutter, server, and CLI
projects alike.

```dart
final config = MagicMap.fromJsonString(jsonText);

final port = config.getAs<int>('server.port') ?? 8080;          // typed, never throws
final host = config.requireAs<String>('server.host');           // throws, naming the path
final tags = config.getListOf<String>('user.tags') ?? const []; // a real List<String>

config.getPath('users[0].email', 'unknown');      // untyped, with a default
config.set('server.tls.cert', '/etc/cert.pem');   // creates 'tls' on the way
config.set('users[2].name', 'Carol');             // appends a new user map
config.getWithGlob('features.*.enabled');         // every feature's flag

final next = config.setImmutable('server.port', 9090); // config unchanged
print(next.toJsonString(indent: 2));
```

## When to use it

`magic_map` is for data whose shape you do not control or cannot model up
front: remote config, feature flags, third-party API responses, Firestore
documents, JSON you are still exploring. When the schema is fixed and yours,
generated models with `json_serializable` or `freezed` give you more safety
and are the idiomatic choice. The two combine well: use `magic_map` to reach
into the loosely typed corners of an otherwise typed model.

## How it works

`MagicMap` and `MagicList` are *views* over ordinary `Map<String, dynamic>`
and `List<dynamic>` objects.

- The constructor **deep-copies** its input into plain containers and converts
  keys to strings. The map you pass in is never modified, and writes never
  fail with type errors no matter how narrowly the original literal was typed.
  For large data you already own, `MagicMap.view()` skips the copy; see
  [Views without copying](#views-without-copying).
- Reading a nested map or list returns another view over the **same** data,
  so every method below works at any depth.
- Every write goes straight to the underlying collection. `raw` returns that
  collection at any level.
- Values you assign are deep-copied too, so later changes to the original
  object do not leak into the map.

## Paths

Paths use dot notation with optional bracket indices. `user.tags.0`,
`user.tags[0]` and `users[1].name` are all valid and equivalent. Escape a
literal dot or bracket inside a key with a backslash: `r'a\.b'`. On a map, a
numeric segment is a key; on a list it is an index.

### `getPath(String path, [dynamic defaultValue])`

Returns the value at `path`, or `defaultValue` when the path does not exist
or holds `null`. Maps and lists come back as `MagicMap` / `MagicList` views.
Never throws.

```dart
map.getPath('user.profile.name');            // Alice
map.getPath('user.hobbies[1]');              // traveling
map.getPath('user.contact.email', 'N/A');    // N/A
map.getPath('user.profile').set('age', 31);  // views are writable
```

### `hasPath(String path)`

`true` when the path exists, even if its value is `null`.

### `set(String path, dynamic value)`

Stores `value`, creating intermediate containers as needed. A missing
intermediate becomes a list when the next segment is an integer, otherwise a
map. On a list, an index equal to the current length appends.

```dart
map.set('user.profile.age', 31);
map.set('user.contact.email', 'alice@example.com'); // creates 'contact'
map.set('user.hobbies.0', 'coding');                // replaces index 0
map.set('user.hobbies.2', 'chess');                 // appends
map.set('user.friends[0].name', 'Bob');             // creates a list of maps
```

It throws `MagicMapException` instead of corrupting data when:

- the path is empty,
- a list index is out of range or not an integer,
- the path tries to descend into a scalar (for example `user.name.first`
  when `user.name` is a `String`).

### `removePath(String path)`

Removes the key or list item at `path` and returns it, or `null` if nothing
was there.

### `getWithGlob(String pattern)`

Returns every value whose path matches the pattern, in traversal order.

| Syntax           | Meaning                                  |
| ---------------- | ---------------------------------------- |
| `*` (segment)    | any key or index at that level           |
| `[*]`            | same as `*`, for list-style paths        |
| `**`             | any number of levels, including none     |
| `*` in a segment | any run of characters (`hob*`)           |
| `?` in a segment | one character (`s?les`)                  |

```dart
map.getWithGlob('user.*.name');                      // [Alice]
map.getWithGlob('user.hobbies.*');                   // [reading, traveling]
map.getWithGlob('company.departments.*.manager');    // [Bob, Carol]
map.getWithGlob('items[*].id');                      // [1, 2]
map.getWithGlob('**.manager');                       // any depth
```

### `setImmutable(String path, dynamic value)` and `clone()`

`clone()` returns an independent deep copy. `setImmutable` is
`clone()..set(path, value)`: the original is untouched and the copy is
returned, so calls chain.

```dart
final updated = map
    .setImmutable('user.profile.name', 'Alicia')
    .setImmutable('user.profile.age', 32);
```

## Typed access

`getPath` returns `dynamic`. The typed accessors check the type for you and
rebuild lists and maps with the element type you ask for. All four take the
same path syntax and are available on nested views.

| Method                 | Returns           | When missing or wrong type                                   |
| ---------------------- | ----------------- | ------------------------------------------------------------ |
| `getAs<T>(path)`       | `T?`              | `null`                                                       |
| `requireAs<T>(path)`   | `T`               | throws `MagicMapException` naming the path and actual type   |
| `getListOf<T>(path)`   | `List<T>?`        | `null`, or drop bad elements with `skipInvalid: true`        |
| `getMapOf<V>(path)`    | `Map<String, V>?` | same as `getListOf`                                          |

```dart
final port   = config.getAs<int>('server.port') ?? 8080;
final host   = config.requireAs<String>('server.host');
final tags   = config.getListOf<String>('user.tags') ?? const [];
final limits = config.getMapOf<int>('limits') ?? const {};
final users  = config.getListOf<MagicMap>('users');   // writable views
final when   = config.getAs<DateTime>('created_at'); // from an ISO-8601 string
```

`getListOf` exists because `jsonDecode` produces `List<dynamic>`, so
`getPath('user.tags') as List<String>` throws at runtime even when every
element is a `String`. The list has to be rebuilt, and that belongs in the
library rather than at every call site. `getMapOf` solves the same problem
for `Map<String, int>` and friends.

Conversions applied by all four, on by default because JSON has one number
type and no date type:

- `int` to `double`
- a whole `double` to `int` (`3.0` becomes `3`; `3.5` and out-of-range values
  do not convert)
- an ISO-8601 `String` to `DateTime`
- `MagicMap` to `Map<String, dynamic>` when you ask for the plain map type.
  A `MagicList` already is a `List<dynamic>`, so `getAs<List>` returns the
  view; use `.raw` on it for the plain list.

Opt in with `parseStrings: true` for sources that hand you `"8080"` or
`"true"`; it adds `String` to `int`, `double`, `num` and `bool`. It is off
by default because silent coercion hides upstream bugs.

Use `requireAs` at trust boundaries, such as parsing a config file at
startup, and `getAs` when rendering data you do not control. A `null` value
satisfies `requireAs` only when `T` is nullable.

## JSON

```dart
map.toJsonString();                 // compact
map.toJsonString(indent: 2);        // pretty printed
jsonEncode(map);                    // also works: MagicMap/MagicList have toJson()

MagicMap.fromJsonString('{"a": 1}');    // root must be an object
MagicList.fromJsonString('[1, 2]');     // root must be an array
```

`toJsonString` accepts two optional callbacks:

- `replacer` mirrors the replacer of JavaScript's `JSON.stringify`. It is
  called top-down for every key/value pair (list indices are passed as
  strings, the root as `''`) and its return value is what gets encoded.
  Return `MagicMap.omit` to drop a map entry; an omitted list element encodes
  as `null`.
- `toEncodable` is forwarded to `JsonEncoder` for values that JSON cannot
  represent, such as `DateTime`.

```dart
map.toJsonString(
  replacer: (key, value) {
    if (key == 'password') return MagicMap.omit;
    return value is String ? value.toUpperCase() : value;
  },
  toEncodable: (v) => v is DateTime ? v.toIso8601String() : v,
);
```

Invalid JSON or a root of the wrong type throws `MagicMapException`.

## Lists

Nested lists come back as `MagicList`, a real `List` that writes through to
the underlying data. Iteration, `length`, `add`, `insert`, `removeAt`,
`sort`, spreads and the rest of the `List` API all work, and elements that
are maps or lists are returned as views.

```dart
final hobbies = map.getPath('user.hobbies'); // MagicList
hobbies.add('coding');
hobbies[0] = 'reading';
for (final h in hobbies) { /* ... */ }
```

`MagicList` has the same path and typed methods as `MagicMap`, so
`list.getPath('0.name')`, `list.getListOf<int>('')` and
`list.getWithGlob('*.id')` work.

## Views without copying

The default constructor copies its input, which is O(n) and is what makes
writes safe. When that cost matters, for example on a large decoded response
you already own, `MagicMap.view()` and `MagicList.view()` wrap the
collection directly. Writes go into your original object.

```dart
final data = jsonDecode(body) as Map<String, dynamic>;
final map = MagicMap.view(data); // no copy; map.raw is data
```

The requirement is that the collection, and every map and list nested in it,
is a `Map<String, dynamic>` or `List<dynamic>`. A narrowly typed container
such as `Map<String, String>` throws a `TypeError` when a value of another
type is written into it. The output of `jsonDecode` satisfies the
requirement; hand-written literals often do not.

## Bonus: dynamic dot access

If you cast a `MagicMap` to `dynamic`, you can read and write keys with
JavaScript-style dot syntax. It is convenient for prototyping and scripts.

```dart
final d = MagicMap({'user': {'name': 'Alice', 'tags': ['a']}}) as dynamic;

d.user.name;              // Alice
d.user.missing;           // null
d.user.name = 'Bob';      // update
d.user.email = 'b@x.io';  // insert
d.user.tags.add('b');     // writes through
d.user.tags = [...?d.user.tags, 'c'];
```

Be aware of the trade-offs before using it in application code:

- The `dynamic` cast gives up autocomplete and static checking. The path and
  typed APIs above need no cast.
- A missing key reads as `null`, so `d.missing.deeper` throws just like
  JavaScript would. Use `getPath` or `getAs` when the shape is uncertain.
- Member names that exist on `MagicMap` itself (`raw`, `set`, `getPath`,
  `getAs`, `clone`, `toJson`, ...) cannot be read with dot syntax. Use
  `d['set']` or `getPath('set')` for such keys.
- Dot access relies on `noSuchMethod`, which needs symbol names at runtime.
  It works on the Dart VM and Flutter mobile/desktop. In minified web builds
  symbol names may be mangled; prefer the path API there.

## Equality and printing

Two views are `==` when they wrap the same underlying collection, so
`map.getPath('user') == map.getPath('user')` is `true`, and `hashCode`
follows the same identity, which makes a view safe to use as a map key. Two
separately constructed maps with the same content are not equal; compare
`raw` for structural checks. `toString()` prints like the plain collection
would.

## Method summary

| Method                         | Returns              | Mutates |
| ------------------------------ | -------------------- | ------- |
| `getPath(path, [default])`     | value or view        | no      |
| `hasPath(path)`                | `bool`               | no      |
| `getAs<T>(path)`               | `T?`                 | no      |
| `requireAs<T>(path)`           | `T` or throws        | no      |
| `getListOf<T>(path)`           | `List<T>?`           | no      |
| `getMapOf<V>(path)`            | `Map<String, V>?`    | no      |
| `set(path, value)`             | `void`               | yes     |
| `removePath(path)`             | removed value        | yes     |
| `getWithGlob(pattern)`         | `List<dynamic>`      | no      |
| `setImmutable(path, value)`    | new copy             | no      |
| `clone()`                      | new copy             | no      |
| `raw` / `toJson()`             | live underlying data | no      |
| `toJsonString(...)`            | `String`             | no      |
| `MagicMap.fromJsonString(s)`   | `MagicMap`           | n/a     |
| `MagicList.fromJsonString(s)`  | `MagicList`          | n/a     |
| `MagicMap.view(map)`           | view, no copy        | n/a     |
| `MagicList.view(list)`         | view, no copy        | n/a     |
