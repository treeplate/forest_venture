import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/world.dart';

const String _emptyWorld = '...\n'
    'empty\n\n'
    'GTa\n\n\n'
    'a empty';

const String _goalWorld = 'empty\n'
    'main\n\n'
    'aG\n\n\n'
    'a goal';

void main() {
  test(
    'Transition unit tests',
    () async {
      final WorldSource source = TestWorldSource.only;
      Completer<World> completer = Completer<World>();
      source.addListener(() {
        if (source.currentWorld != null) {
          completer.complete(source.currentWorld!);
        }
      });
      World world = await completer.future;
      expect(world.name, "main");
      completer = Completer<World>();
      expect(world.objects.length, equals(1));
      expect(world.objects.single is Player, true);
      Player p = world.objects.single as Player;
      world.right(p);
      world = await completer.future;
      expect(world.name, "empty");
    },
  );
}

Map<String, String> worlds = {
  "main": _goalWorld,
  "empty": _emptyWorld,
};

class TestWorldSource extends WorldSource {
  TestWorldSource() : super((String name) async => worlds[name]!);
  static TestWorldSource only = TestWorldSource();

  String get startingLevel => 'main';
}

void expectPlayerAt(Player player, int x, int y) {
  expect(player.position.x, equals(x));
  expect(player.position.y, equals(y));
}
