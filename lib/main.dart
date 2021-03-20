import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Threshold;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'world.dart';

Future<String> loader(String name) =>
    rootBundle.loadString('worlds/$name.world');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WorldSource source = WorldSource(loader);
  runApp(Container(
    child: ForestVenture(source: source),
    color: Colors.black,
  ));
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

@immutable
class CellState {
  const CellState(this.backgroundColor);
  factory CellState.fromCell(Cell cell) {
    switch (cell.runtimeType) {
      case Null:
        return CellState(Colors.black.withAlpha(50));
      case Empty:
      case Threshold:
        return CellState(Colors.brown.withAlpha(50));
      case Goal:
        return GoalCellState();
      case Tree:
        return TreeCellState();
      case OneWay:
        return ArrowCellState((cell as OneWay).dir);
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

class GoalCellState extends CellState {
  GoalCellState() : super(Colors.brown.withAlpha(50));
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    canvas.drawOval(cellOrigin & cellSize, Paint()..color = Colors.black);
    canvas.drawOval(cellOrigin & cellSize, Paint()..style = PaintingStyle.stroke..color=Colors.green);
  }
}

class ArrowCellState extends CellState {
  ArrowCellState(this.dir) : super(Colors.brown.withAlpha(50));
  final Direction dir;

  @override
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    Path p = Path();
    p.moveTo(cellOrigin.dx, cellOrigin.dy);
    p.lineTo(
      cellOrigin.dx + cellSize.width,
      cellOrigin.dy + (cellSize.height / 2),
    );
    p.lineTo(cellOrigin.dx, cellOrigin.dy + cellSize.height);
    Offset center = cellSize.center(cellOrigin);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    var radians = dir.toRadians();
    canvas.rotate(radians);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(
      p,
      ((Paint()..color = Colors.orange)..style = PaintingStyle.stroke)
        ..strokeWidth = 5,
    );
    canvas.restore();
  }
}

class TreeCellState extends CellState {
  TreeCellState() : super(Colors.brown.withAlpha(50));

  @override
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    /*
    Rect treeRect = (cellOrigin & cellSize).deflate(cellSize.longestSide * 0.1);
    canvas.drawPath(
      Path()
        ..addPath(_triangle(Size(treeRect.width, treeRect.height * 0.75)),
            treeRect.topLeft),
      Paint()..color = Colors.green[900],
    );
    canvas.drawRect(
      Rect.fromLTWH(
          treeRect.left + treeRect.width * 0.4,
          treeRect.top + treeRect.height * 0.75,
          treeRect.width * 0.2,
          treeRect.height * 0.25),
      Paint()..color = Colors.brown[800],
    );
    */
    canvas.drawCircle(
      cellSize.center(cellOrigin),
      cellSize.width / 2,
      Paint()..color = Colors.green.withAlpha(50),
    );
  }
  /*
  static Path _triangle(Size cellSize) {
    return Path()
      ..moveTo(0.5 * cellSize.width, 0)
      ..lineTo(cellSize.width, cellSize.height)
      ..lineTo(0, cellSize.height);
  }
  */
}

@immutable
abstract class WorldState {
  const WorldState();

  String get message;

  void paint(Canvas canvas, Size size, Size cellSize);

  WorldState lerpTo(covariant WorldState b, double t);
  WorldState lerpEnd() => this;

  static WorldState lerp(WorldState a, WorldState b, double t) {
    assert(t != null);
    assert(a != null);
    assert(b != null);
    if (t == 0.0) {
      return a;
    }
    if (t == 1.0) {
      return b.lerpEnd();
    }
    if (b.runtimeType == a.runtimeType) return a.lerpTo(b, t);
    return MultiWorldState.lerp(a, b, t);
  }
}

class ActiveWorldState extends WorldState {
  const ActiveWorldState(
    this.name,
    this.width,
    this.grid,
    this.offset,
    this.message,
  );

  factory ActiveWorldState.fromWorld(World world) {
    return ActiveWorldState(
      world.name,
      world.width,
      world.cells
          .map<CellState>((Cell cell) => CellState.fromCell(cell))
          .toList(),
      Offset(world.playerX + 0.5, world.playerY + 0.5),
      world.currentMessage,
    );
  }

  final String name;
  final int width;
  int get height => grid.length ~/ width;
  final List<CellState> grid;
  final Offset offset;

  @override
  final String message;

