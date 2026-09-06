// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:magic_map/magic_map.dart';

void main() {
  // -------------------------------------------------------------------------
  // Dynamic (JavaScript-style) access. Cast to `dynamic` for dot syntax.
  // -------------------------------------------------------------------------
  final data = MagicMap({
    'user': {
      'profile': {'name': 'Alice', 'age': 30},
      'hobbies': ['reading', 'traveling'],
    },
  });
  final map1 = data as dynamic;

  print(map1.user.profile.name); // Alice
  print(map1.user.hobbies[0]); // reading
  print(map1.user.missing); // null

  // Writes go straight through to the underlying data.
  map1.user.profile.name = 'Bob';
  map1.user.profile.city = 'Lagos';
  print(map1.user.profile.name); // Bob
  print(map1.user.profile.city); // Lagos

  // Lists are real lists: index writes, add, spread and iteration all work.
  map1.user.hobbies[1] = 'swimming';
  map1.user.hobbies.add('coding');
  map1.user.hobbies = [...?map1.user.hobbies, 'chess'];
  print(map1.user.hobbies); // [reading, swimming, coding, chess]
  print(data.raw['user']['hobbies']); // same list, seen through raw

  // Immutable update: the clone changes, the original does not.
  final clone = map1.setImmutable('user.profile.age', 35);
  print(clone.user.profile.age); // 35
  print(map1.user.profile.age); // 30

  // -------------------------------------------------------------------------
  // Path API (statically typed, never needs a dynamic cast).
  // -------------------------------------------------------------------------
  final map2 = MagicMap({
    'user': {
      'name': 'Alice',
      'age': 30,
      'address': {'city': 'New York', 'zip': '10001'},
      'hobbies': ['reading', 'hiking'],
    },
  });

  print(map2.getPath('user.name')); // Alice
  print(map2.getPath('user.address.city')); // New York
  print(map2.getPath('user.hobbies.0')); // reading
  print(map2.getPath('user.hobbies[1]')); // hiking
  print(map2.getPath('user.phone', 'N/A')); // N/A
  print(map2.hasPath('user.phone')); // false

  map2.set('user.phone', '123-456-7890');
  map2.set('user.hobbies.2', 'chess'); // index == length appends
  map2.set('user.friends[0].name', 'Bob'); // creates the list and the map
  print(map2.getPath('user.friends.0.name')); // Bob
  print(map2.removePath('user.age')); // 30

  // Glob patterns: `*` and `?` inside a segment, `*` for any key/index,
  // `**` for any depth.
  print(map2.getWithGlob('user.*.city')); // [New York]
  print(map2.getWithGlob('user.hobbies.*')); // [reading, hiking, chess]
  print(map2.getWithGlob('**.name')); // [Alice, Bob]
  print(map2.getWithGlob('user.hob*')); // [[reading, hiking, chess]]

  // Invalid writes throw instead of silently destroying data.
  try {
    map2.set('user.name.first', 'A'); // 'user.name' is a String
  } on MagicMapException catch (e) {
    print(e);
  }

  // -------------------------------------------------------------------------
  // JSON
  // -------------------------------------------------------------------------
  print(map2.toJsonString(indent: 2));
  print(jsonEncode(map2)); // MagicMap has toJson(), so this works too

  // JS-style replacer: transform values or drop keys with MagicMap.omit.
  print(
    map2.toJsonString(
      replacer: (key, value) {
        if (key == 'phone') return MagicMap.omit;
        return value is String ? value.toUpperCase() : value;
      },
    ),
  );

  final fromJson = MagicMap.fromJsonString('{"test": {"value": 42}}');
  print(fromJson.getPath('test.value')); // 42

  final list = MagicList.fromJsonString('[{"id": 1}, {"id": 2}]');
  print(list.getWithGlob('*.id')); // [1, 2]
}
