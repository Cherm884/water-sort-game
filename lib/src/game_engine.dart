import 'dart:math';
import 'package:water_sort/src/constants.dart';

class TubeData {
  final int id;
  final int capacity;
  List<String> colors;

  TubeData({required this.id, required this.capacity, required this.colors});

  TubeData copy() {
    return TubeData(id: id, capacity: capacity, colors: List.from(colors));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'capacity': capacity,
    'colors': colors,
  };
}

class GameEngine {
  static List<TubeData> generateLevel(LevelConfig config) {
    List<TubeData> tubes = [];
    List<String> usedColors = kColorKeys.sublist(0, config.colorCount);

    for (int i = 0; i < config.colorCount; i++) {
      tubes.add(
        TubeData(
          id: i,
          capacity: kTubeCapacity,
          colors: List.filled(kTubeCapacity, usedColors[i], growable: true),
        ),
      );
    }

    for (int i = config.colorCount; i < config.colorCount + config.emptyTubes; i++) {
      tubes.add(TubeData(id: i, capacity: kTubeCapacity, colors: []));
    }

    int moves = 0;
    int maxAttempts = config.shuffleMoves * 10;
    int attempts = 0;
    Random random = Random();

    while (moves < config.shuffleMoves && attempts < maxAttempts) {
      attempts++;
      int sourceIdx = random.nextInt(tubes.length);
      int targetIdx = random.nextInt(tubes.length);

      if (sourceIdx == targetIdx) continue;

      var source = tubes[sourceIdx];
      var target = tubes[targetIdx];

      if (source.colors.isEmpty) continue;
      if (target.colors.length >= target.capacity) continue;

      String color = source.colors.removeLast();
      target.colors.add(color);
      moves++;
    }

    return tubes;
  }

  static bool isValidMove(TubeData source, TubeData target) {
    if (source.colors.isEmpty) return false;
    if (target.colors.length >= target.capacity) return false;
    if (target.colors.isEmpty) return true;
    return source.colors.last == target.colors.last;
  }

  // New helper to get the color string for animation
  static String? getTopColor(List<TubeData> tubes, int tubeId) {
    final tube = tubes.firstWhere((t) => t.id == tubeId);
    if (tube.colors.isEmpty) return null;
    return tube.colors.last;
  }

  static List<TubeData> performMove(
    List<TubeData> currentTubes,
    int sourceId,
    int targetId,
  ) {
    List<TubeData> newTubes = currentTubes.map((t) => t.copy()).toList();

    var source = newTubes.firstWhere((t) => t.id == sourceId);
    var target = newTubes.firstWhere((t) => t.id == targetId);

    if (!isValidMove(source, target)) return currentTubes;

    String colorToMove = source.colors.last;

    while (source.colors.isNotEmpty &&
        source.colors.last == colorToMove &&
        target.colors.length < target.capacity) {
      source.colors.removeLast();
      target.colors.add(colorToMove);
    }

    return newTubes;
  }

  static bool checkWin(List<TubeData> tubes) {
    for (var tube in tubes) {
      if (tube.colors.isEmpty) continue;
      if (tube.colors.length != tube.capacity) return false;
      String first = tube.colors.first;
      if (tube.colors.any((c) => c != first)) return false;
    }
    return true;
  }

  static List<int>? getHint(List<TubeData> tubes) {
    // 1. Priority: Find a move that stacks matching colors (not moving to empty)
    for (var source in tubes) {
      if (source.colors.isEmpty) continue;
      
      if (source.colors.length == source.capacity && 
          source.colors.every((c) => c == source.colors.first)) {
        continue;
      }

      for (var target in tubes) {
        if (source.id == target.id) continue;
        if (!isValidMove(source, target)) continue;
        if (target.colors.isNotEmpty) {
           return [source.id, target.id];
        }
      }
    }

    // 2. Secondary: Move to empty
    for (var source in tubes) {
      if (source.colors.isEmpty) continue;
      bool isUniform = source.colors.every((c) => c == source.colors.first);
      if (isUniform) continue; 

      for (var target in tubes) {
        if (source.id == target.id) continue;
        if (isValidMove(source, target) && target.colors.isEmpty) {
           return [source.id, target.id];
        }
      }
    }
    
    // 3. Last Resort
    for (var source in tubes) {
       if (source.colors.isEmpty) continue;
       for (var target in tubes) {
          if (source.id == target.id) continue;
          if (isValidMove(source, target)) {
             return [source.id, target.id];
          }
       }
    }

    return null;
  }
}