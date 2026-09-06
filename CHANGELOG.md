# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.1] - 2026-09-06

### Changed

- README and package description now lead with the path API (`getPath`,
  `set`, `getWithGlob`, `setImmutable`, JSON helpers) and present dynamic
  dot access as an optional extra with its trade-offs listed. No code
  changes.

---

## [2.0.0] - 2026-09-06

Internal rewrite around one invariant: the underlying data is always plain
`Map<String, dynamic>` / `List<dynamic>` containers, and every view writes
through to it. Most of the previously documented behaviour now actually works.

### Fixed

- `getPath()` resolves list indices (`user.hobbies.0`); it returned the
  default before.
- `set()` through a list index (`user.hobbies.0`) no longer throws or
  replaces the list with an empty map.
- `set()` with a map or list value no longer stores wrapper objects in the
  data, which made `toJsonString()` and `raw` unusable afterwards.
- Direct list mutation through dot access (`d.user.hobbies[1] = 'x'`,
  `.add(...)`) now writes through instead of modifying a throwaway copy.
- Writes into maps built from narrowly typed literals (for example
  `{'name': 'Alice'}` inferred as `Map<String, String>`) no longer throw
  type errors: input is deep-copied into `Map<String, dynamic>`.
- Non-string keys in the input are converted with `toString()` instead of
  failing lazily on access.
- `getPath()` no longer swallows every error with a bare `catch`.
- The `replacer` parameter of `toJsonString()` now behaves like the
  JavaScript `JSON.stringify` replacer it was documented as; the previous
  parameter was `JsonEncoder`'s `toEncodable` and never saw string values.

### Added

- `MagicList`: a real `List` view returned for nested lists, with
  write-through `[]=`, `add`, `insert`, `removeAt`, `sort`, and so on.
- Nested views are `MagicMap` instances, so `getPath`, `set`, `getWithGlob`,
  `setImmutable`, `toJsonString`, `raw` and friends work at any depth.
- Bracket index syntax in paths: `users[0].name`, `items[*].id`.
- Backslash escaping of `.` and `[` inside keys.
- `hasPath()`, `removePath()`, `clone()`, `toJson()`.
- Glob patterns support `*` and `?` inside a segment and `**` for any depth.
- `MagicList.fromJsonString()`.
- `toJsonString(toEncodable: ...)` for values JSON cannot encode.
- `MagicMap.omit` sentinel for dropping entries from a replacer.
- `set()` creates intermediate lists for integer segments and appends when
  the index equals the list length.
- Cyclic input is rejected with `MagicMapException` instead of hanging.
- `==` and `hashCode` compare the underlying collection, so two views over
  the same data are equal.
- A test suite (`flutter test`) covering the public API.

### Changed (breaking)

- `MagicMap(...)` deep-copies its argument; it used to hold a reference, so
  mutations no longer show up in the original map. It requires a `Map`
  (or `MagicMap`, or `null`) and throws `MagicMapException` for other input.
- `toJsonString` now takes named parameters:
  `toJsonString(indent: 2, replacer: ..., toEncodable: ...)`.
- `raw` is typed `Map<String, dynamic>` and returns the live data.
- `set()` throws `MagicMapException` instead of silently replacing a scalar
  or a list with an empty map when a path descends through it, and for list
  indices that are out of range.
- `toString()` prints the plain map (`{a: 1}`) rather than `MagicMap({a: 1})`.
- Assigning a `MagicMap`/`MagicList` or a raw collection stores a deep copy
  rather than an alias.
- `MagicMap.fromJsonString` throws `MagicMapException` for invalid JSON or a
  non-object root.
- Removed the unused `glob` dependency.

---

## [1.0.4] - 2025-04-19

### Added

- Introduced `MagicMap` class for flexible, dynamic map access.
- Support for dot-separated path-based value retrieval using `getPath()`.
- Support for dot-separated dynamic nested value assignment using `set()`.
- Bash-style glob pattern matching support with `getWithGlob()`.
- Immutable data updates using `setImmutable()`.
- JSON serialization via `toJsonString()` and `fromJsonString()`.
- Dynamic property access using `noSuchMethod` on `_MagicMapImpl`.
- Custom `MagicMapException` class with detailed error messages.

### Internal

- Wrapped and unwrapped data to maintain consistent structure using `_wrap()` and `_unwrap()` utilities.
- Recursive collection of matched entries for glob matching.

---

