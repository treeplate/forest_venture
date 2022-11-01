import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/main.dart';
import 'package:forest_venture/world.dart';

const String _emptyWorld = '...\n'
    'empty\n'
    '\n'
    'G\n'
    '\n'
    '\n'
    'a ';

const String _lineWorld = '...\n'
    'line\n'
    '\n'
    'Ga T\n'
    '\n'
    '\n'
    'a ';
const String _squareWorld = '...\n'
    'munit\n\n'
    'TTTTT\n'
    'T  TT\n'
    'T aTT\n'
    'TTTTT\n'
    'TTGTT\n\n\n'
    'a munit';

void main() {
  group(
    "Tests",
    () {
      testWidgets(
        'Most basic world',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: GamePage(
                source: TestWorldSource(_emptyWorld),
              ),
            ),
          );
          await tester.pump();
          await expectLater(
            find.byType(WorldCanvas),
            matchesGoldenFile('basic_world_1.png'),
          );
        },
        skip: !Platform.isMacOS,
      );

      testWidgets(
        'Movement, trees',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: GamePage(
                source: TestWorldSource(_lineWorld),
              ),
            ),
          );
          await tester.pump();
          await expectLater(
            find.byType(WorldCanvas),
            matchesGoldenFile('basic_world_move_before.png'),
          );
          await tester.tapAt(
            Offset(
              tester.getCenter(find.byType(WorldCanvas)).dx + 60.0,
              tester.getCenter(find.byType(WorldCanvas)).dy,
            ),
          );
          await tester.pump();
          await expectLater(
            find.byType(WorldCanvas),
            matchesGoldenFile('basic_world_move_before.png'),
          );
          await tester.pump(const Duration(seconds: 1));
          await expectLater(
            find.byType(WorldCanvas),
            matchesGoldenFile('basic_world_move_after.png'),
          );
          await tester.tapAt(
            Offset(
              tester.getCenter(find.byType(WorldCanvas)).dx + 60.0,
              tester.getCenter(find.byType(WorldCanvas)).dy,
            ),
          );
          await tester.pump();
          await expectLater(
            find.byType(WorldCanvas),
            matchesGoldenFile('basic_world_move_after.png'),
          );
        },
        skip: !Platform.isMacOS,
      );

      testWidgets('Move unit tests', (WidgetTester tester) async {
        final WorldSource source = TestWorldSource(_squareWorld);

        Completer<World> completer = Completer<World>();
        source.addListener(() {
          completer.complete(source.currentWorld!);
        });
        World world = await completer.future;
        expect(world.objects.length, equals(21));
        expect(world.objects[9] is Player, true);
        Player p = world.objects[9] as Player;
        expectPlayerAt(p, 2, 2);
        world.left(p);
        expectPlayerAt(p, 1, 2);
        world.left(p);
        expectPlayerAt(p, 1, 2);
        world.right(p);
        expectPlayerAt(p, 2, 2);
        world.right(p);
        expectPlayerAt(p, 2, 2);
        world.up(p);
        expectPlayerAt(p, 2, 1);
        world.up(p);
        expectPlayerAt(p, 2, 1);
        world.down(p);
        expectPlayerAt(p, 2, 2);
        world.down(p);
        expectPlayerAt(p, 2, 2);
      });
    },
  );
}

void expectPlayerAt(Player player, int x, int y) {
  expect(player.position.x, equals(x));
  expect(player.position.y, equals(y));
}

class TestWorldSource extends WorldSource {
  TestWorldSource(String data) : super((String name) async => data);
  TestWorldSource.empty() : super(null);
}
