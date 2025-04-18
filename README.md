## `MagicMap` Flutter Package

The `MagicMap` package provides a convenient way to access nested maps using dot notation, mimicking JavaScript-style object access. This package aims to simplify the way you interact with dynamic data structures like JSON in Dart and Flutter.

---

### Featuress
- Access nested maps using dot notation.
- Supports dynamic property access.
- Simple, clean API for easier handling of complex data structures.

---

### Installation

To add the `MagicMap` package to your Flutter project, follow these steps:

1. **Add the Dependency**: 
   In your `pubspec.yaml` file, add the package under `dependencies`:

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     magic_map:
       path: ../magic_map  # Adjust the path to the local package location
   ```

2. **Get the Packages**:
   Run the following command in your project directory to fetch the package:

   ```bash
   flutter pub get
   ```

---

### Usage

Here’s how to use the `MagicMap` package in your project:

1. **Import the Package**:

   In your Dart file, import the `MagicMap` package:

   ```dart
   import 'package:magic_map/magic_map.dart';
   ```

2. **Create and Use `MagicMap`**:

   The `MagicMap` class allows you to access data in a map using dot notation.

   ```dart
   void main() {
     final data = MagicMap({
       'user': {
         'name': 'Alice',
         'age': 30,
         'address': {
           'city': 'New York',
           'zip': '10001',
         },
       },
     });

     print(data['user']['name']);  // Outputs: Alice
     print(data['user']['address']['city']);  // Outputs: New York
   }
   ```

---

### API Reference

- **MagicMap(Map<String, dynamic> data)**:  
  The constructor accepts a map and allows for dynamic access to nested keys using dot notation.

- **operator []**:  
  Allows accessing values within the map using the bracket syntax, e.g., `data['key']`.

---

### Contributing

We welcome contributions to this project! To contribute:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-name`).
3. Make your changes.
4. Commit your changes (`git commit -am 'Add new feature'`).
5. Push to the branch (`git push origin feature-name`).
6. Open a pull request.

Please ensure that you follow the Dart code style and include tests for any new functionality.

---

### License

This package is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

---

### Acknowledgments

- This package is inspired by JavaScript's object access syntax and aims to bring that convenience to Dart.
- Special thanks to the Flutter and Dart communities for providing a great ecosystem.

---

