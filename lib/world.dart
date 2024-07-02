import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'dart:math';

typedef DataLoader = Future<String> Function(String name);

class WorldSource extends ChangeNotifier {
  WorldSource(this.loader) {
    initWorld('main');
  }

  final DataLoader loader;

  World? _currentWorld;
  World? get currentWorld => _currentWorld;

  bool _disposed = false;

  Future<World> initWorld(String newName) async {
    Completer<World> completer = Completer<World>();
    assert(!_disposed);
    _currentWorld = null;
    notifyListeners();
    final String data = await loader(newName);
    if (!_disposed) {
      completer.complete(_currentWorld = World.parse(data, this));
      notifyListeners();
    }
    return completer.future;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class World extends ChangeNotifier {
  World(this.width, this.cells, this._playerPos, this.to, this.worldSource,
      this.name, this.messageIDs, this.messages)
      : _initialPos = _playerPos {
    //print("World.to: '$to'");
    _checkForMessage(atOffset(_playerPos));
  }
  World.fromHeight(int height, this.cells, this._playerPos, this.to,
      this.worldSource, this.name, this.messageIDs, this.messages)
      : this.width = cells.length ~/ height,
        _initialPos = _playerPos {
    //print("World.to fromHeight: '$to'");
    _checkForMessage(atOffset(_playerPos));
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

  final Offset _initialPos;
  int get playerX => _playerPos.dx.toInt();
  int get playerY => _playerPos.dy.toInt();

  /// Used for savefiles with unusual starting positions.
  /// [reset] is not affected.
  void updatePos(Offset newPos) {
    if (_playerPos != _initialPos) {
      throw StateError("call [updatePos] before moving, not after");
    }
    _playerPos = newPos;
    notifyListeners();
  }

  void left() {
    move(Direction.a());
  }

  void up() {
    move(Direction.w());
  }

  void right() {
    move(Direction.d());
  }

  void move(Direction dir) {
    assert(
        dir == Direction.w() ||
            dir == Direction.s() ||
            dir == Direction.a() ||
            dir == Direction.d() ||
            dir == Direction(0, 0),
        "is $dir");
    var nextOffset = atOffset(_playerPos + dir.toOffset());
    if (!(nextOffset?.canMove ?? false)) return;
    MoveResult att = nextOffset?.move(_playerPos + dir.toOffset(), dir) ??
        MoveResult(Direction(0, 0), Offset(-1, 0));
    Offset oldPos = _playerPos;
    _playerPos = isValid(att.newPos) ? att.newPos : _playerPos;
    Cell? newCell =
        atOffset(_playerPos);
    _checkForMessage(newCell);
    notifyListeners();
    if (newCell is Goal) {
      worldSource.initWorld(to);
    } else if (newCell is! Empty) {
      if (_playerPos == oldPos) return;
      move(Direction(0, 0));
    }
  }

  void down() {
    move(Direction.s());
  }

  final List<Cell?> cells;

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

  factory World.parse(
    String rawData,
    WorldSource source,
  ) {
    List<String> data = rawData.split('\n');
    List<Cell?> parsed = [];
    int height = 0;
    List<String> xy = data.first.split(" ");
    int x = int.parse(xy[0]);
    int y = int.parse(xy[1]);
    String to = data[1];
    String name = data[2];
    //print("parse($to)");
    int lineIndex = 3;
    rows:
    for (; lineIndex < data.length; lineIndex += 1) {
      String line = data[lineIndex];
      if (line.isEmpty) {
        break rows;
      }
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
          case "a":
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
            parsed.add(Threshold(char));
            break;
          default:
            throw FormatException(
                "Unexpected \"$char\"(${char.runes.first}) while parsing world on line $lineIndex");
        }
      }
      height++;
    }
    lineIndex += 1;
    // read messages
    final List<String> messageIDs = <String>[];
    final Map<String, String> messages = <String, String>{};
    messages:
    for (; lineIndex < data.length; lineIndex += 1) {
      String line = data[lineIndex];
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
    return World.fromHeight(
      height,
      parsed,
      Offset(x.toDouble(), y.toDouble()),
      to,
      source,
      name,
      messageIDs,
      messages,
    );
  }
  String toString() =>
      "$playerX $playerY\n$name\n$to\n" +
      cells.join('').split("null").join("|\n");
  Cell? at(int x, int y) {
    if (x < 0) return null;
    if (x > width - 1) return null;
    if (y < 0) return null;
    if (y > (cells.length / width) - 1) return null;
    return cells[x + (y * width)];
  }

  Cell? atOffset(Offset att) => at(att.dx.toInt(), att.dy.toInt());

  bool isValid(Offset offset) {
    return offset.dx < width - 1 &&
        offset.dx >= 0 &&
        offset.dy < height &&
        offset.dy >= 0;
  }

  void reset() {
    _playerPos = _initialPos;
    _currentMessage = "Reset.";
    _nextMessage = 0;
    _checkForMessage(atOffset(_playerPos));
    notifyListeners();
  }

  String generateSavefile() {
    return "${_playerPos.dx} ${_playerPos.dy}\n$name";
  }
}

abstract class Cell {
  MoveResult move(Offset pos, Direction inDir) => MoveResult(inDir, pos);
  bool get canMove => true;
}

class Empty extends Cell {
  String toString() => " ";
}

class Threshold extends Empty {
  Threshold(this.id);
  final String id;
  String toString() => id;
}

class Goal extends Cell {
  String toString() => "G";
}

class Tree extends Cell {
  MoveResult move(Offset pos, Direction inDir) =>
      MoveResult(Direction(-inDir.x, -inDir.y), pos - inDir.toOffset());
  String toString() => "#";
  bool get canMove => false;
}

class OneWay extends Cell {
  OneWay(this.dir);
  final Direction dir;
  String toString() {
    if (dir == Direction.s()) return "v";
    if (dir == Direction.w()) return "∧";
    if (dir == Direction.d()) return ">";
    if (dir == Direction.a()) return "<";
    throw UnimplementedError("Unknown direction ($dir)");
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
  Offset toOffset() => Offset(x / 1, y / 1);
  double toRadians() {
    if (this == Direction.w()) return -pi / 2;
    if (this == Direction.a()) return pi;
    if (this == Direction.s()) return pi / 2;
    if (this == Direction.d()) return 0;
    throw "Unknown Direction";
  }

  @override
  // TODO(tree): implement hashCode
  int get hashCode => super.hashCode;

  Direction rotateLeft() {
    if (this == Direction.d()) return Direction.w();
    if (this == Direction.w()) return Direction.a();
    if (this == Direction.a()) return Direction.s();
    if (this == Direction.s()) return Direction.d();
    throw "Unnown Direction";
  }
}
