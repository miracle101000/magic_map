# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.2] - 2025-04-19

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

