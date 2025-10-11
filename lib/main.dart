import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

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
  String filename = 'level1.lvl';
  late final Ticker ticker;
  final FocusNode focusNode = FocusNode();
  Object? player;
  int jumpVel = 20;
  int speed = 5;
  Map<String, Set<Object>> teleportedObjects = {};
  bool readTas = true;
  bool writeTas = false;
  List<String>? tas;
  int startingMXVel = 0;
  int startingBXVel = 0;
  int startingMYVel = 0;
  int startingBYVel = 0;
  int tick = 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(doTick);
    if (!writeTas) ticker.start();
    rootBundle.loadString('levels/level1.lvl').then((final String file) {
      setState(() {
        world = World.parse(file);
        this.file = file;
        player = world!.objects.singleWhere((e) => e.tags.contains('player'));
      });
    });
    if (readTas) {
      rootBundle.loadString('tas/$filename.tas').then((final String file) {
        tas = file.split('\n');
      });
    } else if (writeTas) {
      tas = [];
    }
  }

  void tickTo(int goal) {
    assert(!readTas || tas != null);
    while (tick < goal) {
      doTick(Duration(milliseconds: 1000 ~/ 60));
    }
  }

  void doTick(Duration duration) {
    setState(() {
      if (readTas && tas == null) {
        return;
      }
      if (tas != null) {
        if (tick < tas!.length && tas![tick] != '') {
          List<String> events = tas![tick].split('');
          for (String event in events) {
            switch (event) {
              case 'r':
                if (rightPressed) {
                  rightUp();
                } else {
                  rightDown();
                }
              case 'l':
                if (leftPressed) {
                  leftUp();
                } else {
                  leftDown();
                }
              case 'j':
                jump();
              case '1':
                fire();
              case 'R':
                restart();
            }
          }
        }
      }
      world?.tick();
      tick++;
      jumped = false;
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
              if (writeTas) {
                FilePickerMacOS()
                    .pickFiles(
                      dialogTitle: 'Save TAS to:',
                      type: FileType.custom,
                      allowedExtensions: ['tas'],
                    )
                    .then((FilePickerResult? result) {
                      if (result != null) {
                        File(
                          result.files.first.path!,
                        ).writeAsStringSync(tas!.join('\n'));
                      }

                      tas = [];
                      if (readTas) {
                        rootBundle
                            .loadString('tas/$filename.tas')
                            .then((final String file) {
                              tas = file.split('\n');
                            })
                            .onError((e, st) {
                              if (writeTas) {
                                tas = [];
                              } else {
                                throw e!;
                              }
                            });
                      }
                    });
              } else {
                tas = [];
                if (readTas) {
                  rootBundle
                      .loadString('tas/$filename.tas')
                      .then((final String file) {
                        tas = file.split('\n');
                      })
                      .onError((e, st) {
                        if (writeTas) {
                          tas = [];
                        } else {
                          throw e!;
                        }
                      });
                }
              }
              tick = 0;
              startingBXVel = player!.baseXvel;
              startingBYVel = player!.baseYvel;
              startingMXVel = player!.moveXvel;
              startingMYVel = player!.moveYvel;
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
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  KeyEventResult onKeyEvent(FocusNode node, KeyEvent event) {
    if (textField1FocusNode.hasFocus || textField2FocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
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
  bool jumped = false;

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
    if (!jumped) {
      player!.y--;
      if (world!.colliders(player!).isNotEmpty) {
        player!.baseYvel += jumpVel;
      }
      player!.y++;
      jumped = true;
    }
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
    tick = 0;
    world = World.parse(file!);
    player!.x = 0;
    player!.y = 0;
    player!.height = 50;
    player!.tags.add('player');
    world!.objects.removeWhere((e) => e.tags.contains('player'));
    (teleportedObjects[filename] ??= {}).add(player!);
  }

  FocusNode textField1FocusNode = FocusNode();
  FocusNode textField2FocusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (world == null) {
      return CircularProgressIndicator();
    }
    return Focus(
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: Scaffold(
        appBar: AppBar(title: Text(world!.name)),
        body: Center(
          child: Row(
            children: [
              Expanded(child: SizedBox()),
              Container(
                width: world!.width.toDouble(),
                height: world!.height.toDouble(),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                ),
                child: Stack(
                  children: [
                    ...world!.objects.map(
                      (e) => Positioned(
                        bottom: e.y,
                        left: e.x,
                        child: Container(
                          color: e.tags.any((e) => e.startsWith('goto='))
                              ? Colors.green
                              : e.tags.contains('enemy') ||
                                    e.tags.contains('fire')
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
              Expanded(
                child: writeTas
                    ? Column(
                        children: [
                          Text('Tick $tick'),
                          TextField(
                            focusNode: textField1FocusNode,
                            controller: TextEditingController(
                              text: tick < tas!.length ? tas![tick] : '',
                            ),
                            onChanged: (value) {
                              while (tick >= tas!.length) {
                                tas!.add('');
                              }
                              tas![tick] = value;
                            },
                          ),
                          OutlinedButton(
                            onPressed: () {
                              doTick(Duration.zero);
                            },
                            child: Text('Run'),
                          ),
                          TextField(
                            focusNode: textField2FocusNode,
                            controller: textEditingController,
                          ),
                          OutlinedButton(
                            onPressed: () {
                              int? goal = int.tryParse(
                                textEditingController.text,
                              );
                              if (goal == null) return;
                              if (goal < tick) {
                                restart();
                                player!.moveXvel = startingMXVel;
                                player!.moveYvel = startingMYVel;
                                player!.baseXvel = startingBXVel;
                                player!.baseYvel = startingBYVel;
                              }
                              tickTo(goal);
                            },
                            child: Text('Go to tick'),
                          ),
                        ],
                      )
                    : SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
