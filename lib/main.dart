import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      home: GamePage(source: WorldSource()),
    );
  }
}

@immutable
class WorldSource {
  Future<World> initWorld() async {
    String data = await rootBundle.loadString('worlds/main.world');
    return World.parse(data);
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key key, this.source}) : super(key: key);

  final WorldSource source;

  @override
  _GamePageState createState() => _GamePageState();
}

@immutable
class CellState {
  const CellState(this.color);

  factory CellState.fromCell(Cell cell) {
    switch (cell.runtimeType) {
      case Null:
        return CellState(Colors.black);
      case Empty:
        return CellState(Colors.blue);
      case Goal:
        return CellState(Colors.green);
      case Tree:
        return CellState(Colors.black);
      default:
        throw UnimplementedError("Unknown ${cell.runtimeType}");
    }
  }

  final Color color;
}

@immutable
class WorldState {
  const WorldState(this.width, this.grid, this.offset);

  factory WorldState.fromWorld(World world) {
    return WorldState(
      world.width,
      world.cells
          .map<CellState>((Cell cell) => CellState.fromCell(cell))
          .toList(),
      Offset(world.playerX + 0.5, world.playerY + 0.5),
    );
  }

  final int width;
  int get height => grid.length ~/ width;
  final List<CellState> grid;
  final Offset offset;
}

class _GamePageState extends State<GamePage> {
  World _world;

  WorldState _currentFrame;

  @override
  void initState() {
    super.initState();
    _initWorld();
  }

  @override
  void didUpdateWidget(GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) _initWorld();
  }

  void _initWorld() {
    final WorldSource source = widget.source;
    source.initWorld().then((World value) {
      if (mounted && (widget.source == source)) {
        _world = value;
        _updateWorldState();
      }
    });
  }

  void _updateWorldState() {
    setState(() {
      _currentFrame = WorldState.fromWorld(_world);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_world == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    return WorldCanvas(world: _currentFrame);
  }
}

class WorldCanvas extends StatefulWidget {
  WorldCanvas({Key key, this.world}) : super(key: key);

  final WorldState world;

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

  final WorldState world;

  static const Size cellSize = Size(60.0, 60.0);

  @override
  void paint(Canvas canvas, Size size) {
    Offset worldOrigin = Offset(
      size.width / 2.0 - (world.offset.dx) * cellSize.width,
      size.height / 2.0 - (world.offset.dy) * cellSize.height,
    );

    for (int y = 0; y < world.height; y += 1) {
      for (int x = 0; x < world.width; x += 1) {
        paintCell(
          canvas,
          cellSize,
          worldOrigin + Offset(x * cellSize.width, y * cellSize.height),
          world.grid[x + y * world.width],
        );
      }
    }
    paintPerson(
      canvas,
      cellSize,
      size.center(Offset.zero) - cellSize.center(Offset.zero),
    );
  }

  void paintCell(
      Canvas canvas, Size cellSize, Offset cellOrigin, CellState cell) {
    canvas.drawRect(
      (cellOrigin & cellSize).deflate(2.0),
      Paint()..color = cell.color,
    );
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
