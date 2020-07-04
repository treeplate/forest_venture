import 'package:flutter/foundation.dart';
import 'dart:ui';

typedef DataLoader = Future<String> Function(String name);

class WorldSource extends ChangeNotifier {
  WorldSource(this.loader) {
    initWorld('main');
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
  World(this.width, this.cells, this._playerPos, this.to, this.worldSource) {
    //print("World.to: '$to'");
  }
  World.fromHeight(
      int height, this.cells, this._playerPos, this.to, this.worldSource)
      : this.width = cells.length ~/ height {
    //print("World.to fromHeight: '$to'");
  }

  final WorldSource worldSource;

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
    move(Offset(-1, 0));
  }

  void up() {
    move(Offset(0, -1));
  }

  void right() {
    move(Offset(1, 0));
  }

  int x = 0;
  int y = 0;
  void move(Offset dir, [String indent = ""]) {
    assert(
        dir == Offset(0, 1) ||
            dir == Offset(0, -1) ||
            dir == Offset(1, 0) ||
            dir == Offset(-1, 0),
        "is $dir");
    print(indent + "move {");
    print("$indent  move $dir");
    MoveResult att = atOffset(_playerPos + dir)?.move(_playerPos + dir, dir) ??
        MoveResult(Offset(0, 0), Offset(-1, 0));
    Offset oldPos = _playerPos;
    print("$indent  move valid: ${isValid(att.newPos)}");
    _playerPos = isValid(att.newPos) ? att.newPos : _playerPos;
    notifyListeners();
    if (atOffset(_playerPos) is Goal) {
      worldSource.initWorld(to);
    } else if (atOffset(_playerPos) is! Empty) {
      print("$indent  hu ($_playerPos - $oldPos)");
      print("$indent  $dir");
      if (_playerPos == oldPos) return;
      move(att.dir, indent + "  ");
    }
    print("$indent}");
  }

  void down() {
    move(Offset(0, 1));
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
    //print("parse($to)");
    for (String line in data.toList()..removeRange(0, 2)) {
      cols:
      for (String char in line.split('')) {
        switch (char) {
          case " ":
            parsed.add(Empty());
            break;
          case "G":
            parsed.add(Goal());
            break;
          case "#":
            parsed.add(Tree());
            break;
          case ">":
            parsed.add(OneWay(Offset(1, 0)));
            break;
          case "<":
            parsed.add(OneWay(Offset(-1, 0)));
            break;
          case "A":
          case "∧":
            parsed.add(OneWay(Offset(0, -1)));
            break;
          case "v":
            parsed.add(OneWay(Offset(0, 1)));
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
  MoveResult move(Offset pos, Offset inDir) => MoveResult(inDir, pos);
}

class Empty extends Cell {
  String toString() => " ";
}

class Goal extends Cell {
  String toString() => "G";
}

class Tree extends Cell {
  MoveResult move(Offset pos, Offset inDir) => MoveResult(-inDir, pos - inDir);
  String toString() => "#";
}

class OneWay extends Cell {
  OneWay(this.dir);
  final Offset dir;
  String toString() {
    if (dir == Offset(0, 1)) return "v";
    if (dir == Offset(0, -1)) return "∧";
    if (dir == Offset(1, 0)) return ">";
    if (dir == Offset(-1, 0)) return "<";
    throw UnimplementedError(
        "Unknown direction ($dir) == Offset(-1, 0) ${dir == Offset(-1, 0)}");
  }

  MoveResult move(Offset pos, Offset inDir) {
    print("$dir");
    return MoveResult(dir, pos + dir);
  }
}

class MoveResult {
  MoveResult(this.dir, this.newPos);
  final Offset dir;
  final Offset newPos;
}
