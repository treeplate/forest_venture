class World {
  World(this.width, this.height);
  final int width;
  final int height;
  Cell at(int x, int y) => Cell();
}

class Cell {}
