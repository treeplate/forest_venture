import 'package:flutter/foundation.dart';

class World extends ChangeNotifier {
  World(this.width, this.cells, this._playerX, this._playerY);
  World.fromHeight(int height, this.cells, this._playerX, this._playerY)
      : this.width = cells.length ~/ height;
  final int width;
  int get height {
    assert(cells.length.isFinite);
    assert(width.isFinite);
    //print("l: ${cells.length}");
    //print("w: $width");
    return cells.length ~/ width;
  }

  int _playerX;
  int _playerY;
  int get playerX => _playerX;
  int get playerY => _playerY;

  void left() {
    assert(playerX > 0);
    if (at(playerX - 1, playerY).clear) {
      _playerX--;
      notifyListeners();
    }
  }

  void right() {
    assert(playerX < width - 1);
    if (at(playerX + 1, playerY).clear) {
      _playerX++;
      notifyListeners();
    }
  }

  void up() {
    assert(playerY > 0);
    if (at(playerX, playerY - 1).clear) {
      _playerY--;
      notifyListeners();
    }
  }

  void down() {
    assert(playerY < height - 1);
    if (at(playerX, playerY + 1).clear) {
      _playerY++;
      notifyListeners();
    }
  }

  final List<Cell> cells;

  factory World.parse(String rawData) {
    List<String> data = rawData.split('\n');
    List<Cell> parsed = [];
    int height = 0;
    List<String> xy = data.first.split(" ");
    int x = int.parse(xy[0]);
    int y = int.parse(xy[1]);
    for (String line in data.toList()..removeRange(0, 1)) {
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
          case "|":
            parsed.add(null);
            break cols;
          default:
            throw FormatException("Unexpected \"$char\" while parsing world");
        }
      }
      height++;
    }
    return World.fromHeight(height, parsed, x, y);
  }
  String toString() =>
      "$playerX $playerY\n" + cells.join('').split("null").join("|\n");
  Cell at(int x, int y) => cells[x + (y * width)];
}

abstract class Cell {
  bool get clear => true;
}

class Empty extends Cell {
  String toString() => " ";
}

class Goal extends Cell {
  String toString() => "G";
}

class Tree extends Cell {
  bool get clear => false;
  String toString() => "#";
}
