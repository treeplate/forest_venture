import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/main.dart';
import 'package:forest_venture/world.dart';

void main() {
  testWidgets('Most basic world', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
          home: GamePage(
              source: TestWorldSource(
                  World(1, <Cell>[Empty()], Offset(0, 0), "...")))),
    );
    await tester.pump();
    await expectLater(
      find.byType(WorldCanvas),
      matchesGoldenFile('basic_world_1.png'),
    );
  });

  testWidgets('Movement', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
          home: GamePage(
              source: TestWorldSource(World(
                  3, <Cell>[Empty(), Empty(), null], Offset(0, 0), '...')))),
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
      matchesGoldenFile('basic_world_move_after.png'),
    );
  });
  testWidgets('Tree world', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
          home: GamePage(
              source: TestWorldSource(
                  World(2, <Cell>[Empty(), Tree()], Offset(0, 0), "...")))),
    );
    await tester.pump();
    await expectLater(
      find.byType(WorldCanvas),
      matchesGoldenFile('basic_tree_world.png'),
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
      matchesGoldenFile('basic_tree_world.png'),
    );
  });
  test("Move 2x2 unit tests", () {
    World world = World.parse("1 1\n...\n  |\n  |");
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
}

void expectPlayerAt(World w, int x, int y) {
  expect(w.playerX, equals(x));
  expect(w.playerY, equals(y));
}

@immutable
class TestWorldSource implements WorldSource {
  TestWorldSource(this.world);
  final World world;
  final String name = null;
  Future<World> initWorld() async {
    return world;
  }
}
