import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/world.dart';

const String _boxWorld = 'empty\n'
    'boxes\n\n'
    'TTTTT\n'
    'T _ T\n'
    'T #GT\n'
    'T a T\n'
    'TTTTT\n\n\n'
    'a boxes';

const String _emptyWorld = '...\n'
    'empty\n\n'
    'GTa\n\n\n'
    'a empty';

void main() {
  group(
    "Tests",
    () {
      test('Box unit tests', () async {
        final WorldSource source = TestWorldSource();

        Completer<World> completer = Completer<World>();
        source.addListener(() {
          if (source.currentWorld != null) {
            completer.complete(source.currentWorld!);
          }
        });
        World world = await completer.future;
        expect(world.name, 'boxes');
        completer = Completer<World>();
        expect(world.rooms.length, 1);
        Room room = world.rooms.single;
        expect(world.objects.whereType<Box>().length, 1);
        Box box = world.objects.whereType<Box>().single;
        expect(world.objects.whereType<Player>().length, 1);
        Player player = world.objects.whereType<Player>().single;
        expectAt(Position.withRoom(2, 2, room), box);
        expectAt(Position.withRoom(2, 3, room), player);
        expect(room.cells.where((element) => element is! Empty).length, 2);
        Iterable<Cell> goals = room.cells.where((element) => element is! Empty);
        expect(goals.first is BoxGoal, true);
        expect(goals.last is PlayerGoal, true);
        expect(room.goalAt(2, 1), goals.first);
        expect(room.goalAt(3, 2), goals.last);
        expect(world.goalsDone(), false);
        expect(completer.isCompleted, false);
        world.up(player);
        expectAt(Position.withRoom(2, 1, room), box);
        expectAt(Position.withRoom(2, 2, room), player);
        expect(world.goalsDone(), false);
        expect(completer.isCompleted, false);
        world.right(player);
        expectAt(Position.withRoom(2, 1, room), box);
        expectAt(Position.withRoom(3, 2, room), player);
        expect(world.goalsDone(), true);

        world = await completer.future;
        expect(world.name, 'empty');
      });
    },
  );
}

void expectAt(Position position, SolidObject object) {
  expect(object.position, equals(position));
}

Map<String, String> worlds = {
  "main": _boxWorld,
  "empty": _emptyWorld,
};

class TestWorldSource extends WorldSource {
  TestWorldSource() : super((String name) async => worlds[name]!);
  static TestWorldSource only = TestWorldSource();

  String get startingLevel => 'main';
}
