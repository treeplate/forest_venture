import 'package:flutter_test/flutter_test.dart';

import 'package:forest_venture/main.dart';
import 'package:forest_venture/world.dart';

void main() {
  testWidgets('Most basic world', (WidgetTester tester) async {
    await tester.pumpWidget(
      WorldCanvas(world: World(1, <Cell>[Cell()], 0, 0)),
    );
    await expectLater(find.byType(WorldCanvas), matchesGoldenFile('basic_world_1.png'));
  });
}
