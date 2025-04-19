## Dynamic Property Access with MagicMap

MagicMap enables JavaScript-style dynamic property access when cast as `dynamic`. This provides a clean, intuitive syntax for working with nested data structures.

### Basic Dynamic Access

```dart
final map1 = MagicMap({
  'user': {
    'profile': {'name': 'Alice', 'age': 30},
    'hobbies': ['reading', 'traveling'],
  },
}) as dynamic; // Cast to dynamic for property access

// Access nested properties directly
print(map1.user.profile.name); // Output: Alice
print(map1.user.hobbies[0]);   // Output: reading
```

### Modifying Values

```dart
// Update existing values
map1.user.profile.name = 'Bob';
print(map1.user.profile.name); // Output: Bob

// Add new properties dynamically
map1.user.profile.city = 'Lagos';
print(map1.user.profile.city); // Output: Lagos
```

### Working with Lists

```dart
// Immutable list update pattern
map1.user.hobbies = [...?map1.user.hobbies, 'coding'];
print(map1.user.hobbies); // Output: [reading, traveling, coding]

// Direct index access
map1.user.hobbies[1] = 'swimming';
print(map1.user.hobbies); // Output: [reading, swimming, coding]
```

### Immutable Updates

```dart
// Original values
print(map1.user.profile.age); // Output: 30

// Create an updated clone
final clone = map1.setImmutable('user.profile.age', 35);
print(clone.user.profile.age); // Output: 35

// Original remains unchanged
print(map1.user.profile.age); // Output: 30
```

### Important Notes

1. **Dynamic Cast Requirement**:  
   Must cast to `dynamic` for property access syntax to work:
   ```dart
   final map = MagicMap(...) as dynamic;
   ```

2. **List Modification**:  
   For immutable list updates, use the spread operator pattern:
   ```dart
   map.listField = [...?map.listField, newItem];
   ```

3. **Type Safety**:  
   Dynamic access bypasses static type checking. For type-safe code, use `getPath()`/`set()` methods instead.

4. **Performance**:  
   Dynamic access has minimal overhead compared to traditional Map access methods.

This syntax is particularly useful for:
- Rapid prototyping
- Working with complex JSON structures
- Building dynamic UIs where data paths may change frequently
- Cases where readability is prioritized over strict typing

## Core API Methods

### 1. Path-Based Access

#### `getPath(String path, [dynamic defaultValue])`
Get a value using dot-notation path with optional default if path doesn't exist.

```dart
final map = MagicMap({
  'user': {
    'profile': {'name': 'Alice', 'age': 30},
    'hobbies': ['reading', 'traveling'],
  },
});

// Basic access
print(map.getPath('user.profile.name')); // Output: Alice

// Array index access
print(map.getPath('user.hobbies.1')); // Output: traveling

// Non-existent path with default
print(map.getPath('user.contact.email', 'N/A')); // Output: N/A

// Nested default
print(map.getPath('user.profile.address.city', 'Unknown')); // Output: Unknown
```

#### `set(String path, dynamic value)`
Set values using dot-notation paths, creating intermediate objects as needed.

```dart
// Update existing
map.set('user.profile.age', 31);

// Create new nested path
map.set('user.contact.email', 'alice@example.com');

// Array index modification
map.set('user.hobbies.0', 'coding');

print(map.getPath('user.profile.age')); // Output: 31
print(map.getPath('user.contact.email')); // Output: alice@example.com
print(map.getPath('user.hobbies.0')); // Output: coding
```

### 2. Pattern Matching

#### `getWithGlob(String pattern)`
Find all values matching a glob pattern (`*` wildcards supported).

```dart
final results = map.getWithGlob('user.*.name');
print(results); // Output: [Alice]

final allHobbies = map.getWithGlob('user.hobbies.*');
print(allHobbies); // Output: [coding, traveling]

// Deep wildcard matching
map.set('company.departments.engineering.manager', 'Bob');
map.set('company.departments.sales.manager', 'Carol');

final managers = map.getWithGlob('company.departments.*.manager');
print(managers); // Output: [Bob, Carol]
```

### 3. Immutable Operations

#### `setImmutable(String path, dynamic value)`
Create a new MagicMap with the specified modification.

```dart
final updated = map.setImmutable('user.profile.name', 'Alicia');

print(map.getPath('user.profile.name')); // Output: Alice (original unchanged)
print(updated.getPath('user.profile.name')); // Output: Alicia

// Can chain immutable operations
final doubleUpdated = map
  .setImmutable('user.profile.name', 'Alicia')
  .setImmutable('user.profile.age', 32);

print(doubleUpdated.getPath('user.profile.age')); // Output: 32
```

### 4. JSON Serialization

#### `toJsonString([Object? Function(dynamic)? replacer, int indent = 0])`
Convert to formatted JSON string.

```dart
// Compact JSON
print(map.toJsonString()); 
// Output: {"user":{"profile":{"name":"Alice","age":31},"hobbies":["coding","traveling"],"contact":{"email":"alice@example.com"}}}

// Pretty-printed JSON
print(map.toJsonString(null, 2));
/*
Output:
{
  "user": {
    "profile": {
      "name": "Alice",
      "age": 31
    },
    "hobbies": [
      "coding",
      "traveling"
    ],
    "contact": {
      "email": "alice@example.com"
    }
  }
}
*/

// With replacer function
String replacer(dynamic key, dynamic value) =>
    value is String ? value.toUpperCase() : value;
print(map.toJsonString(replacer));
// Output: {"user":{"profile":{"name":"ALICE","age":31},"hobbies":["CODING","TRAVELING"],"contact":{"email":"ALICE@EXAMPLE.COM"}}}
```

#### `MagicMap.fromJsonString(String jsonString)`
Create from JSON string (static method).

```dart
final jsonMap = MagicMap.fromJsonString('''
{
  "system": {
    "version": "1.0.0",
    "config": {
      "darkMode": true
    }
  }
}
''');

print(jsonMap.getPath('system.config.darkMode')); // Output: true
print(jsonMap.system.version); // Output: 1.0.0 (with dynamic access)
```

### Method Comparison Table

| Method | Use Case | Returns | Mutates Original |
|--------|----------|---------|------------------|
| `getPath()` | Safe nested access | The value or default | No |
| `set()` | Deep value updates | void | Yes |
| `getWithGlob()` | Pattern matching | List<dynamic> | No |
| `setImmutable()` | Functional updates | New MagicMap | No |
| `toJsonString()` | Serialization | String | No |
| `fromJsonString()` | Deserialization | MagicMap | N/A |

These methods provide comprehensive tools for working with complex nested data structures while supporting both mutable and immutable patterns.