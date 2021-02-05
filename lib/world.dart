import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:math';

typedef DataLoader = Future<String> Function(String name);

class WorldSource extends ChangeNotifier {
  WorldSource(this.loader) {
    initWorld('end');
  }

  final DataLoader loader;

  World _currentWorld;
  World get currentWorld => _currentWorld;

  bool _disposed = false;

  Future<void> initWorld(String newName) async {
    assert(!_disposed);
    _currentWorld = null;
    notifyListeners();
    final String data = await loader(newName);
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

class World extends ChangeNotifier {
  World(this.width, this.cells, this._playerPos, this.to, this.worldSource,
      this.name) {
    //print("World.to: '$to'");
  }
  World.fromHeight(int height, this.cells, this._playerPos, this.to,
      this.worldSource, this.name)
      : this.width = cells.length ~/ height {
    //print("World.to fromHeight: '$to'");
  }

  final WorldSource worldSource;

  final String name;
  final int width;
  final String to;
  int get height {
    assert(cells.length.isFinite);
    assert(width.isFinite);
    //print("l: ${cells.length}");
    //print("w: $width");
    return cells.length ~/ width;
  }

  Offset _playerPos;
  int get playerX => _playerPos.dx.toInt();
  int get playerY => _playerPos.dy.toInt();

  void left() {
    move(Direction.a());
  }

  void up() {
    move(Direction.w());
  }

  void right() {
    move(Direction.d());
  }

  int x = 0;
  int y = 0;
  void move(Direction dir) {
    assert(
        dir == Direction.w() ||
            dir == Direction.s() ||
            dir == Direction.a() ||
            dir == Direction.d(),
        "is $dir");
    MoveResult att = atOffset(_playerPos + dir.toOffset())?.move(_playerPos + dir.toOffset(), dir) ??
        MoveResult(Direction(0, 0), Offset(-1, 0));
    Offset oldPos = _playerPos;
    _playerPos = isValid(att.newPos) ? att.newPos : _playerPos;
    notifyListeners();
    if (atOffset(_playerPos) is Goal) {
      worldSource.initWorld(to);
    } else if (atOffset(_playerPos) is! Empty) {
      if (_playerPos == oldPos) return;
      move(att.dir);
    }
  }

  void down() {
    move(Direction.s());
  }

  final List<Cell> cells;

  factory World.parse(String rawData, WorldSource source) {
    List<String> data = rawData.split('\n');
    List<Cell> parsed = [];
    int height = 0;
    List<String> xy = data.first.split(" ");
    int x = int.parse(xy[0]);
    int y = int.parse(xy[1]);
    String to = data[1];
    String name = data[2];
    //print("parse($to)");
    for (String line in data.toList()..removeRange(0, 3)) {
      cols:
      for (String char in line.split('')) {
        switch (char) {
          case " ":
            parsed.add(Empty());
            break;
          case "G":
            parsed.add(Goal());
            break;
          case "T":
            parsed.add(Tree());
            break;
          case ">":
            parsed.add(OneWay(Direction.d()));
            break;
          case "<":
            parsed.add(OneWay(Direction.a()));
            break;
          case "A":
          case "∧":
            parsed.add(OneWay(Direction.w()));
            break;
          case "v":
            parsed.add(OneWay(Direction.s()));
            break;
          case "|":
            parsed.add(null);
            break cols;
          default:
            throw FormatException(
                "Unexpected \"$char\"(${char.runes.first}) while parsing world");
        }
      }
      height++;
    }
    return World.fromHeight(
      height,
      parsed,
      Offset(x.toDouble(), y.toDouble()),
      to,
      source,
      name,
    );
  }
  String toString() =>
      "$playerX $playerY\n$to\n" + cells.join('').split("null").join("|\n");
  Cell at(int x, int y) {
    try {
      return cells[x + (y * width)];
    } on RangeError {
      return null;
    }
  }

  Cell atOffset(Offset att) => at(att.dx.toInt(), att.dy.toInt());

  bool isValid(Offset offset) {
    return offset.dx < width - 1 &&
        offset.dx >= 0 &&
        offset.dy < height &&
        offset.dy >= 0;
  }
}

abstract class Cell {
  MoveResult move(Offset pos, Direction inDir) => MoveResult(inDir, pos);
}

class Empty extends Cell {
  String toString() => " ";
}

class Goal extends Cell {
  String toString() => "G";
}

class Tree extends Cell {
  MoveResult move(Offset pos, Direction inDir) => MoveResult(Direction(-inDir.x, -inDir.y), pos - inDir.toOffset());
  String toString() => "#";
}

class OneWay extends Cell {
  OneWay(this.dir);
  final Direction dir;
  String toString() {
    if (dir == Direction.s()) return "v";
    if (dir == Direction.w()) return "∧";
    if (dir == Direction.d()) return ">";
    if (dir == Direction.a()) return "<";
    throw UnimplementedError(
        "Unknown direction ($dir)");
  }

  MoveResult move(Offset pos, Direction inDir) {
    return MoveResult(dir, pos + dir.toOffset());
  }
}

class MoveResult {
  MoveResult(this.dir, this.newPos);
  final Direction dir;
  final Offset newPos;
}

class Direction {
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
  Offset toOffset() => Offset(x/1, y/1);
  double toRadians() {
    if(this == Direction.w()) return -pi/2;
    if(this == Direction.a()) return pi;
    if(this == Direction.s()) return pi/2;
    if(this == Direction.d()) return 0;
    throw "Unknown Direction";
  }

  @override
  // TODO(tree): implement hashCode
  int get hashCode => super.hashCode;

  Direction rotateLeft() {
    if(this == Direction.d()) return Direction.w();
    if(this == Direction.w()) return Direction.a();
    if(this == Direction.a()) return Direction.s();
    if(this == Direction.s()) return Direction.d();
    throw "Unnown Direction";
  }
}