import 'file_stub.dart' if (dart.library.io) 'dart:io';

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
  Object? carrying;
  int jumpVel = 20;
  int speed = 5;
  Map<String, Set<Object>> teleportedObjects = {
    'level1.lvl': {
      Object.xywh(0, 0, 50, 50, tags: {'player'}),
    },
  };
  bool? readTas;
  bool writeTas = false;
  List<String>? tas;
  int startingMXVel = 0;
  int startingBXVel = 0;
  int startingMYVel = 0;
  int startingBYVel = 0;
  bool startingLeftPressed = false;
  bool startingRightPressed = false;
  bool startingJumpPressed = false;
  bool startingDownPressed = false;
  int tick = 0;
  List<int> times = [];
  bool end = false;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(doTick);
    rootBundle.loadString('levels/level1.lvl').then((final String file) {
      setState(() {
        world = World.parse(file);
        this.file = file;
        player = teleportedObjects['level1.lvl']!.single;
      });
    });
  }

  void start() {
    if (!writeTas) ticker.start();
    if (readTas!) {
      rootBundle.loadString('tas/$filename.tas').then((final String file) {
        tas = file.split('\n');
      });
    } else if (writeTas) {
      tas = [];
    }
  }

  void tickTo(int goal) {
    assert(!readTas! || tas != null);
    while (tick < goal) {
      doTick(Duration(milliseconds: 1000 ~/ 60));
    }
  }

  void tickToEnd() {
    String oldFilename = filename;
    assert(!readTas! || tas != null);
    while (filename == oldFilename) {
      doTick(Duration(milliseconds: 1000 ~/ 60));
    }
  }

  void doTick(Duration duration) {
    if (end) return;
    setState(() {
      if (readTas! && tas == null) {
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
                if (jumpPressed && player!.tags.contains('float')) {
                  jumpUp();
                } else {
                  jumpDown();
                }
              case 'd':
                if (downPressed && player!.tags.contains('float')) {
                  downUp();
                } else {
                  downDown();
                }
              case '1':
                fire();
              case '2':
                if (player!.tags.contains('float')) {
                  player!.tags.remove('float');
                } else {
                  player!.tags.add('float');
                }
              case 'R':
                restart();
              case 't':
                take();
            }
          }
        }
      }
      if (player != null && carrying != null && world != null) {
        carrying!.baseXvel = player!.xvel;
        carrying!.baseYvel = player!.yvel;
        int oldX = carrying!.x;
        int oldY = carrying!.y;
        carrying!.x = player!.x + 50;
        carrying!.y = player!.y;
        if (world!.colliders(carrying!).isNotEmpty) {
          carrying!.x = oldX;
          carrying!.y = oldY;
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
            a.y += 2;
            if (!world!.colliding(a, b)) {
              a.y--;
              continue;
            }
            a.y -= 2;
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
                FilePicker
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
                      if (nextLevel == 'end') {
                        end = true;
                        times.add(tick);
                        return;
                      }

                      tas = [];
                      if (readTas!) {
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
                if (nextLevel == 'end') {
                  end = true;
                  times.add(tick);
                  return;
                }
                tas = [];
                if (readTas!) {
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
              if (nextLevel == 'end') {
                end = true;
                times.add(tick);
                return;
              }
              times.add(tick);
              tick = 0;
              startingBXVel = player!.baseXvel;
              startingBYVel = player!.baseYvel;
              startingMXVel = player!.moveXvel;
              startingMYVel = player!.moveYvel;
              startingLeftPressed = leftPressed;
              startingRightPressed = rightPressed;
              startingJumpPressed = jumpPressed;
              startingDownPressed = downPressed;
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
      if (event.logicalKey == LogicalKeyboardKey.digit2) {
        if (player!.tags.contains('float')) {
          player!.tags.remove('float');
        } else {
          player!.tags.add('float');
        }
        return KeyEventResult.handled;
      }
      switch (event.physicalKey) {
        case PhysicalKeyboardKey.keyW:
        case PhysicalKeyboardKey.space:
        case PhysicalKeyboardKey.arrowUp:
          jumpDown();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyS:
        case PhysicalKeyboardKey.arrowDown:
          downDown();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyD:
        case PhysicalKeyboardKey.arrowRight:
          rightDown();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyA:
        case PhysicalKeyboardKey.arrowLeft:
          leftDown();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyE:
        case PhysicalKeyboardKey.shiftRight:
          take();
          return KeyEventResult.handled;
      }
    } else {
      assert(event is KeyUpEvent);
      switch (event.physicalKey) {
        case PhysicalKeyboardKey.keyW:
        case PhysicalKeyboardKey.space:
        case PhysicalKeyboardKey.arrowUp:
          jumpUp();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyS:
        case PhysicalKeyboardKey.arrowDown:
          downUp();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyD:
        case PhysicalKeyboardKey.arrowRight:
          rightUp();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyA:
        case PhysicalKeyboardKey.arrowLeft:
          leftUp();
          return KeyEventResult.handled;
        case PhysicalKeyboardKey.keyE:
        case PhysicalKeyboardKey.shiftRight:
          return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool leftPressed = false;
  bool rightPressed = false;
  bool jumpPressed = false;
  bool downPressed = false;
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

  void jumpUp() {
    if (!player!.tags.contains('float')) return;
    if (jumpPressed) {
      if (downPressed) {
        player!.moveYvel = -speed;
      } else {
        player!.moveYvel = 0;
      }
      jumpPressed = false;
    }
  }

  void downUp() {
    if (!player!.tags.contains('float')) return;
    if (downPressed) {
      if (jumpPressed) {
        player!.moveYvel = speed;
      } else {
        player!.moveYvel = 0;
      }
      downPressed = false;
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

  void jumpDown() {
    if (player!.tags.contains('float')) {
      if (!jumpPressed) {
        if (!downPressed) {
          player!.moveYvel = speed;
        } else {
          player!.moveYvel = 0;
        }
        jumpPressed = true;
      }
    } else {
      if (!jumped) {
        player!.y--;
        if (world!.colliders(player!).isNotEmpty) {
          player!.baseYvel += jumpVel;
        }
        player!.y++;
        jumped = true;
      }
    }
  }

  void downDown() {
    if (player!.tags.contains('float')) {
      if (!downPressed) {
        if (!jumpPressed) {
          player!.moveYvel = -speed;
        } else {
          player!.moveYvel = 0;
        }
        downPressed = true;
      }
    } else {
      if (!jumped) {
        player!.y++;
        if (world!.colliders(player!).isNotEmpty) {
          player!.baseYvel -= jumpVel;
        }
        player!.y--;
        jumped = true;
      }
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
    player!.tags.remove('float');
    (teleportedObjects[filename] = {}).add(player!);
  }

  void take() {
    if (carrying != null) {
      carrying = null;
      return;
    }
    player!.x += player!.width;
    Object? key = world!
        .colliders(player!)
        .where((e) => e!.tags.contains('key'))
        .firstOrNull;
    carrying = key;
    player!.x -= player!.width;
  }

  FocusNode textField1FocusNode = FocusNode();
  FocusNode textField2FocusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (readTas == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Wizard vs Red Squares')),
        body: Center(
          child: Column(
            children: [
              OutlinedButton(
                onPressed: () {
                  readTas = false;
                  start();
                },
                child: Text('Play normally'),
              ),
              OutlinedButton(
                onPressed: () {
                  readTas = true;
                  start();
                },
                child: Text('Play TAS'),
              ),
              if (Platform.version != 'web')
                OutlinedButton(
                  onPressed: () {
                    readTas = false;
                    writeTas = true;
                    setState(() {
                      start();
                    });
                  },
                  child: Text('Write TAS'),
                ),
              if (Platform.version != 'web')
                OutlinedButton(
                  onPressed: () {
                    readTas = true;
                    writeTas = true;
                    setState(() {
                      start();
                    });
                  },
                  child: Text('Edit TAS'),
                ),
            ],
          ),
        ),
      );
    }
    if (end) {
      return Scaffold(
        appBar: AppBar(title: Text('You Win!')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total time: ${Duration(milliseconds: 1000 ~/ 60) * times.reduce((a, b) => a + b)}',
              ),
              ...times.map((e) {
                return Text('- ${Duration(milliseconds: 1000 ~/ 60) * e}');
              }),
            ],
          ),
        ),
      );
    }
    if (world == null) {
      return CircularProgressIndicator();
    }
    return Focus(
      autofocus: true,
      onKeyEvent: onKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(world!.name),
          bottom: PreferredSize(
            preferredSize: Size.zero,
            child: Text(
              '${times.isEmpty ? Duration(milliseconds: 1000 ~/ 60) * tick : Duration(milliseconds: 1000 ~/ 60) * (tick + times.reduce((a, b) => a + b))} (${Duration(milliseconds: 1000 ~/ 60) * tick})',
            ),
          ),
        ),
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
                        bottom: e.y.toDouble(),
                        left: e.x.toDouble(),
                        child: Container(
                          color: e.tags.any((e) => e.startsWith('goto='))
                              ? Colors.green
                              : e.tags.contains('enemy') ||
                                    e.tags.contains('fire')
                              ? Colors.red
                              : e.tags.contains('key')
                              ? Colors.yellow
                              : e.tags.contains('door')
                              ? Colors.brown
                              : Colors.white,
                          width: e.width.toDouble(),
                          height: e.height.toDouble(),
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
                              setState(() {
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
                                  leftPressed = startingLeftPressed;
                                  rightPressed = startingRightPressed;
                                  jumpPressed = startingJumpPressed;
                                  downPressed = startingDownPressed;
                                }
                                tickTo(goal);
                              });
                            },
                            child: Text('Go to tick'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                tickToEnd();
                              });
                            },
                            child: Text('Next Level'),
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
