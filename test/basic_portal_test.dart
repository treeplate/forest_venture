import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/world.dart';

const String _portalWorld = 'empty\n'
    'portal\n'
    '1\n\n'
    'TTTTT\n'
    'TTTTT\n'
    'TaP_T\n'
    'TTTTT\n'
    'TTTTT\n\n'
    'TTT\n'
    ' GT\n'
    'TTT\n\n\n'
    'a portal';

const String _emptyWorld = '...\n'
    'empty\n\n'
    'GTa\n\n\n'
    'a empty';

void main() {
  group(
    "Tests",
    () {
      test('Portal unit tests', () async {
        final WorldSource source = TestWorldSource();

        Completer<World> completer = Completer<World>();
        source.addListener(() {
          if (source.currentWorld != null) {
            completer.complete(source.currentWorld!);
          }
        });
        World world = await completer.future;
        expect(world.name, 'portal');
        completer = Completer<World>();
        expect(world.rooms.length, 2);
        Room room = world.rooms.first;
        expect(world.objects.whereType<FullPortal>().length, 1);
        FullPortal portal = world.objects.whereType<FullPortal>().single;
        expect(world.objects.whereType<Player>().length, 1);
        Player player = world.objects.whereType<Player>().single;
        expectAt(Position.withRoom(2, 2, room), portal);
        expectAt(Position.withRoom(1, 2, room), player);
        expect(room.cells.where((element) => element is! Empty).length, 1);
        Cell boxGoal = room.cells.where((element) => element is! Empty).single;
        expect(boxGoal is BoxGoal, true);
        expect(room.goalAt(3, 2), boxGoal);
        Room room2 = world.rooms.last;
        expect(room2.cells.where((element) => element is! Empty).length, 1);
        Cell playerGoal =
            room2.cells.where((element) => element is! Empty).single;
        expect(room2.goalAt(1, 1), playerGoal);
        expect(world.goalsDone(), false);
        expect(completer.isCompleted, false);
        world.right(player);
        expectAt(Position.withRoom(2, 2, room), player);
        expectAt(Position.withRoom(3, 2, room), portal);
        expect(world.goalsDone(), false);
        expect(completer.isCompleted, false);
        world.right(player);
        expectAt(Position.withRoom(0, 1, room2), player);
        expectAt(Position.withRoom(3, 2, room), portal);
        expect(world.goalsDone(), false);
        world.right(player);
        expectAt(Position.withRoom(1, 1, room2), player);
        expectAt(Position.withRoom(3, 2, room), portal);
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
  "main": _portalWorld,
  "empty": _emptyWorld,
};

class TestWorldSource extends WorldSource {
  TestWorldSource() : super((String name) async => worlds[name]!);
  static TestWorldSource only = TestWorldSource();

  String get startingLevel => 'main';
}
