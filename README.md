# magic_map

JavaScript-style dot access for deeply nested Dart maps and lists.

```dart
final data = MagicMap({
  'user': {
    'profile': {'name': 'Alice', 'age': 30},
    'hobbies': ['reading', 'traveling'],
  },
});

final d = data as dynamic;
print(d.user.profile.name);      // Alice
d.user.hobbies[1] = 'swimming';  // writes through
d.user.profile.city = 'Lagos';   // adds a key

print(data.getPath('user.hobbies[1]')); // swimming
print(data.raw);                        // plain Map<String, dynamic>
```

## How it works

`MagicMap` and `MagicList` are *views* over ordinary `Map<String, dynamic>`
and `List<dynamic>` objects.

- Reading a nested map or list returns another view over the **same** data.
- Every write, through dot access, `[]=`, `set()` or the `List` API, goes
  straight to the underlying collection.
- `raw` returns that underlying collection at any level.
- The constructor **deep-copies** its input into plain containers and converts
  keys to strings. The map you pass in is never modified, and writes never
  fail with type errors no matter how narrowly the original literal was typed.
- Values you assign are deep-copied too, so later changes to the original
  object do not leak into the map.

## Dynamic access

Cast to `dynamic` to use dot syntax. Static typing cannot know your keys, so
this is required for property-style access.

```dart
final d = MagicMap({'user': {'name': 'Alice', 'tags': ['a']}}) as dynamic;

d.user.name;              // Alice
d.user.missing;           // null
d.user.name = 'Bob';      // update
d.user.email = 'b@x.io';  // insert
d.user.tags.add('b');     // MagicList is a real List
d.user.tags[0] = 'z';
d.user.tags = [...?d.user.tags, 'c'];
for (final tag in d.user.tags) { /* ... */ }
```

Notes:

- A missing key reads as `null`, so `d.missing.deeper` throws just like
  JavaScript would. Use `getPath` when the shape is uncertain.
- Member names that exist on `MagicMap` itself (`raw`, `set`, `getPath`,
  `clone`, `toJson`, ...) cannot be read with dot syntax. Use `d['set']` or
  `getPath('set')` for such keys.
- Dot access relies on `noSuchMethod`, which needs symbol names at runtime.
  It works on the Dart VM and Flutter mobile/desktop. In minified web builds
  symbol names may be mangled; prefer the path API there.

## Path API

All of these are available on both `MagicMap` and `MagicList`, including
nested views, and work without any `dynamic` cast.

Paths use dot notation with optional bracket indices. `user.tags.0`,
`user.tags[0]` and `users[1].name` are equivalent forms. Escape a literal dot
or bracket inside a key with a backslash: `r'a\.b'`.

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

## Equality and printing

Two views are `==` when they wrap the same underlying collection, so
`d.user == d.user` is `true`. Two separately constructed maps with the same
content are not equal; compare `raw` for structural checks. `toString()`
prints like the plain collection would.

## Method summary

| Method                         | Returns              | Mutates |
| ------------------------------ | -------------------- | ------- |
| `getPath(path, [default])`     | value or view        | no      |
| `hasPath(path)`                | `bool`               | no      |
| `set(path, value)`             | `void`               | yes     |
| `removePath(path)`             | removed value        | yes     |
| `getWithGlob(pattern)`         | `List<dynamic>`      | no      |
| `setImmutable(path, value)`    | new copy             | no      |
| `clone()`                      | new copy             | no      |
| `raw` / `toJson()`             | live underlying data | no      |
| `toJsonString(...)`            | `String`             | no      |
| `MagicMap.fromJsonString(s)`   | `MagicMap`           | n/a     |
| `MagicList.fromJsonString(s)`  | `MagicList`          | n/a     |
