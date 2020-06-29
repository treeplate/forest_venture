import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
      home: GamePage(source: WorldSource("main")),
    );
  }
}

@immutable
class WorldSource {
  WorldSource(this.name);
  final String name;
  Future<World> initWorld() async {
    print('file is l2: ${name == 'l2'} ($name)');
    String data = await rootBundle.loadString('worlds/$name.world');
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
        return TreeCellState();
      case OneWay:
        return CharCellState("$cell");
      default:
        throw UnimplementedError("Unknown ${cell.runtimeType}");
    }
  }

  final Color color;
}

class CharCellState extends CellState {
  CharCellState(this.str) : super(Colors.red);
  final String str;
}

class TreeCellState extends CellState {
  TreeCellState() : super(Colors.green[200]);
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
        _world?.removeListener(_updateWorldState);
        _world = value;
        _world?.addListener(_updateWorldState);
        _updateWorldState();
      }
    });
  }

  void newWorld(String name) {
    print("newWorld('$name')");
    final WorldSource source = WorldSource(name);
    source.initWorld().then((World value) {
      if (mounted) {
        _world?.removeListener(_updateWorldState);
        _world = value;
        _world?.addListener(_updateWorldState);
        print("\nNew World:\n$_world");
        _updateWorldState();
      }
    });
  }

  @override
  void dispose() {
    _world?.removeListener(_updateWorldState);
    super.dispose();
  }

  void _updateWorldState() {
    if (_world?.at(_world.playerX, _world.playerY) is Goal) {
      print("world to: '" + _world.to + "'");
      newWorld(_world.to);
    }
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
                <Offset>[Offset(1.0, 0.0), Offset(1.0, 1.0), Offset(0.5, 0.5)]),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _world?.right),
            ),
          ),
          ClipPath(
            clipper: PolygonClipper(
                <Offset>[Offset(1.0, 1.0), Offset(0.0, 1.0), Offset(0.5, 0.5)]),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: _world?.down),
            ),
          ),
          ClipPath(
            clipper: PolygonClipper(
                <Offset>[Offset(0.0, 1.0), Offset(0.0, 0.0), Offset(0.5, 0.5)]),
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
    if (cell is TreeCellState) {
      canvas.drawPath(Path()..addPath(treeShape(cellSize), cellOrigin),
          Paint()..color = Colors.green);
    }
    if (cell is CharCellState) {
      print("Got ${cell.str}");
      canvas.drawParagraph(
          (Object t) {
            print(t);
            return t;
          }((ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 60))
                ..pushStyle(ui.TextStyle(color: Colors.green))
                ..addText(cell.str))
              .build()),
          cellOrigin);
    }
  }

  Path treeShape(Size cellSize) {
    Path result = Path();
    result.moveTo(0.5 * cellSize.width, 0);
    result.lineTo(cellSize.width, cellSize.height);
    result.lineTo(0, cellSize.height);
    return result;
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