  @override
  void paint(Canvas canvas, Size size, Size cellSize) {
    Offset worldOrigin = Offset(
      size.width / 2.0 - (offset.dx) * cellSize.width,
      size.height / 2.0 - (offset.dy) * cellSize.height,
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    for (int y = 0; y < height; y += 1) {
      for (int x = 0; x < width; x += 1) {
        grid[x + y * width].paint(
          canvas,
          cellSize,
          worldOrigin + Offset(x * cellSize.width, y * cellSize.height),
        );
      }
    }
    _paintPerson(
      canvas,
      cellSize,
      size.center(Offset.zero) - cellSize.center(Offset.zero),
    );
  }

  void _paintPerson(Canvas canvas, Size cellSize, Offset cellOrigin) {
    canvas.drawCircle(
      cellSize.center(cellOrigin),
      cellSize.shortestSide / 2.0,
      Paint()..color = Colors.yellow,
    );
  }

  WorldState lerpTo(ActiveWorldState b, double t) {
    if (name == b.name) {
      assert(width == b.width);
      return ActiveWorldState(
        b.name,
        b.width,
        b.grid, // TODO(ianh): lerp grid
        Offset.lerp(offset, b.offset, t),
        b.message, // message is animated by the message UI
      );
    }
    return MultiWorldState.lerp(this, b, t);
  }
}

class EmptyWorldState extends WorldState {
  const EmptyWorldState();

  String get message => 'Loading...';

  @override
  void paint(Canvas canvas, Size size, Size cellSize) {}

  WorldState lerpTo(EmptyWorldState b, double t) {
    return b;
  }
}

class MultiWorldState extends WorldState {
  MultiWorldState(this.worlds, this.ts) {
    assert(worlds.isNotEmpty);
    assert(worlds.length == ts.length);
    assert(!worlds.any((WorldState child) => child is MultiWorldState));
  }

  String get message => '';

  final List<WorldState> worlds;
  final List<double> ts;

  @override
  void paint(Canvas canvas, Size size, Size cellSize) {
    for (int index = 0; index < worlds.length; index += 1) {
      final WorldState world = worlds[index];
      final double t = ts[index];
      final int alpha = (0xFF * t).round();
      if (alpha > 0x00) {
        canvas.saveLayer(
          null,
          Paint()
            ..colorFilter =
                ColorFilter.mode(Color(alpha << 24), BlendMode.dstATop),
        );
        world.paint(canvas, size, cellSize);
        canvas.restore();
      }
    }
  }

  @override
  WorldState lerpTo(MultiWorldState b, double t) {
    throw UnimplementedError();
  }

  MultiWorldState add(WorldState b, double t) {
    assert(b is! MultiWorldState);
    assert(t != 0.0);
    assert(t != 1.0);
    WorldState last = WorldState.lerp(worlds.last, b, t);
    if (last is MultiWorldState) {
      // need to actually add next one
      return MultiWorldState(
        worlds.followedBy(<WorldState>[b]).toList(),
        ts.map((double t0) => t0 * (1.0 - t)).followedBy(<double>[t]).toList(),
      );
    }
    // next one got merged into last one, so just replace the last one
    return MultiWorldState(
      worlds.take(worlds.length - 1).followedBy(<WorldState>[last]).toList(),
      ts
          .take(ts.length - 1)
          .map((double t0) => t0 * (1.0 - t))
          .followedBy(<double>[t]).toList(),
    );
  }

  @override
  WorldState lerpEnd() => worlds.last;

  static MultiWorldState lerp(WorldState a, WorldState b, double t) {
    assert(t != null);
    assert(a != null);
    assert(b != null);
    assert(t != 0.0);
    assert(t != 1.0);
    if (a is MultiWorldState) {
      assert(b is! MultiWorldState);
      return a.add(b, t);
    }
    if (b is MultiWorldState) {
      assert(a is! MultiWorldState);
      return MultiWorldState(
        <WorldState>[a, ...b.worlds],
        <double>[1.0 - t, ...b.ts.map((double t0) => t0 * t)],
      );
    }
    assert(a is! MultiWorldState);
    assert(b is! MultiWorldState);
    return MultiWorldState(<WorldState>[a, b], <double>[1.0 - t, t]);
  }

  String toString() => '<$worlds@$ts>';
}

class WorldStateTween extends Tween<WorldState> {
  WorldStateTween({WorldState begin, WorldState end})
      : super(begin: begin, end: end);

  WorldState lerp(double t) {
    return WorldState.lerp(begin, end, t);
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key key, this.source}) : super(key: key);

  final WorldSource source;

  @override
  _GamePageState createState() => _GamePageState();
}

enum MoveDirection { left, up, right, down }

class MoveIntent extends Intent {
  const MoveIntent(this.direction);
  final MoveDirection direction;
}

