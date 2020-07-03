import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'world.dart';

Future<String> loader(String name) => rootBundle.loadString('worlds/$name.world');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WorldSource source = WorldSource(loader);
  runApp(ForestVenture(source: source));
}

class ForestVenture extends StatelessWidget {
  ForestVenture({Key key, this.source}) : super(key: key);

  final WorldSource source;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forest Venture',
      home: GamePage(source: source),
    );
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
  const CellState(this.backgroundColor);

  factory CellState.fromCell(Cell cell) {
    switch (cell.runtimeType) {
      case Null:
        return CellState(Colors.black.withAlpha(50));
      case Empty:
        return CellState(Colors.brown.withAlpha(50));
      case Goal:
        return CellState(Colors.green);
      case Tree:
        return TreeCellState();
      case OneWay:
        return CharCellState("$cell");
      default:
        throw UnimplementedError("Unknown ${cell.runtimeType}");
    }
  }

  final Color backgroundColor;

  @mustCallSuper
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    canvas.drawRect(
      (cellOrigin & cellSize).deflate(2.0),
      Paint()..color = backgroundColor,
    );
  }
}

class CharCellState extends CellState {
  CharCellState(this.label) : super(Colors.red);
  final String label;

  @override
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    // TODO(ianh): Cache the TextPainter.
    TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: cellSize.shortestSide, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )
    ..layout()
    ..paint(canvas, cellOrigin);
  }
}

class TreeCellState extends CellState {
  TreeCellState() : super(Colors.green[200].withAlpha(50));

  @override
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    canvas.drawPath(
      Path()..addPath(_treeShape(cellSize), cellOrigin),
      Paint()..color = Colors.green.withAlpha(50),
    );
  }

  static Path _treeShape(Size cellSize) {
    return Path()
      ..moveTo(0.5 * cellSize.width, 0)
      ..lineTo(cellSize.width, cellSize.height)
      ..lineTo(0, cellSize.height);
  }
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
    widget.source.addListener(_handleSourceUpdate);
    _handleSourceUpdate();
  }

  @override
  void didUpdateWidget(GamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      oldWidget.source.removeListener(_handleSourceUpdate);
      widget.source.addListener(_handleSourceUpdate);
      _handleSourceUpdate();
    }
  }

  @override
  void dispose() {
    widget.source.removeListener(_handleSourceUpdate);
    _world?.removeListener(_handleWorldUpdate);
    super.dispose();
  }

  void _handleSourceUpdate() {
    _world?.removeListener(_handleWorldUpdate);
    _world = widget.source.currentWorld;
    _world?.addListener(_handleWorldUpdate);
    _handleWorldUpdate();
  }

  void _handleWorldUpdate() {
    setState(() {
      _currentFrame = _world == null ? null : WorldState.fromWorld(_world);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_world == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    return WorldCanvas(
      world: _currentFrame,
      child: Stack(
        children: <Widget>[
          ClipPath(
              clipper: PolygonClipper(<Offset>[
                Offset(0.0, 0.0),
                Offset(1.0, 0.0),
                Offset(0.5, 0.5)
              ]),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: _world?.up),
              )),
          ClipPath(
            clipper: PolygonClipper(
                <Offset>[Offset(1.0, 0.0), Offset(1.0, 1.0), Offset(0.5, 0.5),]),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _world?.right),
            ),
          ),
          ClipPath(
            clipper: PolygonClipper(
                <Offset>[Offset(1.0, 1.0), Offset(0.0, 1.0), Offset(0.5, 0.5),]),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _world?.down),
            ),
          ),
          ClipPath(
            clipper: PolygonClipper(
                <Offset>[Offset(0.0, 1.0), Offset(0.0, 0.0), Offset(0.5, 0.5),]),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _world?.left),
            ),
          ),
        ],
      ),
    );
  }
}

class PolygonClipper extends CustomClipper<Path> {
  PolygonClipper(this.points) : assert(points.length >= 3);

  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final Path path = Path()
      ..moveTo(size.width * points.first.dx, size.height * points.first.dy);
    for (Offset offset in points.skip(1))
      path.lineTo(size.width * offset.dx, size.height * offset.dy);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(PolygonClipper oldClipper) {
    return listEquals<Offset>(oldClipper.points, points);
  }
}

class WorldCanvas extends StatefulWidget {
  WorldCanvas({Key key, this.world, this.child}) : super(key: key);

  final WorldState world;

  final Widget child;

  @override
  _WorldCanvasState createState() => _WorldCanvasState();
}

class _WorldCanvasState extends State<WorldCanvas> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WorldPainter(widget.world),
      child: widget.child,
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
        world.grid[x + y * world.width].paint(
          canvas,
          cellSize,
          worldOrigin + Offset(x * cellSize.width, y * cellSize.height),
        );
      }
    }
    paintPerson(
      canvas,
      cellSize,
      size.center(Offset.zero) - cellSize.center(Offset.zero),
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
