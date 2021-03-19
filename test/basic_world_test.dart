import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/main.dart';
import 'package:forest_venture/world.dart';

const String _emptyWorld = '0 0\n'
    '...\n'
    'empty\n'
    ' ';

const String _lineWorld = '0 0\n'
    '...\n'
    'line\n'
    '  T|';

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
        final WorldSource source = TestWorldSource("1 1\n...\nmunit\n  |\n  |");
        World world;
        Completer<void> completer = Completer<void>();
        source.addListener(() {
          world = source.currentWorld;
          completer.complete();
        });
        await completer.future;
        expectPlayerAt(world, 1, 1);
        world.left();
        expectPlayerAt(world, 0, 1);
        world.left();
        expectPlayerAt(world, 0, 1);
        world.right();
        expectPlayerAt(world, 1, 1);
        world.right();
        expectPlayerAt(world, 1, 1);
        world.up();
        expectPlayerAt(world, 1, 0);
        world.up();
        expectPlayerAt(world, 1, 0);
        world.down();
        expectPlayerAt(world, 1, 1);
        world.down();
        expectPlayerAt(world, 1, 1);
      });
    },
  );
}

void expectPlayerAt(World w, int x, int y) {
  expect(w.playerX, equals(x));
  expect(w.playerY, equals(y));
}

class TestWorldSource extends WorldSource {
  TestWorldSource(String data) : super((String name) async => data);
  TestWorldSource.empty() : super(null);
}