class _GamePageState extends State<GamePage> {
  World _world;
  WorldState _currentFrame;
  MoveDirection /*?*/ _pendingDirection;
  bool _animating = false;

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
      _animating = _currentFrame != null;
      _currentFrame = _world == null
          ? const EmptyWorldState()
          : ActiveWorldState.fromWorld(_world);
    });
  }

  void _handleAnimationEnd() {
    _animating = false;
    if (_pendingDirection != null) {
      switch (_pendingDirection) {
        case MoveDirection.left:
          _world?.left();
          break;
        case MoveDirection.up:
          _world?.up();
          break;
        case MoveDirection.right:
          _world?.right();
          break;
        case MoveDirection.down:
          _world?.down();
          break;
      }
      _pendingDirection = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(_currentFrame != null);
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // WASD
        LogicalKeySet(LogicalKeyboardKey.keyW):
            const MoveIntent(MoveDirection.up),
        LogicalKeySet(LogicalKeyboardKey.keyA):
            const MoveIntent(MoveDirection.left),
        LogicalKeySet(LogicalKeyboardKey.keyS):
            const MoveIntent(MoveDirection.down),
        LogicalKeySet(LogicalKeyboardKey.keyD):
            const MoveIntent(MoveDirection.right),
        // Dvorak WASD (A is the same as above)
        LogicalKeySet(LogicalKeyboardKey.comma):
            const MoveIntent(MoveDirection.up),
        LogicalKeySet(LogicalKeyboardKey.keyO):
            const MoveIntent(MoveDirection.down),
        LogicalKeySet(LogicalKeyboardKey.keyE):
            const MoveIntent(MoveDirection.right),
        // Arrow keys
        LogicalKeySet(LogicalKeyboardKey.arrowUp):
            const MoveIntent(MoveDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const MoveIntent(MoveDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            const MoveIntent(MoveDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const MoveIntent(MoveDirection.right),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          MoveIntent: CallbackAction<MoveIntent>(onInvoke: (MoveIntent intent) {
            _pendingDirection = intent.direction;
            if (!_animating) {
              _handleAnimationEnd();
            }
            return null;
          }),
        },
        child: Builder(
          builder: (BuildContext context) {
            return Focus(
              autofocus: true,
              child: AnimatedWorldCanvas(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeIn,
                world: _currentFrame,
                onEnd: _handleAnimationEnd,
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
                          child: InkWell(onTap: () {
                            Actions.invoke(
                                context, MoveIntent(MoveDirection.up));
                          }),
                        )),
                    ClipPath(
                      clipper: PolygonClipper(<Offset>[
                        Offset(1.0, 0.0),
                        Offset(1.0, 1.0),
                        Offset(0.5, 0.5),
                      ]),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: () {
                          Actions.invoke(
                              context, MoveIntent(MoveDirection.right));
                        }),
                      ),
                    ),
                    ClipPath(
                      clipper: PolygonClipper(<Offset>[
                        Offset(1.0, 1.0),
                        Offset(0.0, 1.0),
                        Offset(0.5, 0.5),
                      ]),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: () {
                          Actions.invoke(
                              context, MoveIntent(MoveDirection.down));
                        }),
                      ),
                    ),
                    ClipPath(
                      clipper: PolygonClipper(<Offset>[
                        Offset(0.0, 1.0),
                        Offset(0.0, 0.0),
                        Offset(0.5, 0.5),
                      ]),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: () {
                          Actions.invoke(
                              context, MoveIntent(MoveDirection.left));
                        }),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _world?.reset(),
                              child: Container(
                                color: Color(0x7F000000),
                                child: Text(
                                  "Reset Level",
                                  style: TextStyle(fontSize: 10, height: 1),
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                    Positioned(
                      bottom: 32.0,
                      left: 0.0,
                      right: 0.0,
                      child: IgnorePointer(
                        child: AnimatedSwitcher(
                          layoutBuilder: (
                            Widget currentChild,
                            List<Widget> previousChildren,
                          ) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          child: _currentFrame.message.isEmpty
                              ? SizedBox.shrink()
                              : Container(
                                  key: Key(_currentFrame.message),
                                  padding: EdgeInsets.all(24.0),
                                  decoration: ShapeDecoration(
                                    shape: StadiumBorder(),
                                    color: const Color(0x7F000000),
                                  ),
                                  child: Text(
                                    _currentFrame.message,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      inherit: false,
                                      fontSize: 40.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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

class AnimatedWorldCanvas extends ImplicitlyAnimatedWidget {
  AnimatedWorldCanvas({
    Key key,
    this.world,
    Curve curve: Curves.linear,
    @required Duration duration,
    VoidCallback onEnd,
    this.child,
  }) : super(key: key, curve: curve, duration: duration, onEnd: onEnd);

  final WorldState world;
  final Widget child;

  @override
  _AnimatedWorldCanvasState createState() => _AnimatedWorldCanvasState();
}

class _AnimatedWorldCanvasState
    extends AnimatedWidgetBaseState<AnimatedWorldCanvas> {
  Tween<WorldState> _world;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _world = visitor(
      _world,
      widget.world,
      (dynamic value) => WorldStateTween(begin: widget.world),
    ) as Tween<WorldState>;
  }

  @override
  Widget build(BuildContext context) {
    return WorldCanvas(
      world: _world.evaluate(animation),
      child: widget.child,
    );
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
    world.paint(canvas, size, cellSize);
  }

  @override
  bool shouldRepaint(_WorldPainter oldDelegate) => world != oldDelegate.world;
}
