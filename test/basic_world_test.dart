import 'package:flutter_test/flutter_test.dart';
import 'package:forest_venture/main.dart';
import 'package:forest_venture/world.dart';

void main() {
  testWidgets('Most basic world', (WidgetTester tester) async {
    await tester.pumpWidget(
      WorldCanvas(world: World(1, <Cell>[Cell()], 0, 0)),
    );
    await expectLater(
        find.byType(WorldCanvas), matchesGoldenFile('basic_world_1.png'));
  });
  testWidgets('Movement', (WidgetTester tester) async {
    await tester.pumpWidget(
      WorldCanvas(world: World(2, <Cell>[Cell(), Goal()], 0, 0)),
    );
    //TODO: Check image
    await tester.tapAt(Offset(
        tester.getCenter(find.byType(WorldCanvas)).dx + 60.0,
        tester.getCenter(find.byType(WorldCanvas)).dy));
    //TODO: Check image again
  });
}
