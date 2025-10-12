import 'dart:ui' show Rect, Offset, Size;

class Object {
  int x;
  int y;
  int width;
  int height;
  int baseXvel = 0;
  int baseYvel = 0;
  int moveXvel = 0;
  int moveYvel = 0;
  int get xvel => baseXvel + moveXvel;
  int get yvel => baseYvel + moveYvel;
  final Set<String> tags;

  Rect get asRect => Offset(x.toDouble(), y.toDouble()) & Size(width.toDouble(), height.toDouble());

  Object.xywh(this.x, this.y, this.width, this.height, {required this.tags});
}

class World {
  Set<Object> objects;

  /// pixels per frame^2
  int gravity = 1;
  final int width;
  final int height;
  final String name;

  World(this.objects, this.width, this.height, this.name);

  factory World.parse(String file) {
    final Set<Object> objects = {};
    List<String> lines = file.split('\n');
    List<String> headerParts = lines.first.split(' ');
    if (headerParts.length < 3) {
      throw FormatException(
        'bad header (not enough spaces) - parts: $headerParts',
      );
    }
    int? width = int.tryParse(headerParts.first);
    if (width == null) {
      throw FormatException(
        'invalid integer for world width: ${headerParts.first}',
      );
    }
    int? height = int.tryParse(headerParts[1]);
    if (height == null) {
      throw FormatException(
        'invalid integer for world height: ${headerParts[1]}',
      );
    }
    String name = headerParts.skip(2).join(' ');
    for (String objstr in lines.skip(1)) {
      List<String> parts = objstr.split(' ');
      if (parts.length < 4) {
        throw FormatException('bad object (not enough spaces) - parts: $parts');
      }
      int? x = int.tryParse(parts[0]);
      if (x == null) {
        throw FormatException('invalid int for object x: ${parts[0]}');
      }
      int? y = int.tryParse(parts[1]);
      if (y == null) {
        throw FormatException('invalid int for object y: ${parts[1]}');
      }
      int? width = int.tryParse(parts[2]);
      if (width == null) {
        throw FormatException('invalid int for object width: ${parts[2]}');
      }
      int? height = int.tryParse(parts[3]);
      if (height == null) {
        throw FormatException('invalid int for object height: ${parts[3]}');
      }
      objects.add(
        Object.xywh(x, y, width, height, tags: parts.skip(4).toSet()),
      );
    }
    return World(objects, width, height, name);
  }

  bool colliding(Object a, Object? b) {
    if (b != null) {
      return a.asRect.overlaps(b.asRect);
    }
    return a.x < 0 ||
        a.y < 0 ||
        a.x + a.width > width ||
        a.y + a.height > height;
  }

  Iterable<Object?> colliders(Object a) sync* {
    if (colliding(a, null)) yield null;
    for (Object b in objects) {
      if (a == b) continue;
      if (colliding(a, b)) yield b;
    }
  }

  void tick() {
    Set<Object> deadObjects = {};
    for (Object object in objects) {
      assert(colliders(object).isEmpty);
      if (object.tags.contains('enemy')) {
        Object? player = objects
            .where((e) => e.tags.contains('player'))
            .firstOrNull;
        Object? fire = objects
            .where((e) => e.tags.contains('fire'))
            .firstOrNull;
        if (fire != null) {
          if (object.tags.contains('float')) {
            if (fire.y > object.y + object.height) {
              object.moveYvel = -2;
            } else {
              object.moveYvel = 2;
            }
          } else {
            if (fire.y <= object.y + object.height) {
              object.y--;
              if (colliders(object).isNotEmpty) {
                object.baseYvel += 15;
              }
              object.y++;
            }
          }
          if (fire.x > object.x) {
            object.moveXvel = -2;
          } else {
            object.moveXvel = 2;
          }
        } else if (player != null) {
          if (object.tags.contains('float')) {
            if (player.y < object.y) {
              object.moveYvel = -2;
            } else if (player.y > object.y) {
              object.moveYvel = 2;
            } else {
              object.moveYvel = 0;
            }
          } else {
            if (player.y > object.y) {
              object.y--;
              if (colliders(object).isNotEmpty) {
                object.baseYvel += 15;
              }
              object.y++;
            }
          }
          if (player.x < object.x) {
            object.moveXvel = -2;
          } else if (player.x > object.x) {
            object.moveXvel = 2;
          } else {
            object.moveXvel = 0;
          }
        } else if (object.moveXvel == 0) {
          object.moveXvel = -2;
        } else if (object.moveXvel == -2) {
          object.x--;
          if (colliders(object).isNotEmpty) {
            object.moveXvel = 2;
          }
          object.x++;
        } else {
          assert(object.moveXvel == 2);
          object.x++;
          if (colliders(object).isNotEmpty) {
            object.moveXvel = -2;
          }
          object.x--;
        }
      }
      if (!object.tags.contains('float')) {
        object.baseYvel -= gravity;
      }
      object.y += object.yvel;
      if (colliders(object).isNotEmpty) {
        Iterable<Object?> currentColliders = colliders(object).toList();
        while (currentColliders.isNotEmpty) {
          if (object.tags.contains('enemy') || !currentColliders.any(
            (e) => e?.tags.contains('enemy') ?? false,
          )) {
            object.y -= object.yvel.sign;
          }
          for (Object? object2 in currentColliders) {
            if (!object.tags.contains('enemy') && (object2?.tags.contains('enemy') ?? false)) {
              object2!.height -= 1;
              if (object2.height == 0) deadObjects.add(object2);
            }
          }
          currentColliders = colliders(object).toList();
        }
        object.baseYvel = 0;
      }
      object.x += object.xvel;
      if (colliders(object).isNotEmpty) {
        List<Object?> currentColliders = colliders(object).toList();
        if (object.tags.contains('fire')) {
          object.x -= object.xvel;
          deadObjects.add(object);
          for (Object? collider in currentColliders) {
            if (collider?.tags.contains('enemy') ?? false) {
              deadObjects.add(collider!);
            }
          }
          continue;
        }
        if (object.tags.contains('key')) {
          object.x -= object.xvel;
          for (Object? collider in currentColliders) {
            if (collider?.tags.contains('door') ?? false) {
              deadObjects.add(collider!);
            }
          }
          continue;
        }
        while (currentColliders.isNotEmpty) {
          if (!currentColliders.any(
                (e) => e?.tags.contains('player') ?? false,
              ) ||
              !object.tags.contains('enemy')) {
            object.x -= object.xvel.sign;
          }
          for (Object? object2 in currentColliders) {
            if (object.tags.contains('enemy') &&
                (object2?.tags.contains('player') ?? false)) {
              object2!.height = 0;
              object2.tags.remove('player');
            }
          }
          currentColliders = colliders(object).toList();
        }
        object.baseXvel = 0;
      }
    }
    objects.removeAll(deadObjects);
  }
}
