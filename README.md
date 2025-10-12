# Wizard vs red squares
A simple platformer about a wizard and some not-so-friendly red squares.
Based partially on my earlier work \([Wooden Doors 2](github.com/treeplate/doors2)\, a similar platformer).

Written in Dart+Flutter, with a simple physics engine built from scratch.

The game has two spells which you learn during the game, Fire, which shoots a small square that kills enemies, and Fly, which lets you fly around freely without gravity.

This game also has TAS functionality, where you can write a frame-by-frame TAS in the built-in TAS editor, and then play it back.

## TAS Creation
In order to write a TAS for this game, you need to:
1. [download Flutter](https://docs.flutter.dev/get-started/quick)
2. clone this repo
3. go to the directory you cloned it in, and type `flutter run`
4. select a non-web platform when it prompts you
5. in the app, press "Write TAS"
6. Write your TAS!
- The top text field is the list of inputs to do that tick
  - `r`: toggle move right
  - `l`: toggle move left
  - `j`: jump / toggle move up
  - `d`: toggle move down
  - `1`: shoot fire
  - `2`: toggle flying
  - `t`: pick up key
  - As an example, `jr` makes you jump and start moving right, if you are not already moving right.
7. Once you win, you will be prompted to select a file to put your TAS in. If you want to replay your TAS later, choose `<project dir>/tas/level<level number>.lvl.tas`, which should already exist.
8. To replay your TAS, go to the terminal you ran `flutter run` in, type R, and then select "Play TAS".