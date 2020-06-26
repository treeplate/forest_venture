import 'dart:io';

class World {
  World(this.width, this.cells);
  final int width;
  int get height {
    assert(cells.length.isFinite);
    assert(width.isFinite);
    //print("l: ${cells.length}");
    //print("w: $width");
    return cells.length ~/ width;
  }

  final List<Cell> cells;
  factory World.parse(List<String> data) {
    List<Cell> parsed = [];
    int width = 0;
    for (String line in data) {
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
    return World(width, parsed);
  }
  Cell at(int x, int y) => cells[x + (y * width)];
}

World fromFile(String file) {
  return World.parse(File("lib/" + file).readAsLinesSync());
}

class Cell {}
