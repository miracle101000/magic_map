## 🔮 MagicMap 

[![Pub Version](https://img.shields.io/pub/v/magic_map?color=blue)](https://pub.dev/packages/magic_map)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A Dart utility that brings JavaScript-style dot notation to nested Map/List structures. Perfect for handling dynamic JSON data with graceful null safety.

```dart
final data = MagicMap({
  "user": {
    "profile": {"name": "Alice", "age": 30},
    "orders": [{"id": 1}, {"id": 2}]
  }
});

print(data.user.profile.name); // Alice
print(data.user.orders[0].id); // 1
```

## 🌟 Features

- 🎯 **Dot-path navigation** - `data.user.profile.name`
- 🛠 **Dynamic path creation** - `set('config.ui.theme', 'dark')`
- 🔍 **Glob pattern matching** - `getWithGlob('users.*.email')`
- 🧊 **Immutable updates** - Create modified copies without side effects
- 📦 **JSON serialization** - `fromJsonString()`/`toJsonString()`
- 🛡 **Null-safe access** - Missing keys return `null` instead of throwing
- 📜 **Detailed errors** - `MagicMapException` with full path context

## 🚀 Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  magic_map: ^1.0.0
  glob: ^2.1.2  # Required for glob patterns
```

Run:
```bash
dart pub get
```

## 🧩 Quick Start

### Basic Usage
```dart
final map = MagicMap({
  'app': {
    'version': '1.0.0',
    'settings': {'theme': 'dark'}
  }
});

// Dot access
print(map.app.settings.theme); // dark

// Path operations
map.set('app.settings.font', 'Roboto');
print(map.getPath('app.settings.font')); // Roboto

// JSON serialization
final jsonStr = map.toJsonString();
```

## 📚 Comprehensive Guide

### 1. Deep Path Operations
```dart
// Create nested paths automatically
final config = MagicMap({});
config.set('services.auth.endpoints.login', '/api/login');

// Access with null safety
print(config.services?.auth?.endpoints?.login); // /api/login
```

### 2. Immutable Updates
```dart
final original = MagicMap({'counter': 1});
final updated = original.setImmutable('counter', 2);

print(original.counter); // 1
print(updated.counter);  // 2
```

### 3. Advanced Pattern Matching
```dart
final data = MagicMap({
  'departments': {
    'engineering': {
      'members': ['Alice', 'Bob']
    },
    'sales': {
      'members': ['Charlie']
    }
  }
});

// Find all member lists
print(data.getWithGlob('departments.*.members'));
// Output: [['Alice', 'Bob'], ['Charlie']]
```

### 4. Error Handling
```dart
try {
  print(data.getPath('nonexistent.key'));
} on MagicMapException catch (e) {
  print(e); // "Missing key 'nonexistent' at path 'nonexistent'"
}
```

## 📖 API Reference

| Method | Description |
|--------|-------------|
| `MagicMap(dynamic data)` | Wrap Map/List data |
| `getPath(String path)` | Get value with path validation |
| `set(String path, dynamic value)` | Create/modify nested path |
| `getWithGlob(String pattern)` | Find values using glob syntax |
| `setImmutable()` | Create modified clone |
| `toJsonString()` | Serialize to JSON string |
| `MagicMap.fromJsonString()` | Parse from JSON string |

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a PR with tests

See our [contribution guidelines](CONTRIBUTING.md) for details.

## 📜 License

MIT © 2024 Okolo Miracle Echezona

```

Key improvements:
1. Added GitHub badges for professionalism
2. Restructured content with clearer hierarchy
3. Added more practical code examples
4. Improved visual consistency with emojis
5. Added contributing section
6. Made API reference more scannable
7. Better emphasized key features
8. Added proper YAML syntax highlighting
9. Made error handling example more realistic
10. Added links for navigation (though actual links would need URL targets)