import 'package:flutter/foundation.dart';
import 'dart:ui';

class World extends ChangeNotifier {
  World(this.width, this.cells, this._playerPos, this.to) {
    print("World.to: '$to'");
  }
  World.fromHeight(int height, this.cells, this._playerPos, this.to)
      : this.width = cells.length ~/ height {
    print("World.to fromHeight: '$to'");
  }
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
    Offset att = at(playerX - 1, playerY)?.move(
            Offset((playerX - 1).toDouble(), (playerY).toDouble()),
            Offset(-1, 0)) ??
        Offset(-1, 0);
    _playerPos = isValid(att) ? att : _playerPos;
    notifyListeners();
  }

  void right() {
    //print(playerX + 1);
    //print("is less than ${width - 1}");
    Offset att = at(playerX + 1, playerY)?.move(
            Offset((playerX + 1).toDouble(), (playerY).toDouble()),
            Offset(1, 0)) ??
        Offset(-1, 0);
    _playerPos = isValid(att) ? att : _playerPos;
    notifyListeners();
  }

  void up() {
    Offset att = at(playerX, playerY - 1)?.move(
            Offset((playerX).toDouble(), (playerY - 1).toDouble()),
            Offset(0, -1)) ??
        Offset(-1, 0);
    _playerPos = isValid(att) ? att : _playerPos;
    notifyListeners();
  }

  void down() {
    Offset att = at(playerX, playerY + 1)?.move(
            Offset((playerX).toDouble(), (playerY + 1).toDouble()),
            Offset(0, 1)) ??
        Offset(-1, 0);
    _playerPos = isValid(att) ? att : _playerPos;
    notifyListeners();
  }

  final List<Cell> cells;

  factory World.parse(String rawData) {
    List<String> data = rawData.split('\n');
    List<Cell> parsed = [];
    int height = 0;
    List<String> xy = data.first.split(" ");
    int x = int.parse(xy[0]);
    int y = int.parse(xy[1]);
    String to = data[1];
    print("parse($to)");
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
            throw FormatException("Unexpected \"$char\" while parsing world");
        }
      }
      height++;
    }
    return World.fromHeight(
        height, parsed, Offset(x.toDouble(), y.toDouble()), to);
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

  bool isValid(Offset offset) {
    return offset.dx < width - 1 &&
        offset.dx >= 0 &&
        offset.dy < height &&
        offset.dy >= 0;
  }
}

abstract class Cell {
  Offset move(Offset pos, Offset inDir) => pos;
}

class Empty extends Cell {
  String toString() => " ";
}

class Goal extends Cell {
  String toString() => "G";
}

class Tree extends Cell {
  Offset move(Offset pos, Offset inDir) => pos - inDir;
  String toString() => "#";
}

class OneWay extends Cell {
  OneWay(this.dir);
  final Offset dir;
  String toString() {
    if (dir == Offset(0, 1)) return "v";
    if (dir == Offset(0, -1)) return "∧";
    if (dir == Offset(1, 0)) return ">";
    if (dir == Offset(1, 0)) return "<";
    throw UnimplementedError("Unknown direction ($dir)");
  }

  Offset move(Offset pos, Offset inDir) => pos + dir;
}
