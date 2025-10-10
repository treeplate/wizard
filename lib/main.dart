import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'physics.dart';

void main() {
  runApp(MaterialApp(home: Home(), theme: ThemeData.dark()));
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  World? world;
  String? file;
  String filename = 'level1.txt';
  late final Ticker ticker;
  final FocusNode focusNode = FocusNode();
  Object? player;
  int jumpVel = 20;
  int speed = 5;
  Map<String, Set<Object>> teleportedObjects = {};
  @override
  void initState() {
    super.initState();
    ticker = createTicker((Duration duration) {
      setState(() {
        world?.tick();
        if (!(player?.tags.contains('player') ?? true)) {
          restart();
        }
        if (world != null) {
          Set<Object> deadObjects = {};
          for (Object obj in teleportedObjects[filename] ?? []) {
            if (world!.colliders(obj).isEmpty) {
              world!.objects.add(obj);
              deadObjects.add(obj);
            }
          }
          teleportedObjects[filename]?.removeAll(deadObjects);
        }
        outer:
        for (Object a in world?.objects ?? []) {
          for (Object b in world!.objects) {
            if (a == b) continue;
            a.y--;
            if (!world!.colliding(a, b)) {
              a.y++;
              continue;
            }
            a.y++;
            for (String tag in b.tags.where((e) => e.startsWith('goto='))) {
              String nextLevel = tag.substring(5);
              (teleportedObjects[nextLevel] ??= {}).add(a);
              a.x = 0;
              a.y = 0;
              if (a.tags.contains('player')) {
                player!.height = 50;
                player!.tags.add('player');
                world = null;
                filename = nextLevel;
                rootBundle.loadString('levels/$nextLevel').then((
                  final String file,
                ) {
                  setState(() {
                    world = World.parse(file);
                    this.file = file;
                  });
                });
                break outer;
              }
            }
          }
        }
      });
    })..start();
    rootBundle.loadString('levels/level1.lvl').then((final String file) {
      setState(() {
        world = World.parse(file);
        this.file = file;
        player = world!.objects.singleWhere((e) => e.tags.contains('player'));
      });
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        restart();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        fire();
        return KeyEventResult.handled;
      }
      switch (event.physicalKey) {
        case PhysicalKeyboardKey.keyW:
        case PhysicalKeyboardKey.space:
        case PhysicalKeyboardKey.arrowUp:
          jump();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyD:
        case PhysicalKeyboardKey.arrowRight:
          rightDown();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyA:
        case PhysicalKeyboardKey.arrowLeft:
          leftDown();
          return KeyEventResult.handled;
      }
    } else {
      assert(event is KeyUpEvent);
      switch (event.physicalKey) {
        case PhysicalKeyboardKey.keyW:
        case PhysicalKeyboardKey.space:
        case PhysicalKeyboardKey.arrowUp:
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyD:
        case PhysicalKeyboardKey.arrowRight:
          rightUp();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyA:
        case PhysicalKeyboardKey.arrowLeft:
          leftUp();
          return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool leftPressed = false;
  bool rightPressed = false;

  void leftUp() {
    if (leftPressed) {
      if (rightPressed) {
        player!.moveXvel = speed;
      } else {
        player!.moveXvel = 0;
      }
      leftPressed = false;
    }
  }

  void rightUp() {
    if (rightPressed) {
      if (leftPressed) {
        player!.moveXvel = -speed;
      } else {
        player!.moveXvel = 0;
      }
      rightPressed = false;
    }
  }

  void leftDown() {
    if (!leftPressed) {
      if (rightPressed) {
        player!.moveXvel = 0;
      } else {
        player!.moveXvel = -speed;
      }
      leftPressed = true;
    }
  }

  void rightDown() {
    if (!rightPressed) {
      if (leftPressed) {
        player!.moveXvel = 0;
      } else {
        player!.moveXvel = speed;
      }
      rightPressed = true;
    }
  }

  void jump() {
    player!.y--;
    if (world!.colliders(player!).isNotEmpty) {
      player!.baseYvel += jumpVel;
    }
    player!.y++;
  }

  void fire() {
    Object fire = Object.xywh(
      player!.x + player!.width,
      player!.y + player!.width ~/ 2,
      10,
      10,
      tags: {'fire', 'float'},
    );
    fire.baseXvel = speed + player!.xvel;
    if (world!.colliders(fire).isEmpty) {
      world!.objects.add(fire);
    }
  }

  void restart() {
    world = World.parse(file!);
    player!.x = 0;
    player!.y = 0;
    player!.height = 50;
    player!.tags.add('player');
    world!.objects.removeWhere((e) => e.tags.contains('player'));
    (teleportedObjects[filename] ??= {}).add(player!);
  }

  @override
  Widget build(BuildContext context) {
    if (world == null) {
      return CircularProgressIndicator();
    }
    return Focus(
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: WorldRenderer(world: world),
    );
  }
}

class WorldRenderer extends StatelessWidget {
  const WorldRenderer({super.key, required this.world});

  final World? world;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(world!.name)),
      body: Center(
        child: Container(
          width: world!.width.toDouble(),
          height: world!.height.toDouble(),
          decoration: BoxDecoration(border: Border.all(color: Colors.white)),
          child: Stack(
            children: [
              ...world!.objects.map(
                (e) => Positioned(
                  bottom: e.y,
                  left: e.x,
                  child: Container(
                    color: e.tags.any((e) => e.startsWith('goto='))
                        ? Colors.green
                        : e.tags.contains('enemy') || e.tags.contains('fire')
                        ? Colors.red
                        : Colors.white,
                    width: e.width,
                    height: e.height,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
