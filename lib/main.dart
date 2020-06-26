import 'package:flutter/material.dart';

import 'world.dart';

void main() {
  runApp(ForestVenture(world: fromFile("main.world")));
}

class ForestVenture extends StatelessWidget {
  ForestVenture({Key key, this.world}) : super(key: key);

  final World world;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forest Venture',
      home: GamePage(world: world),
    );
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key key, this.world}) : super(key: key);

  final World world;

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  Widget build(BuildContext context) {
    return WorldCanvas(world: widget.world);
  }
}

class WorldCanvas extends StatefulWidget {
  WorldCanvas({Key key, this.world}) : super(key: key);

  final World world;

  @override
  _WorldCanvasState createState() => _WorldCanvasState();
}

class _WorldCanvasState extends State<WorldCanvas> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WorldPainter(widget.world),
    );
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.world);

  final World world;

  static const Size cellSize = Size(60.0, 60.0);

  @override
  void paint(Canvas canvas, Size size) {
    for (int y = 0; y < world.height; y += 1) {
      for (int x = 0; x < world.width; x += 1) {
        paintCell(canvas, size, x, y, world.at(x, y));
      }
    }
  }

  void paintCell(Canvas canvas, Size size, int x, int y, Cell cell) {
    canvas.drawRect(
        Rect.fromLTWH(x * cellSize.width, y * cellSize.height,
            cellSize.width * 0.8, cellSize.height * 0.8),
        Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) => world != oldDelegate.world;
}
