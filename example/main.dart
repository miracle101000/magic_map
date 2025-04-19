import 'package:magic_map/magic_map.dart';

void main() {
  final map1 =
      MagicMap({
            'user': {
              'profile': {'name': 'Alice', 'age': 30},
              'hobbies': ['reading', 'traveling'],
            },
          })
          as dynamic;

  print(map1.user.profile.name); // Alice
  print(map1.user.hobbies[0]); // reading

  // Correct way to add new items to a list in the map (immutable)
  map1.user.hobbies = [...?map1.user.hobbies, 'coding'];

  print(map1.user.profile.name); // Alice (unchanged)
  print(map1.user.hobbies); // [reading, traveling, coding]

  // Modifying nested paths
  map1.user.profile.name = 'Bob';
  map1.user.profile.city = 'Lagos';
  print(map1.user.profile.name); // Bob
  print(map1.user.profile.city); // Lagos
  print(map1.user.hobbies); // [reading, traveling, coding]

  // Immutable update: Changing 'age' in the cloned map
  final clone = map1.setImmutable('user.profile.age', 35);
  print(clone.user.profile.age); // 35
  print(map1.user.profile.age); // 30

  // #################################################################################

  final map2 =
      MagicMap({
            'user': {
              'name': 'Alice',
              'age': 30,
              'address': {'city': 'New York', 'zip': '10001'},
              'hobbies': ['reading', 'hiking'],
            },
          })
          as dynamic;

  print(map2.getPath('user.name')); // Output: Alice
  print(map2.getPath('user.address.city')); // Output: New York
  print(map2.getPath('user.hobbies.0')); // Output: reading

  // Default value for missing paths
  print(map2.getPath('user.phone', 'N/A')); // Output: N/A

  // Find all values matching a pattern
  final results = map2.getWithGlob('user.*.city');
  print(results); // Output: [New York]

  final allHobbies = map2.getWithGlob('user.hobbies.*');
  print(allHobbies); // Output: [reading, hiking]

  // Find all values matching a pattern
  final result = map2.getWithGlob('user.*.city');
  print(result); // Output: [New York]

  final allHobbie = map2.getWithGlob('user.hobbies.*');
  print(allHobbie); // Output: [reading, hiking]

  // Convert to JSON string
  final jsonString = map2.toJsonString(null, 2);
  print(jsonString);
  /*
Output:
{
  "user": {
    "name": "Bob",
    "age": 30,
    "address": {
      "city": "New York",
      "zip": "10001"
    },
    "hobbies": [
      "reading",
      "hiking"
    ],
    "phone": "123-456-7890"
  }
}
*/

  // Create from JSON string
  final fromJson = MagicMap.fromJsonString('{"test": {"value": 42}}');
  print(fromJson.getPath('test.value')); // Output: 42
}
