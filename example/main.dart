import 'package:magic_map/magic_map.dart';

void main() {
  final data =
      MagicMap({
            "user": {"name": null},
          })
          as dynamic;

  print(data.user.name); // Miracle
}
