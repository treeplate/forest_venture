import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/world.dart';

const String _emptyWorld = '1 0\n'
    '...\n'
    'empty\n'
    '  ';

const String _goalWorld = '0 0\n'
    'empty\n'
    'main\n'
    ' G|';

void main() {
  test('Transition unit tests', () async {
        final WorldSource source = TestWorldSource.only;
        World world;
        Completer<void> completer = Completer<void>();
        source.addListener(() {
          if(source.currentWorld != null) {
            world = source.currentWorld;
            completer?.complete();
          }
        });
        await completer.future;
        expect(world?.name ?? "ERR", "main");
        completer = Completer<void>();
        world.right();
        await completer.future;
        expect(world?.name ?? "ERR", "empty");
    },
  );
}

Map<String, String> worlds = {
  "main": _goalWorld,
  "empty": _emptyWorld,
};

class TestWorldSource extends WorldSource {
  TestWorldSource() : super((String name) async => worlds[name]);
  static TestWorldSource only = TestWorldSource();
}

void expectPlayerAt(World w, int x, int y) {
  expect(w.playerX, equals(x));
  expect(w.playerY, equals(y));
}