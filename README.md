
---

```markdown
# 🔮 MagicMap

`MagicMap` is a powerful Dart utility for dynamic, nested map access and mutation with dot-path syntax, glob support, immutable updates, and dynamic field access.

> Effortlessly manage deeply nested structures in a readable, type-safe-ish way.

---

## ✨ Features

- ✅ Dot-path access to deeply nested fields
- ✅ Dynamic creation of nested structures with `set`
- ✅ Immutable update API with `setImmutable`
- ✅ Bash-style glob pattern querying (`Glob`)
- ✅ JSON (de)serialization
- ✅ Dynamic dot access via `noSuchMethod`
- ✅ Supports `Map<String, dynamic>` and nested `List`s

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  glob: ^2.1.2
```

Then run:

```bash
dart pub get
```

---

## 🚀 Quick Start

### 7️⃣ Dynamic Dot Access (`noSuchMethod`)
```dart
final map = MagicMap({'person': {'name': 'Zion'}});
print(map.person.name); // Output: Zion
```

---

## 🔍 Usage Examples

### 1️⃣ Basic Access

```dart
final map = MagicMap({'name': 'Echezona', 'age': 24});
print(map.getPath('name')); // Output: Echezona
print(map.getPath('age'));  // Output: 24
```

---

### 2️⃣ Setting a Nested Value Dynamically

```dart
final map = MagicMap({});
map.set('user.profile.name', 'Miracle');

print(map.getPath('user.profile.name')); // Output: Miracle
print(map.toJsonString()); // {"user":{"profile":{"name":"Miracle"}}}
```

---

### 3️⃣ Immutable Update (Functional Style)

```dart
final map1 = MagicMap({'config': {'theme': 'dark'}});
final map2 = map1.setImmutable('config.theme', 'light');

print(map1.getPath('config.theme')); // Output: dark
print(map2.getPath('config.theme')); // Output: light
```

---

### 4️⃣ Glob Matching (Flexible Pattern Matching)

```dart
final data = {
  'settings': {
    'ui': {'theme': 'dark', 'font': 'Roboto'},
    'notifications': {'email': true, 'sms': false},
  }
};

final map = MagicMap(data);

final matches = map.getWithGlob('settings.ui.*');
print(matches); // Output: [dark, Roboto]
```

---

### 5️⃣ Using Lists with Glob

```dart
final data = {
  'users': [
    {'name': 'Alice', 'age': 30},
    {'name': 'Bob', 'age': 25},
  ]
};

final map = MagicMap(data);

final names = map.getWithGlob('users.[*].name');
print(names); // Output: [Alice, Bob]
```

---

### 6️⃣ JSON String Input/Output

```dart
final jsonStr = '{"app":{"version":"1.0.0","debug":false}}';
final map = MagicMap.fromJsonString(jsonStr);

print(map.getPath('app.version')); // Output: 1.0.0

map.set('app.debug', true);
print(map.toJsonString()); 
// Output: {"app":{"version":"1.0.0","debug":true}}
```

---

## 🧱 API Overview

### Constructor
```dart
MagicMap(dynamic data)
```

### Get value at dot path
```dart
map.getPath('config.theme');
```

### Set value at dot path
```dart
map.set('config.theme', 'light');
```

### Immutable update
```dart
final newMap = map.setImmutable('user.active', true);
```

### Glob pattern search
```dart
map.getWithGlob('settings.ui.*');
```

### Convert to JSON
```dart
final jsonStr = map.toJsonString();
```

### Create from JSON
```dart
final map = MagicMap.fromJsonString(jsonStr);
```

---

## ❗Error Handling

Throws `MagicMapException` on:

- Accessing missing keys
- Using `getPath` on non-Map structure
- Invalid root data for path operations

---

## 🔚 License

MIT — use freely, modify wildly, and contribute happily!

---

## 👨‍💻 Author

**Okolo Miracle Echezona**  
📧 okolomiracle513@gmail.com  
🌍 [GitHub](https://github.com/miracle101000) | [LinkedIn](https://www.linkedin.com/in/miracle-okolo-bb2133183)

---