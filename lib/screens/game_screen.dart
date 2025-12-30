// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_sort/src/constants.dart';
import 'package:water_sort/src/game_engine.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final int levelIndex;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.levelIndex,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late List<TubeData> _tubes;
  List<List<TubeData>> _history = [];
  int? _selectedTubeId;
  int _currentLevelId = 1;
  bool _isCompleted = false;

  // Animation Variables
  late AnimationController _pourController;
  final Map<int, GlobalKey> _tubeKeys = {};
  int? _animatingSourceId;
  int? _animatingTargetId;
  String? _animatingColor;
  Offset? _sourcePos;
  Offset? _targetPos;
  int _pouringAmount = 0; // Track how much liquid is being poured

  @override
  void initState() {
    super.initState();
    _pourController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _pourController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finalizeMove();
      }
    });

    _startLevel();
  }

  @override
  void dispose() {
    _pourController.dispose();
    super.dispose();
  }

  void _startLevel() {
    final config = getLevelConfig(widget.difficulty, widget.levelIndex);
    setState(() {
      _currentLevelId = config.id;
      _tubes = GameEngine.generateLevel(config);
      _history = [];
      _selectedTubeId = null;
      _isCompleted = false;
      
      // Reset keys for new level
      _tubeKeys.clear();
      for (var tube in _tubes) {
        _tubeKeys[tube.id] = GlobalKey();
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        'chromaflow_last_difficulty',
        widget.difficulty.toString(),
      );
    });
  }

  void _handleTubeTap(int id) {
    if (_isCompleted || _pourController.isAnimating) return;

    if (_selectedTubeId == null) {
      final tube = _tubes.firstWhere((t) => t.id == id);
      if (tube.colors.isNotEmpty) {
        setState(() => _selectedTubeId = id);
        HapticFeedback.lightImpact();
      }
    } else {
      if (_selectedTubeId == id) {
        setState(() => _selectedTubeId = null);
      } else {
        _initiateMoveAnimation(_selectedTubeId!, id);
      }
    }
  }

  // Step 1: Check Validity and Start Animation
  void _initiateMoveAnimation(int sourceId, int targetId) {
    final sourceTube = _tubes.firstWhere((t) => t.id == sourceId);
    final targetTube = _tubes.firstWhere((t) => t.id == targetId);

    if (GameEngine.isValidMove(sourceTube, targetTube)) {
      // Get positions
      final RenderBox? sourceBox = _tubeKeys[sourceId]?.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? targetBox = _tubeKeys[targetId]?.currentContext?.findRenderObject() as RenderBox?;

      if (sourceBox != null && targetBox != null) {
        // Find absolute positions
        final sourceOffset = sourceBox.localToGlobal(Offset.zero);
        final targetOffset = targetBox.localToGlobal(Offset.zero);
        
        // Calculate how much liquid will be poured
        final colorToMove = sourceTube.colors.last;
        int pourCount = 0;
        for (int i = sourceTube.colors.length - 1; i >= 0; i--) {
          if (sourceTube.colors[i] == colorToMove && 
              targetTube.colors.length + pourCount < targetTube.capacity) {
            pourCount++;
          } else {
            break;
          }
        }
        
        setState(() {
          _animatingSourceId = sourceId;
          _animatingTargetId = targetId;
          _animatingColor = GameEngine.getTopColor(_tubes, sourceId);
          _pouringAmount = pourCount;
          
          // Calculate top-center of tubes
          _sourcePos = Offset(sourceOffset.dx + sourceBox.size.width / 2, sourceOffset.dy + 10);
          _targetPos = Offset(targetOffset.dx + targetBox.size.width / 2, targetOffset.dy + 10);
        });

        _pourController.forward(from: 0.0);
      } else {
        // Fallback if render objects not found
        _finalizeMoveDirectly(sourceId, targetId);
      }
    } else {
      // Invalid move
      setState(() => _selectedTubeId = null);
      HapticFeedback.heavyImpact();
    }
  }

  // Step 2: Update Data after Animation
  void _finalizeMove() {
    if (_animatingSourceId != null && _animatingTargetId != null) {
      _finalizeMoveDirectly(_animatingSourceId!, _animatingTargetId!);
    }
  }

  void _finalizeMoveDirectly(int sourceId, int targetId) async {
    // Reset animation state
    _pourController.reset();
    
    final newTubes = GameEngine.performMove(_tubes, sourceId, targetId);
    final oldSource = _tubes.firstWhere((t) => t.id == sourceId);
    final newSource = newTubes.firstWhere((t) => t.id == sourceId);

    if (oldSource.colors.length != newSource.colors.length) {
      setState(() {
        _history.add(_tubes.map((t) => t.copy()).toList());
        _tubes = newTubes;
        _selectedTubeId = null;
        
        // Clear animation vars
        _animatingSourceId = null;
        _animatingTargetId = null;
        _sourcePos = null;
        _targetPos = null;
        _pouringAmount = 0;
      });
      HapticFeedback.mediumImpact();

      if (GameEngine.checkWin(_tubes)) {
        setState(() => _isCompleted = true);
        await Future.delayed(const Duration(milliseconds: 500));
        _showWinDialog();
        _saveProgress();
      }
    } else {
      setState(() {
        _selectedTubeId = null;
        _animatingSourceId = null;
        _animatingTargetId = null;
      });
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chromaflow_progress_${widget.difficulty}';
    final currentMax = prefs.getInt(key) ?? 1;
    if (_currentLevelId + 1 > currentMax) {
      await prefs.setInt(key, _currentLevelId + 1);
    }
  }

  void _undo() {
    if (_history.isNotEmpty && !_pourController.isAnimating) {
      setState(() {
        _tubes = _history.removeLast();
        _selectedTubeId = null;
      });
    }
  }

  void _showHint() {
    if (_isCompleted || _pourController.isAnimating) return;
    
    final hintMove = GameEngine.getHint(_tubes);
    
    if (hintMove != null) {
      final sourceId = hintMove[0];
      final targetId = hintMove[1];
      
      setState(() {
        _selectedTubeId = sourceId;
      });
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.yellowAccent),
              const SizedBox(width: 10),
              Text(
                'Hint: Move to Tube ${targetId + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.blueAccent,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No moves available! Try undoing or restarting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'LEVEL CLEARED!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Great job!',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _goToNextLevel();
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      try {
        Navigator.of(context).pop();
      } catch (_) {}
      _goToNextLevel();
    });
  }

  void _goToNextLevel() {
    final nextIndex = widget.levelIndex + 1;
    if (nextIndex < kLevelsPerDifficulty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GameScreen(difficulty: widget.difficulty, levelIndex: nextIndex),
        ),
      );
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCrowded = _tubes.length > 8;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1C2A),
      body: Stack(
        children: [
          // Layer 1: The Main UI
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.black),
                          onPressed: () =>
                              Navigator.popUntil(context, (route) => route.isFirst),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            widget.difficulty.name.toUpperCase().replaceAll(
                              'EXTRAHARD',
                              'EXPERT',
                            ),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'LEVEL $_currentLevelId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          onPressed: _startLevel,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: isCrowded ? 15 : 30,
                        runSpacing: isCrowded ? 10 : 40,
                        children: _tubes.map((tube) {
                          // Ensure key exists
                          if (!_tubeKeys.containsKey(tube.id)) {
                             _tubeKeys[tube.id] = GlobalKey();
                          }
                          
                          return TubeWidget(
                            key: _tubeKeys[tube.id],
                            data: tube,
                            isSelected: _selectedTubeId == tube.id,
                            isAnimatingSource: _animatingSourceId == tube.id,
                            onTap: () => _handleTubeTap(tube.id),
                            scale: isCrowded ? 0.85 : 1.0,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GameControl(
                        icon: Icons.undo,
                        label: 'Undo',
                        color: Colors.amber,
                        onTap: _undo,
                        disabled: _history.isEmpty || _pourController.isAnimating,
                      ),
                      _GameControl(
                        icon: Icons.lightbulb,
                        label: 'Hint',
                        color: Colors.lightGreen,
                        onTap: _showHint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Layer 2: The Liquid Stream Animation
          if (_pourController.isAnimating && _sourcePos != null && _targetPos != null && _animatingColor != null)
             AnimatedBuilder(
               animation: _pourController,
               builder: (ctx, child) {
                 return CustomPaint(
                   painter: RealisticWaterPourPainter(
                     start: _sourcePos!,
                     end: _targetPos!,
                     color: kColors[_animatingColor] ?? Colors.blue,
                     progress: _pourController.value,
                     pouringAmount: _pouringAmount,
                   ),
                   size: MediaQuery.of(context).size,
                 );
               },
             ),
        ],
      ),
    );
  }
}

class RealisticWaterPourPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double progress;
  final int pouringAmount;

  RealisticWaterPourPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
    required this.pouringAmount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final dxDir = end.dx > start.dx ? 1 : -1;
    final realStart = start + Offset(18.0 * dxDir, -8);
    
    // Calculate the main stream path with a more natural curve
    final controlPoint1 = Offset(
      realStart.dx + (end.dx - realStart.dx) * 0.3,
      min(realStart.dy, end.dy) - 80,
    );
    final controlPoint2 = Offset(
      realStart.dx + (end.dx - realStart.dx) * 0.7,
      min(realStart.dy, end.dy) - 50,
    );

    final path = Path();
    path.moveTo(realStart.dx, realStart.dy);
    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      end.dx, end.dy,
    );

    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    
    // Calculate stream progress - continuous flow
    double streamProgress = progress;
    if (progress > 0.7) {
      // Start tapering off
      streamProgress = 1.0 - ((progress - 0.7) / 0.3);
    }
    
    final currentLength = totalLength * streamProgress;
    
    // Draw main stream with varying width
    final streamPath = metrics.extractPath(0, currentLength);
    
    // Create gradient for the stream (darker at edges, lighter in center)
    final streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    // Draw multiple layers for depth
    // Outer shadow layer
    streamPaint
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 16.0;
    canvas.drawPath(streamPath, streamPaint);
    
    // Main stream layer
    streamPaint
      ..color = color
      ..strokeWidth = 14.0;
    canvas.drawPath(streamPath, streamPaint);
    
    // Inner highlight layer (brighter)
    streamPaint
      ..color = Color.fromARGB(
        (color.alpha * 0.95).round().clamp(0, 255),
        (color.red * 1.1).round().clamp(0, 255),
        (color.green * 1.1).round().clamp(0, 255),
        (color.blue * 1.1).round().clamp(0, 255),
      )
      ..strokeWidth = 10.0;
    canvas.drawPath(streamPath, streamPaint);
    
    // Add shine/reflection on top
    streamPaint
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 6.0;
    canvas.drawPath(streamPath, streamPaint);

    // Draw water droplets along the stream
    final dropletCount = (currentLength / 15).floor();
    for (int i = 0; i < dropletCount; i++) {
      final t = (i / dropletCount) * streamProgress;
      if (t > streamProgress) continue;
      
      final tangent = metrics.getTangentForOffset(totalLength * t);
      if (tangent != null) {
        final pos = tangent.position;
        final dropletPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        
        // Random size variation for realism
        final size = 3.0 + (i % 3) * 1.5;
        canvas.drawCircle(pos, size, dropletPaint);
        
        // Add highlight to droplets
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos + Offset(-1, -1), size * 0.4, highlightPaint);
      }
    }

    // Draw splash effect at the target when stream reaches
    if (progress > 0.3 && progress < 0.9) {
      final splashProgress = ((progress - 0.3) / 0.6).clamp(0.0, 1.0);
      final splashPaint = Paint()
        ..color = color.withOpacity(0.6 * (1 - splashProgress))
        ..style = PaintingStyle.fill;
      
      // Draw multiple splash particles
      for (int i = 0; i < 8; i++) {
        final angle = (i / 8) * 2 * pi;
        final distance = 8.0 + splashProgress * 15.0;
        final splashPos = end + Offset(
          cos(angle) * distance,
          sin(angle) * distance,
        );
        final splashSize = 2.0 + splashProgress * 3.0;
        canvas.drawCircle(splashPos, splashSize, splashPaint);
      }
      
      // Draw ripples
      for (int i = 0; i < 3; i++) {
        final rippleProgress = (splashProgress - i * 0.3).clamp(0.0, 1.0);
        if (rippleProgress > 0) {
          final ripplePaint = Paint()
            ..color = color.withOpacity(0.3 * (1 - rippleProgress))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          final rippleRadius = 5.0 + rippleProgress * 12.0;
          canvas.drawCircle(end, rippleRadius, ripplePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RealisticWaterPourPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.start != start ||
           oldDelegate.end != end;
  }
}

class _GameControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  const _GameControl({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Column(
        children: [
          GestureDetector(
            onTap: disabled ? null : onTap,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TubeWidget extends StatelessWidget {
  final TubeData data;
  final bool isSelected;
  final bool isAnimatingSource;
  final VoidCallback onTap;
  final double scale;

  const TubeWidget({
    super.key,
    required this.data,
    required this.isSelected,
    this.isAnimatingSource = false,
    required this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // If this is the source of the animation, we rotate it slightly
    // to simulate "pouring"
    final double rotation = isAnimatingSource ? 0.4 : 0.0; // 0.4 radians approx 23 degrees
    
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: rotation),
        builder: (context, angle, child) {
          return Transform.rotate(
            angle: angle,
            alignment: Alignment.bottomRight,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isSelected ? -20 : 0, 0)
            ..scale(scale),
          width: 55,
          height: 180,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.yellowAccent.withOpacity(0.8)
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.yellowAccent.withOpacity(0.2),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: data.colors.reversed.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final colorKey = entry.value;
                    final isTopLayer = index == 0;
                    
                    return Container(
                      height: 180 / kTubeCapacity,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kColors[colorKey] ?? Colors.red,
                        // Add subtle gradient for depth
                        gradient: isTopLayer
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (kColors[colorKey] ?? Colors.red).withOpacity(0.9),
                                  kColors[colorKey] ?? Colors.red,
                                ],
                              )
                            : null,
                      ),
                      child: isTopLayer
                          ? Container(
                              decoration: BoxDecoration(
                                // Add shine effect on top layer
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  width: 56,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (isSelected && !isAnimatingSource)
                Positioned(
                    top: -30,
                    child: Icon(Icons.arrow_downward,
                        color: Colors.yellowAccent, size: 24))
            ],
          ),
        ),
      ),
    );
  }
}