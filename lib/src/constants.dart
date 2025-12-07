// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard, extraHard }

class LevelConfig {
  final int id;
  final Difficulty difficulty;
  final int tubeCount;
  final int emptyTubes;
  final int colorCount;
  final int shuffleMoves;

  LevelConfig({
    required this.id,
    required this.difficulty,
    required this.tubeCount,
    required this.emptyTubes,
    required this.colorCount,
    required this.shuffleMoves,
  });
}

const int kTubeCapacity = 4;
const int kLevelsPerDifficulty = 25;

const Map<String, Color> kColors = {
  'Red': Color(0xFFFF3B30),
  'Blue': Color(0xFF007AFF),
  'Green': Color(0xFF34C759),
  'Yellow': Color(0xFFFFCC00),
  'Orange': Color(0xFFFF9500),
  'Purple': Color(0xFFAF52DE),
  'Cyan': Color(0xFF32ADE6),
  'Brown': Color(0xFFA2845E),
  'Gray': Color(0xFF8E8E93),
  'Lime': Color(0xFFA4C400),
  'Navy': Color(0xFF004080),
  'Teal': Color(0xFF30B0C7),
  'Magenta': Color(0xFFE056FD),
  'Gold': Color(0xFFFFD60A),
  'Silver': Color(0xFFB0B0B5),
  'Coral': Color(0xFFFF7F50),
  'Mint': Color(0xFF00C7BE),
  'Lavender': Color(0xFFD9B9FA),
  'Dark Red': Color(0xFF8B0000),
};

final List<String> kColorKeys = kColors.keys.toList();

LevelConfig getLevelConfig(Difficulty difficulty, int levelIndex) {
  int tubeCount = 4;
  int emptyTubes = 2;
  int shuffleMoves = 20;

  switch (difficulty) {
    case Difficulty.easy:
      tubeCount = 4 + (levelIndex ~/ 10);
      if (tubeCount > 5) tubeCount = 5;
      shuffleMoves = 20 + levelIndex;
      break;
    case Difficulty.medium:
      tubeCount = 6 + (levelIndex ~/ 8);
      if (tubeCount > 8) tubeCount = 8;
      shuffleMoves = 30 + (levelIndex * 2);
      break;
    case Difficulty.hard:
      tubeCount = 9 + (levelIndex ~/ 12);
      if (tubeCount > 10) tubeCount = 10;
      shuffleMoves = 50 + (levelIndex * 3);
      break;
    case Difficulty.extraHard:
      tubeCount = 11 + (levelIndex ~/ 10);
      if (tubeCount > 12) tubeCount = 12;
      shuffleMoves = 80 + (levelIndex * 5);
      break;
  }

  return LevelConfig(
    id: levelIndex + 1,
    difficulty: difficulty,
    tubeCount: tubeCount,
    emptyTubes: emptyTubes,
    colorCount: tubeCount - emptyTubes,
    shuffleMoves: shuffleMoves,
  );
}

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1E1C2A)),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.15),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}