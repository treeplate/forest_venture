import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;

typedef DataLoader = Future<String> Function(String name);

class WorldSource extends ChangeNotifier {
  WorldSource(this.loader) {
    initWorld(startingLevel);
  }

  String get startingLevel => 'l1';

  final DataLoader? loader;

  World? _currentWorld;
  World? get currentWorld => _currentWorld;

  bool _disposed = false;

  Future<void> initWorld(String newName) async {
    assert(!_disposed);
    _currentWorld = null;
    notifyListeners();
    final String data = await loader!(newName);
    if (!_disposed) {
      _currentWorld = World.parse(data, this);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

int nc = 0;

class Room extends Object {
  final List<Cell> cells;
  final int width;
  Portal? holder;
  final List<SolidObject> objs;

  Dimensions get dimensions => Dimensions(width, height);

  Room(this.cells, this.width, this.objs);
  Room.fromHeight(this.cells, int height, this.objs)
      : this.width = cells.length ~/ height;
  Cell? goalAt(int x, int y) {
    try {
      return cells[x + (y * width)];
    } on RangeError {
      return null;
    }
  }

  factory Room.parse(Counter lineIndex, List<String> data,
      List<SolidObject> o1s, Counter portalIndex, List<int> portals) {
    int height = 0;
    int gN = 0;
    List<Cell> goals = [];
    List<SolidObject> o2s = [];
    void objAdd(SolidObject obj) {
      o2s.add(obj);
      o1s.add(obj);
    }

    rows:
    for (;; lineIndex.i += 1) {
      String line = data[lineIndex.i];
      if (line.isEmpty) {
        break rows;
      }
      int x = 0;
      cols:
      for (String char in line.split('')) {
        assert(goals.length == gN);
        gN++;
        switch (char) {
          case " ":
            goals.add(Empty());
            break;
          case "G":
            goals.add(PlayerGoal());
            break;
          case "_":
            goals.add(BoxGoal());
            break;
          case "T":
            goals.add(Empty());
            objAdd(Tree(Position(x, height, true), nc++));
            break;
          case "P":
            goals.add(Empty());
            objAdd(FullPortal(
                Position(x, height, true), portals[portalIndex.i++], nc++));
            break;
          case "C":
            goals.add(Empty());
            objAdd(Portal(
                Position(x, height, true), portals[portalIndex.i++], nc++));
            break;
          case "#":
            goals.add(Empty());
            objAdd(Box(Position(x, height, true), nc++));
            break;
          case "|":
            gN--;
            break cols;
          case "a":
            objAdd(Player(Position(x, height, true), nc++));
            goals.add(Threshold(char));
            break;
          case "b":
          case "c":
          case "d":
          case "e":
          case "f":
          case "g":
          case "h":
          case "i":
          case "j":
          case "k":
          case "l":
          case "m":
          case "n":
          case "o":
          case "p":
          case "q":
          case "r":
          case "s":
          case "t":
          case "u":
          case "v":
          case "w":
          case "x":
          case "y":
          case "z":
            goals.add(Threshold(char));
            break;
          default:
            throw FormatException(
                "Unexpected \"$char\"(${char.runes.first}) while parsing room on line $lineIndex");
        }
        x++;
      }
      height++;
    }
    return Room.fromHeight(goals, height, o2s);
  }

  void populateObjects() {
    for (SolidObject object in objs) {
      object.position.room = this;
    }
  }

  int get height {
    //print("l: ${cells.length}");
    //print("w: $width");
    return cells.length ~/ width;
  }

  Position enterFrom(Direction inDir, Position? sub) {
    if (inDir.x == 0) {
      assert(inDir.y != 0);
      assert(width % 2 == 1);
      int x = sub?.x ?? (width / 2).floor();
      int y = (inDir.y == 1 ? 0 : height - 1);
      return Position.withRoom(x, y, this);
    } else {
      assert(inDir.y == 0);
      assert(height % 2 == 1);
      int y = sub?.y ?? (height / 2).floor();
      int x = inDir.x == 1 ? 0 : width - 1;
      return Position.withRoom(x, y, this);
    }
  }
}

class Portal extends Box {
  final int roomIndex;

  Portal(Position position, this.roomIndex, int code) : super(position, code);

  String toString() => "room$roomIndex";

  @override
  SolidObject copy() {
    return Portal(position, roomIndex, code);
  }

  @override
  MoveResult move(Position pos, Direction inDir, World world) {
    return MoveResult(true,
        EnterResult(inDir, world.rooms[roomIndex].enterFrom(inDir, pos.sub)));
  }
}

class FullPortal extends Portal {
  FullPortal(Position position, int roomIndex, int code)
      : super(position, roomIndex, code);

  @override
  SolidObject copy() {
    return FullPortal(position, roomIndex, code);
  }
}

class Counter extends Object {
  int i = 0;
  String toString() => i.toString();
}

int _temp_indent_ = 0;

class World extends ChangeNotifier {
  final List<Room> rooms;

  bool innerPush = false;

  World(this.rooms, this.objects, this.to, this.worldSource, this.name,
      this.messageIDs, this.messages) {
    //print("World.to: '$to'");
    objects
        .whereType<Player>()
        .forEach((x) => _checkForMessage(goalAtPosition(x.position)));
    history = [
      objects.map((x) => x.copy()).toList(),
    ];
  }
  late final List<List<SolidObject>> history;
  final List<SolidObject> objects;
  final WorldSource worldSource;

  final String name;
  final String to;
  //int get playerX => _playerPos.x;
  //int get playerY => _playerPos.y;

  void Function(Position) updatePosCreator(SolidObject object) {
    return (Position p) {
      object.position = p..sub = null;
    };
  }

  void left(Player player) {
    move(Direction.a(), true, player.position, updatePosCreator(player));
  }

  void up(Player player) {
    move(Direction.w(), true, player.position, updatePosCreator(player));
  }

  void right(Player player) {
    move(Direction.d(), true, player.position, updatePosCreator(player));
  }

  bool move(Direction dir, bool doStart, final Position player,
      void Function(Position) updatePos,
      [bool handlePush = true, Set positions = const {}]) {
    _temp_indent_++;
    assert(
        dir == Direction.w() ||
            dir == Direction.s() ||
            dir == Direction.a() ||
            dir == Direction.d() ||
            dir == Direction(0, 0),
        "is $dir");
    Position newPos = doStart ? player + dir : player;
    SolidObject? nextOffset = atPosition(newPos, null);
    if (!(nextOffset?.canMoveTo ?? true)) {
      if (innerPush && player.room.holder != null) {
        print(
            '${'  ' * _temp_indent_}inner push (origoal $newPos / start $player / probably a tree $nextOffset)');

        _temp_indent_--;
        return move(dir, true, player.room.holder!.position,
            updatePosCreator(player.room.holder!));
      }
      _currentMessage =
          "You can't ever move to a ${nextOffset.runtimeType} (tried to move to $newPos)";
      notifyListeners();
      _temp_indent_--;
      return false;
    }
    MoveResult att = nextOffset?.move(newPos, dir, this) ??
        MoveResult(false, EnterResult(dir, newPos));
    foo:
    {
      if (positions.contains(newPos)) {
        //throw ('$newPos already exists');
        //break foo; TODO
      }
      if (att.push && handlePush) {
        if (move(dir, true, newPos, updatePosCreator(nextOffset!), true,
            positions.toSet()..add(newPos))) {
          break foo;
        }
        MoveResult eat =
            nextOffset.move(newPos, dir.rotateLeft().rotateLeft(), this);
        if (eat.push &&
            move(
                dir.rotateLeft().rotateLeft(),
                false,
                player,
                updatePosCreator(nextOffset),
                false,
                positions.toSet()..add(newPos))) {
          break foo;
        }
      }
      if (att.enter != null) {
        if (atPosition(att.enter!.newPos, null) == null) {
          newPos = att.enter!.newPos;
          break foo;
        }
        _temp_indent_--;
        return move(
          att.enter!.dir,
          false,
          att.enter!.newPos,
          updatePos,
          handlePush,
        );
      } else {
        _currentMessage =
            "Cannot move to $newPos - pushing the ${nextOffset.runtimeType} there did not succeed";
        notifyListeners();
        _temp_indent_--;
        return false;
      }
    }
    nextOffset = atPosition(newPos, null);
    updatePos(newPos);
    notifyListeners();
    if (goalsDone()) {
      Future.delayed(Duration(milliseconds: 500)).then((value) {
        worldSource.initWorld(to);
        notifyListeners();
      });
      _temp_indent_--;
      return true;
    }
    _checkForMessage(goalAtPosition(player));
    notifyListeners();
    history.add(objects.map((e) => e.copy()).toList());
    _temp_indent_--;
    return true;
  }

  bool goalsDone() {
    for (Room room in rooms) {
      int x = 0;
      int y = 0;
      for (; x < room.width; x++) {
        for (; y < room.height; y++) {
          if (room.goalAt(x, y) is BoxGoal) {
            bool fulf = false;
            for (Box b in objects.whereType<Box>()) {
              if (b.position == Position.withRoom(x, y, room)) {
                fulf = true;
              }
            }
            if (!fulf) {
              return false;
            }
          }
          if (room.goalAt(x, y) is PlayerGoal) {
            bool fulf = false;
            for (Player b in objects.whereType<Player>()) {
              if (b.position == Position.withRoom(x, y, room)) {
                fulf = true;
              }
            }
            if (!fulf) {
              return false;
            }
          }
        }
        y = 0;
      }
    }
    return true;
  }

  void down(Player player) {
    move(Direction.s(), true, player.position, updatePosCreator(player));
  }

  int _nextMessage = 0;
  final List<String> messageIDs;
  final Map<String, String> messages;
  String get currentMessage => _currentMessage;
  String _currentMessage = '';

  void _checkForMessage(Cell? cell) {
    // caller must call notifyListeners if desired
    if (cell is Threshold) {
      if (_nextMessage < messageIDs.length) {
        if (cell.id == messageIDs[_nextMessage]) {
          _currentMessage = messages[messageIDs[_nextMessage]]!;
          _nextMessage += 1;
        }
      }
    }
  }

  factory World.parse(String rawData, WorldSource source) {
    List<String> data = rawData.split('\n');
    List<SolidObject> objects = [];
    List<Room> rooms = [];
    String to = data[0];
    String name = data[1];
    Counter lineIndex = Counter()..i = 2;
    List<int> portals = [];
    //print("parse($to)");
    while (data[lineIndex.i] != '') {
      portals.add(int.parse(data[lineIndex.i]));
      lineIndex.i += 1;
    }
    lineIndex.i += 1;
    Counter portalIndex = Counter();
    while (data[lineIndex.i] != '') {
      rooms.add(Room.parse(lineIndex, data, objects, portalIndex, portals)
        ..populateObjects());
      lineIndex.i += 1;
    }

    for (FullPortal portal in objects.whereType<FullPortal>()) {
      rooms[portal.roomIndex].holder = portal;
    }

    lineIndex.i += 1;
    // read messages
    final List<String> messageIDs = <String>[];
    final Map<String, String> messages = <String, String>{};
    messages:
    for (; lineIndex.i < data.length; lineIndex.i += 1) {
      String line = data[lineIndex.i];
      if (line.isEmpty) {
        break messages;
      }
      String id = line[0];
      String message = '';
      if (line.length > 1) {
        if (line[1] != ' ') {
          throw FormatException(
              "message format is incorrect on line $lineIndex: $line");
        }
        message = line.substring(2);
      }
      messageIDs.add(id);
      messages[id] = message;
    }
    return World(
      rooms,
      objects,
      to,
      source,
      name,
      messageIDs,
      messages,
    );
  }
  String toString() => "$objects\n$name\n$to\n" + rooms.join('\n\n');

  Cell? goalAtPosition(Position att) => att.room.goalAt(att.x, att.y);

  void reset() {
    objects.clear();
    objects.addAll(history.first.map((x) => x.copy()));
    _currentMessage = "Reset.";
    _nextMessage = 0;
    objects
        .whereType<Player>()
        .forEach((x) => _checkForMessage(goalAtPosition(x.position)));

    for (FullPortal portal in objects.whereType<FullPortal>()) {
      rooms[portal.roomIndex].holder = portal;
    }
    notifyListeners();
  }

  SolidObject? atPosition(Position position, SolidObject? player) {
    for (SolidObject object in objects) {
      if (object.position == position && object != player) {
        return object;
      }
    }
    return null;
  }

  void undo() {
    if (history.length == 1) {
      return;
    }
    objects.clear();
    objects.addAll(history[history.length - 2].map((x) => x.copy()));
    history.removeLast();
    _currentMessage = "Reset.";
    _nextMessage = 0;
    objects
        .whereType<Player>()
        .forEach((x) => _checkForMessage(goalAtPosition(x.position)));
    for (Portal portal in objects.whereType<Portal>()) {
      rooms[portal.roomIndex].holder = portal;
    }
    notifyListeners();
  }
}

abstract class Cell extends Object {}

class Empty extends Cell {
  String toString() => " ";
}

class Threshold extends Empty {
  Threshold(this.id);
  final String id;
  String toString() => id;
}

class PlayerGoal extends Cell {
  String toString() => "G";
}

class BoxGoal extends Cell {
  String toString() => "_";
}

abstract class SolidObject extends Object {
  Position position;

  final int code;

  MoveResult move(Position pos, Direction inDir, World world);
  bool get canMoveTo => true;

  SolidObject copy();

  SolidObject(this.position, this.code);
}

class Tree extends SolidObject {
  Tree(Position position, int code) : super(position, code);

  @override
  MoveResult move(Position pos, Direction inDir, World world) =>
      throw UnsupportedError('cannot move into a tree');
  String toString() => "T";
  bool get canMoveTo => false;

  @override
  SolidObject copy() {
    return Tree(position, code);
  }
}

class Player extends SolidObject {
  Player(Position position, int code) : super(position, code);

  @override
  MoveResult move(Position pos, Direction inDir, World world) =>
      MoveResult(true, null);

  String toString() => "<player at $position>";

  @override
  SolidObject copy() {
    return Player(position, code);
  }
}

class Box extends SolidObject {
  Box(Position position, int code) : super(position, code);

  @override
  MoveResult move(Position pos, Direction inDir, World world) =>
      MoveResult(true, null);

  @override
  SolidObject copy() {
    return Box(position, code);
  }
}

class EnterResult extends Object {
  final Direction dir;
  final Position newPos;

  EnterResult(this.dir, this.newPos);
}

class MoveResult extends Object {
  MoveResult(this.push, this.enter);
  final bool push;
  final EnterResult? enter;
}

class Position extends Object {
  final int x;
  final int y;
  Position? sub;

  late final Room room;
  operator +(Direction other) {
    Position newPos = Position.withRoom(
      other.x + x,
      other.y + y,
      room,
    );
    if (room.dimensions.validPosition(newPos)) {
      return newPos;
    } else {
      return (room.holder!.position + other)..sub = this;
    }
  }

  operator ==(Object other) =>
      other is Position && other.x == x && other.y == y && other.room == room;

  Offset toOffset() => Offset(x / 1, y / 1);

  Position(this.x, this.y, [bool x2 = false]) : assert(x2);

  String toString() => "$x, $y";

  @override
  int get hashCode => x.hashCode ^ (y.hashCode * 2) ^ 3;

  Position.withRoom(this.x, this.y, this.room);
}

class Dimensions {
  final int width;
  final int height;

  String toString() => "$width, $height";

  Dimensions(this.width, this.height);

  bool validPosition(Position position) {
    return position.x < width &&
        position.x >= 0 &&
        position.y < height &&
        position.y >= 0;
  }
}

class Direction extends Object {
  const Direction.w()
      : x = 0,
        y = -1;
  const Direction.a()
      : x = -1,
        y = 0;
  const Direction.s()
      : x = 0,
        y = 1;
  const Direction.d()
      : x = 1,
        y = 0;
  const Direction(this.x, this.y);
  final int x;
  final int y;
  operator ==(Object direction) =>
      direction is Direction && direction.x == x && direction.y == y;
  double toRadians() {
    if (this == Direction.w()) return -pi / 2;
    if (this == Direction.a()) return pi;
    if (this == Direction.s()) return pi / 2;
    if (this == Direction.d()) return 0;
    throw "Unknown Direction";
  }

  String toString() {
    if (this == Direction.w()) return "north";
    if (this == Direction.a()) return "west";
    if (this == Direction.s()) return "south";
    if (this == Direction.d()) return "east";
    throw "Unknown Direction";
  }

  @override
  int get hashCode => x.hashCode ^ (y.hashCode * 2);

  Direction rotateLeft() {
    if (this == Direction.d()) return Direction.w();
    if (this == Direction.w()) return Direction.a();
    if (this == Direction.a()) return Direction.s();
    if (this == Direction.s()) return Direction.d();
    throw "Unknown Direction";
  }
}
