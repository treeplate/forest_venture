import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Threshold;
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
  ForestVenture({Key? key, required this.source}) : super(key: key);
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
  factory CellState.fromCell(Cell? cell) {
    switch (cell.runtimeType) {
      case Null:
        return CellState(Colors.black.withAlpha(50));
      case Empty:
      case Threshold:
        return CellState(Colors.brown.withAlpha(50));
      case PlayerGoal:
        return PlayerGoalCellState();
      case BoxGoal:
        return BoxGoalCellState();
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

class BoxGoalCellState extends CellState {
  BoxGoalCellState() : super(Colors.brown.withAlpha(50));
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    canvas.drawRect(cellOrigin & cellSize, Paint()..color = Colors.black);
    canvas.drawRect(
      cellOrigin & cellSize,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.green,
    );
  }
}

class PlayerGoalCellState extends CellState {
  PlayerGoalCellState() : super(Colors.brown.withAlpha(50));
  void paint(Canvas canvas, Size cellSize, Offset cellOrigin) {
    super.paint(canvas, cellSize, cellOrigin);
    canvas.drawOval(cellOrigin & cellSize, Paint()..color = Colors.black);
    canvas.drawOval(
        cellOrigin & cellSize,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.green);
  }
}

class TreeObjectState extends ObjectState {
  TreeObjectState(Offset position, SolidObject source)
      : super(position, source);

  @override
  void paint(Canvas canvas, Size cellSize, Offset gridOrigin) {
    Offset cellOrigin =
        (position.scale(cellSize.width, cellSize.height)) + gridOrigin;

    Rect treeRect = (cellOrigin & cellSize).deflate(cellSize.longestSide * 0.1);
    canvas.drawPath(
      Path()
        ..addPath(_triangle(Size(treeRect.width, treeRect.height * 0.75)),
            treeRect.topLeft),
      Paint()..color = Colors.green[900]!,
    );
    canvas.drawRect(
      Rect.fromLTWH(
          treeRect.left + treeRect.width * 0.4,
          treeRect.top + treeRect.height * 0.75,
          treeRect.width * 0.2,
          treeRect.height * 0.25),
      Paint()..color = Colors.brown[800]!,
    );
  }

  static Path _triangle(Size cellSize) {
    return Path()
      ..moveTo(0.5 * cellSize.width, 0)
      ..lineTo(cellSize.width, cellSize.height)
      ..lineTo(0, cellSize.height);
  }

  @override
  ObjectState lerpTo(ObjectState b, double t) {
    assert(b is TreeObjectState);
    return TreeObjectState(Offset.lerp(position, b.position, t)!, source);
  }
}

@immutable
abstract class WorldState {
  const WorldState();

  String get message;

  void paint(Canvas canvas, Size size, Size cellSize, {bool cloneMode});

  WorldState lerpTo(covariant WorldState b, double t);
  WorldState lerpEnd() => this;

  static WorldState lerp(WorldState a, WorldState b, double t) {
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
  final Room room;
  final int nesting;

  const ActiveWorldState(
    this.name,
    this.width,
    this.grid,
    this.objects,
    this.message,
    this.room,
    this.nesting,
  );

  factory ActiveWorldState.fromWorld(World ttworld, int roomIndex) {
    return ActiveWorldState.fromRoom(
      ttworld,
      ttworld.rooms[roomIndex],
      0,
    );
  }

  factory ActiveWorldState.fromRoom(
    World ttworld,
    Room world,
    int nesting,
  ) {
    return ActiveWorldState(
      ttworld.name,
      world.width,
      world.cells
          .map<CellState>((Cell? cell) => CellState.fromCell(cell))
          .toList(),
      ttworld.objects
          .where((element) => element.position.room == world)
          .map<ObjectState>((SolidObject? cell) =>
              ObjectState.fromObject(cell, ttworld, nesting))
          .toList(),
      ttworld.currentMessage,
      world,
      nesting,
    );
  }

  final String name;
  final int width;
  int get height => grid.length ~/ width;
  final List<CellState> grid;
  final List<ObjectState> objects;

  @override
  final String message;

  @override
  void paint(Canvas canvas, Size size, Size cellSize,
      {bool cloneMode = false}) {
    Offset worldOrigin = Offset(
      (size.width / 2.0) - (width / 2 * cellSize.width),
      (size.height / 2.0) - (height / 2 * cellSize.height),
    );
    canvas.drawRect(Offset.zero & size,
        Paint()..color = cloneMode ? Colors.blueGrey : Colors.black);
    for (int y = 0; y < height; y += 1) {
      for (int x = 0; x < width; x += 1) {
        grid[x + y * width].paint(
          canvas,
          cellSize,
          worldOrigin + Offset(x * cellSize.width, y * cellSize.height),
        );
      }
    }
    _paintObjects(canvas, cellSize, worldOrigin);
  }

  void _paintObjects(Canvas canvas, Size cellSize, Offset worldOrigin) {
    for (ObjectState objectState in objects) {
      objectState.paint(canvas, cellSize, worldOrigin);
    }
  }

  WorldState lerpTo(ActiveWorldState b, double t) {
    if (room == b.room) {
      assert(width == b.width);
      assert(name == b.name);
      assert(nesting == b.nesting);
      return ActiveWorldState(
        b.name,
        b.width,
        b.grid,
        lerpObjects(objects, b.objects, t).toList(),
        b.message, // message is animated by the message UI
        b.room,
        b.nesting,
      );
    }
    return MultiWorldState.lerp(this, b, t);
  }
}

Iterable<ObjectState> lerpObjects(
    List<ObjectState> a, List<ObjectState> b, double t) sync* {
  List<ObjectState> bR = b.toList();
  for (ObjectState aO in a) {
    ObjectState? match;
    for (ObjectState bO in bR) {
      if (bO.source == aO.source) {
        yield aO.lerpTo(bO, t);
        match = bO;
        break;
      }
    }
    if (match == null) {
      yield aO;
    } else {
      bR.remove(match);
    }
  }
  yield* bR;
}

abstract class ObjectState {
  ObjectState(this.position, this.source); // for subclasses
  final Offset position;
  final SolidObject source;

  void paint(Canvas canvas, Size size, Offset gridOrigin);

  factory ObjectState.fromObject(SolidObject? cell, World world, int nesting) {
    // for conversion from SolidObject
    switch (cell.runtimeType) {
      case Player:
        return PlayerObjectState(cell!.position.toOffset(), cell as Player);
      case Box:
        return BoxObjectState(cell!.position.toOffset(), cell);
      case Tree:
        return TreeObjectState(cell!.position.toOffset(), cell);
      case Portal:
        return PortalObjectState(
            cell!.position.toOffset(), cell as Portal, world, nesting);
      case FullPortal:
        return PortalObjectState(
            cell!.position.toOffset(), cell as Portal, world, nesting);
      default:
        throw StateError("Unrecognized ${cell.runtimeType} cell");
    }
  }

  static ObjectState lerp(ObjectState a, ObjectState b, double t) {
    return a.lerpTo(b, t);
  }

  ObjectState lerpTo(ObjectState b, double t);
}

class PortalObjectState extends ObjectState {
  final WorldState? worldState;
  final World world;

  final int nesting;

  PortalObjectState(Offset position, Portal source, this.world, this.nesting,
      [WorldState? worldState])
      : worldState = worldState ??
            (nesting < 3
                ? ActiveWorldState.fromRoom(
                    world,
                    world.rooms[source.roomIndex],
                    nesting + 1,
                  )
                : null),
        super(position, source);

  @override
  ObjectState lerpTo(ObjectState b, double t) {
    assert(b is PortalObjectState);
    if (worldState != null) {
      WorldState nws = worldState!.lerpTo(
        (b as PortalObjectState).worldState!,
        t,
      );
      return PortalObjectState(Offset.lerp(position, b.position, t)!,
          source as Portal, world, (nws as ActiveWorldState).nesting, nws);
    } else {
      return PortalObjectState(Offset.lerp(position, b.position, t)!,
          source as Portal, world, nesting, null);
    }
  }

  @override
  void paint(Canvas canvas, Size size, Offset gridOrigin) {
    canvas.drawRect(
        (Offset(position.dx * size.width, position.dy * size.height) +
                    gridOrigin) -
                Offset(1, 1) &
            size + Offset(2, 2),
        Paint()..color = Colors.blue);
    if (worldState != null) {
      canvas.save();
      canvas.translate(
        gridOrigin.dx + (size.width * position.dx),
        gridOrigin.dy + (size.height * position.dy),
      );
      worldState!.paint(canvas, size,
          size / (world.rooms[(source as Portal).roomIndex].width / 1),
          cloneMode: source is! FullPortal);
      canvas.restore();
    }
  }
}

class BoxObjectState extends ObjectState {
  BoxObjectState(Offset position, SolidObject source) : super(position, source);

  @override
  ObjectState lerpTo(ObjectState b, double t) {
    assert(b is BoxObjectState);
    return BoxObjectState(Offset.lerp(position, b.position, t)!, source);
  }

  @override
  void paint(Canvas canvas, Size size, Offset gridOrigin) {
    Offset cellOrigin = (position.scale(size.width, size.height)) + gridOrigin;
    canvas.drawRect(cellOrigin & size, Paint()..color = Colors.blue);
  }
}

class PlayerObjectState extends ObjectState {
  PlayerObjectState(Offset position, Player source) : super(position, source);

  @override
  void paint(Canvas canvas, Size size, Offset gridOrigin) {
    Offset cellOrigin = (position.scale(size.width, size.height)) + gridOrigin;
    canvas.drawCircle(cellOrigin + (size / 2).bottomRight(Offset.zero),
        size.width / 2, Paint()..color = Colors.yellow);
  }

  @override
  ObjectState lerpTo(ObjectState b, double t) {
    assert(b is PlayerObjectState);
    return PlayerObjectState(
        Offset.lerp(position, b.position, t)!, source as Player);
  }
}

class EmptyWorldState extends WorldState {
  const EmptyWorldState();

  String get message => 'Loading...';

  @override
  void paint(Canvas canvas, Size size, Size cellSize, {bool? cloneMode}) {}

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
  void paint(Canvas canvas, Size size, Size cellSize,
      {bool cloneMode = false}) {
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
        world.paint(canvas, size, cellSize, cloneMode: cloneMode);
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
  WorldStateTween({required WorldState begin, WorldState? end})
      : super(begin: begin, end: end);

  WorldState lerp(double t) {
    return WorldState.lerp(begin!, end!, t);
  }
}

class GamePage extends StatefulWidget {
  GamePage({Key? key, required this.source}) : super(key: key);

  final WorldSource source;

  @override
  _GamePageState createState() => _GamePageState();
}

enum MoveDirection { left, up, right, down }

class MoveIntent extends Intent {
  const MoveIntent(this.direction, this.player);
  final MoveDirection direction;
  final int player;
}

class ResetIntent extends Intent {
  const ResetIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class NextRoomIntent extends Intent {
  const NextRoomIntent();
}

class PrevRoomIntent extends Intent {
  const PrevRoomIntent();
}

class _GamePageState extends State<GamePage> {
  World? _world;
  WorldState? _currentFrame;
  MoveDirection? _pendingDirection;
  int _roomIndex = 0;
  bool _animating = false;

  int? _pendingMovingPlayer;

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
    _roomIndex = 0;
    _handleWorldUpdate();
  }

  void _handleWorldUpdate() {
    setState(() {
      _animating = _currentFrame != null;

      _currentFrame = _world == null
          ? const EmptyWorldState()
          : ActiveWorldState.fromWorld(_world!, _roomIndex);
    });
  }

  void _handleAnimationEnd() {
    _animating = false;
    if (_pendingDirection != null) {
      Player? player =
          _world?.objects.whereType<Player>().toList()[_pendingMovingPlayer!];
      switch (_pendingDirection!) {
        case MoveDirection.left:
          _world?.left(player!);
          break;
        case MoveDirection.up:
          _world?.up(player!);
          break;
        case MoveDirection.right:
          _world?.right(player!);
          break;
        case MoveDirection.down:
          _world?.down(player!);
          break;
      }
      _pendingDirection = null;
      _pendingMovingPlayer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(_currentFrame != null);
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // WASD
        LogicalKeySet(LogicalKeyboardKey.keyW): const MoveIntent(
          MoveDirection.up,
          0,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyA): const MoveIntent(
          MoveDirection.left,
          0,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyS): const MoveIntent(
          MoveDirection.down,
          0,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyD): const MoveIntent(
          MoveDirection.right,
          0,
        ),
        // Dvorak WASD (A is the same as above)
        LogicalKeySet(LogicalKeyboardKey.comma): const MoveIntent(
          MoveDirection.up,
          0,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyO): const MoveIntent(
          MoveDirection.down,
          0,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyE): const MoveIntent(
          MoveDirection.right,
          0,
        ),
        // Arrow keys
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const MoveIntent(
          MoveDirection.up,
          1,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const MoveIntent(
          MoveDirection.left,
          1,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const MoveIntent(
          MoveDirection.down,
          1,
        ),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const MoveIntent(
          MoveDirection.right,
          1,
        ),
        LogicalKeySet(LogicalKeyboardKey.keyR): const ResetIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyZ): const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyQ): const PrevRoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyE): const NextRoomIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          MoveIntent: CallbackAction<MoveIntent>(onInvoke: (MoveIntent intent) {
            _pendingDirection = intent.direction;
            _pendingMovingPlayer = intent.player;
            if (!_animating) {
              _handleAnimationEnd();
            }
            return null;
          }),
          ResetIntent:
              CallbackAction<ResetIntent>(onInvoke: (ResetIntent intent) {
            _world?.reset();
            if (!_animating) {
              _handleAnimationEnd();
            }
            return null;
          }),
          UndoIntent: CallbackAction<UndoIntent>(onInvoke: (UndoIntent intent) {
            if (!_animating) {
              _handleAnimationEnd();
            }
            _world?.undo();
            return null;
          }),
          PrevRoomIntent:
              CallbackAction<PrevRoomIntent>(onInvoke: (PrevRoomIntent intent) {
            if (_roomIndex == 0) {
              _roomIndex = _world?.rooms.length ?? 1;
            }
            _roomIndex--;
            if (!_animating) {
              _handleAnimationEnd();
            }
            _handleWorldUpdate();
            return null;
          }),
          NextRoomIntent:
              CallbackAction<NextRoomIntent>(onInvoke: (NextRoomIntent intent) {
            _roomIndex++;
            if (_roomIndex == (_world?.rooms.length ?? 1)) {
              _roomIndex = 0;
            }
            if (!_animating) {
              _handleAnimationEnd();
            }
            _handleWorldUpdate();
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
                world: _currentFrame!,
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
                                context, MoveIntent(MoveDirection.up, 0));
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
                              context, MoveIntent(MoveDirection.right, 0));
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
                              context, MoveIntent(MoveDirection.down, 0));
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
                              context, MoveIntent(MoveDirection.left, 0));
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
                            Widget? currentChild,
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
                          child: _currentFrame!.message.isEmpty
                              ? SizedBox.shrink()
                              : Container(
                                  key: Key(_currentFrame!.message),
                                  padding: EdgeInsets.all(24.0),
                                  decoration: ShapeDecoration(
                                    shape: StadiumBorder(),
                                    color: const Color(0x7F000000),
                                  ),
                                  child: Text(
                                    _currentFrame!.message,
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
    Key? key,
    required this.world,
    Curve curve: Curves.linear,
    required Duration duration,
    required VoidCallback onEnd,
    required this.child,
  }) : super(key: key, curve: curve, duration: duration, onEnd: onEnd);

  final WorldState world;
  final Widget child;

  @override
  _AnimatedWorldCanvasState createState() => _AnimatedWorldCanvasState();
}

class _AnimatedWorldCanvasState
    extends AnimatedWidgetBaseState<AnimatedWorldCanvas> {
  Tween<WorldState>? _world;

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
      world: _world!.evaluate(animation),
      child: widget.child,
    );
  }
}

class WorldCanvas extends StatefulWidget {
  WorldCanvas({Key? key, required this.world, required this.child})
      : super(key: key);

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
