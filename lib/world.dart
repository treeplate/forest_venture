import 'dart:io';

import 'package:flutter/cupertino.dart';

class World {
  World(this.width, this.cells, this._playerx, this._playery);
  final int width;
  int get height {
    assert(cells.length.isFinite);
    assert(width.isFinite);
    //print("l: ${cells.length}");
    //print("w: $width");
    return cells.length ~/ width;
  }

  int _playerx;
  int _playery;
  int get playerx => _playerx;
  int get playery => _playery;

  void left() {
    assert(playerx > 0);
    if (at(playerx - 1, playery).clear) _playerx--;
  }

  void right() {
    assert(playerx < width - 1);
    if (at(playerx + 1, playery).clear) _playerx++;
  }

  void up() {
    assert(playery > 0);
    if (at(playerx, playery - 1).clear) _playery--;
  }

  void down() {
    assert(playery < height - 1);
    if (at(playerx, playery + 1).clear) _playerx++;
  }

  final List<Cell> cells;
  factory World.parse(List<String> data) {
    List<Cell> parsed = [];
    int width = 0;
    List<String> xy = data.first.split(" ");
    int x = int.parse(xy[0]);
    int y = int.parse(xy[1]);
    for (String line in data.toList()..removeRange(0, 1)) {
      cols:
      for (String char in line.split('')) {
        switch (char) {
          case " ":
            parsed.add(Cell());
            break;
          case "|":
            break cols;
          default:
            throw FormatException("Unexpected \"$char\" while parsing world");
        }
      }
      width++;
    }
    return World(width, parsed, x, y);
  }
  Cell at(int x, int y) => cells[x + (y * width)];
}

World fromFile(String file) {
  return World.parse(File("lib/" + file).readAsLinesSync());
}

class Cell {
  bool get clear => true;
}
