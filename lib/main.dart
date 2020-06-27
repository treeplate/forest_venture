import 'package:flutter/material.dart';

import 'world.dart';

void main() {
  runApp(ForestVenture());
}

class ForestVenture extends StatelessWidget {
  ForestVenture({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forest Venture',
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key key}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  World _world;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    String data =
        await DefaultAssetBundle.of(context).loadString('worlds/main.world');
    if (!mounted) return;
    setState(() {
      _world = World.parse(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_world == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    return WorldCanvas(world: _world);
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
    Offset worldOrigin = Offset(
      size.width / 2.0 - (world.playerX + 0.5) * cellSize.width,
      size.height / 2.0 - (world.playerY + 0.5) * cellSize.height,
    );

    for (int y = 0; y < world.height; y += 1) {
      for (int x = 0; x < world.width; x += 1) {
        paintCell(
            canvas,
            cellSize,
            worldOrigin + Offset(x * cellSize.width, y * cellSize.height),
            world.at(x, y));
      }
    }
    paintPerson(canvas, cellSize,
        size.center(Offset.zero) - cellSize.center(Offset.zero));
  }

  void paintCell(Canvas canvas, Size cellSize, Offset cellOrigin, Cell cell) {
    canvas.drawRect(
      (cellOrigin & cellSize).deflate(2.0),
      Paint()..color = cell is Goal ? Colors.green : Colors.blue,
    );
  }

  Color cellColor(Cell cell) {
    switch (cell.runtimeType) {
      case Empty:
        return Colors.blue;
      case Goal:
        return Colors.green;
      case Tree:
        return Colors.black;
      default:
        throw UnimplementedError("Unknown ${cell.runtimeType}");
    }
  }

  void paintPerson(Canvas canvas, Size cellSize, Offset cellOrigin) {
    canvas.drawCircle(
      cellSize.center(cellOrigin),
      cellSize.shortestSide / 2.0,
      Paint()..color = Colors.yellow,
    );
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) => world != oldDelegate.world;
}
