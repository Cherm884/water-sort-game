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
  double _tiltDirection = 1.0; // +1 = tilt right, -1 = tilt left
  Offset? _sourceOriginalPos; // Store original position
  int _pouringAmount = 0; // Track how much liquid is being poured
  Size? _sourceSize; // Store source tube size
  bool _moveAppliedEarly = false; // Whether we already applied the move to tube data

  @override
  void initState() {
    super.initState();
    _pourController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Longer for move + pour + return
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
        
        // Calculate positions (centers of the tubes)
        final sourceCenter = Offset(
          sourceOffset.dx + sourceBox.size.width / 2,
          sourceOffset.dy + sourceBox.size.height / 2,
        );
        final targetCenter = Offset(
          targetOffset.dx + targetBox.size.width / 2,
          targetOffset.dy + targetBox.size.height / 2,
        );
        final horizontalDir = targetCenter.dx >= sourceCenter.dx ? 1.0 : -1.0;

        // Apply the move immediately so the colors in the tubes update at once.
        // Keep a snapshot in history for undo.
        final previousSnapshot = _tubes.map((t) => t.copy()).toList();
        final previewTubes = GameEngine.performMove(_tubes, sourceId, targetId);

        final oldSourcePreview = _tubes.firstWhere((t) => t.id == sourceId);
        final newSourcePreview = previewTubes.firstWhere((t) => t.id == sourceId);

        // If nothing actually changed, don't animate.
        if (oldSourcePreview.colors.length == newSourcePreview.colors.length) {
          return;
        }
        
        setState(() {
          // Update tubes immediately for visual sync
          _history.add(previousSnapshot);
          _tubes = previewTubes;
          _moveAppliedEarly = true;

          _animatingSourceId = sourceId;
          _animatingTargetId = targetId;
          // Use the original top color from the source tube for the pouring effect
          _animatingColor = colorToMove;
          _pouringAmount = pourCount;
          
          // Store original position (center of tube)
          _sourceOriginalPos = sourceCenter;
          _sourceSize = sourceBox.size;
          _tiltDirection = horizontalDir;
          
          // Calculate pour positions (top of tubes)
          _sourcePos = Offset(sourceCenter.dx, sourceOffset.dy + 15);
          _targetPos = Offset(targetCenter.dx, targetOffset.dy + 15);
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

    if (_moveAppliedEarly) {
      // Move already applied at the start of the animation.
      setState(() {
        _selectedTubeId = null;
        
        // Clear animation vars
        _animatingSourceId = null;
        _animatingTargetId = null;
        _sourcePos = null;
        _targetPos = null;
        _sourceOriginalPos = null;
        _sourceSize = null;
        _pouringAmount = 0;
        _moveAppliedEarly = false;
      });
      HapticFeedback.mediumImpact();

      if (GameEngine.checkWin(_tubes)) {
        setState(() => _isCompleted = true);
        await Future.delayed(const Duration(milliseconds: 500));
        _showWinDialog();
        _saveProgress();
      }
      return;
    }
    
    // Fallback path (no early move applied, e.g. if animation skipped)
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
        _sourceOriginalPos = null;
        _sourceSize = null;
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
        _sourceOriginalPos = null;
        _sourceSize = null;
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
                          
                          // Hide the source tube during animation (it will be shown as floating)
                          final isHiddenSource = _animatingSourceId == tube.id && _pourController.isAnimating;
                          
                          return Opacity(
                            opacity: isHiddenSource ? 0.0 : 1.0,
                            child: TubeWidget(
                              key: _tubeKeys[tube.id],
                              data: tube,
                              isSelected: _selectedTubeId == tube.id,
                              isAnimatingSource: false, // Don't show rotation in original position
                              onTap: () => _handleTubeTap(tube.id),
                              scale: isCrowded ? 0.85 : 1.0,
                            ),
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
          
          // Layer 2: Moving Source Tube + Pouring Animation
          if (_pourController.isAnimating && 
              _animatingSourceId != null && 
              _sourceOriginalPos != null && 
              _targetPos != null && 
              _sourceSize != null &&
              _animatingColor != null)
             AnimatedBuilder(
               animation: _pourController,
               builder: (ctx, child) {
                 // Animation phases:
                 // 0.0 - 0.3: Move to target
                 // 0.3 - 0.7: Pour liquid
                 // 0.7 - 1.0: Move back
                 
                final progress = _pourController.value;
                 Offset currentPos;
                 double rotation = 0.0;
                 double pourProgress = 0.0;

                 // Target position for the CENTER of the moving tube when crossing the target.
                 // We offset the center opposite the tilt direction so that the mouth
                 // of the tube visually sits above the center of the target tube.
                 final Offset crossCenter = Offset(
                   _targetPos!.dx - _tiltDirection * (_sourceSize!.width * 0.25),
                   _targetPos!.dy + _sourceSize!.height / 2 - 15,
                 );
                 
                 if (progress < 0.3) {
                   // Moving to crossing position above target
                   final moveProgress = progress / 0.3;
                   currentPos = Offset.lerp(_sourceOriginalPos!, crossCenter, moveProgress)!;
                   rotation = 0.5 * moveProgress * _tiltDirection; // Tilt towards target
                 } else if (progress < 0.7) {
                   // At target, pouring while crossing
                   currentPos = crossCenter;
                   rotation = 0.5 * _tiltDirection; // Fully tilted towards target
                   pourProgress = (progress - 0.3) / 0.4; // 0 to 1 during pour phase
                 } else {
                   // Moving back from crossing position to original place
                   final returnProgress = (progress - 0.7) / 0.3;
                   currentPos = Offset.lerp(crossCenter, _sourceOriginalPos!, returnProgress)!;
                   rotation = 0.5 * (1 - returnProgress) * _tiltDirection; // Untilt back
                 }
                 
                 return Stack(
                   clipBehavior: Clip.none,
                   children: [
                     // Floating source tube
                     Positioned(
                       left: currentPos.dx - _sourceSize!.width / 2,
                       top: currentPos.dy - _sourceSize!.height / 2,
                       child: Transform.rotate(
                         angle: rotation,
                         alignment: _tiltDirection >= 0 ? Alignment.bottomRight : Alignment.bottomLeft,
                         child: TubeWidget(
                           data: _tubes.firstWhere((t) => t.id == _animatingSourceId),
                           isSelected: false,
                           isAnimatingSource: false, // rotation handled here
                           onTap: () {},
                           scale: 1.0,
                         ),
                       ),
                     ),
                     // Pouring stream (only during pour phase) - full screen overlay
                     if (progress >= 0.3 && progress < 0.7)
                       Positioned.fill(
                         child: CustomPaint(
                           painter: SimpleWaterPourPainter(
                             // Start directly above the target tube center, but higher up near the tube mouth
                             start: Offset(
                               _targetPos!.dx,
                               currentPos.dy - _sourceSize!.height / 2 + 15,
                             ),
                             end: _targetPos!,
                             color: kColors[_animatingColor] ?? Colors.blue,
                             progress: pourProgress,
                           ),
                         ),
                       ),
                   ],
                 );
               },
             ),
        ],
      ),
    );
  }
}

class SimpleWaterPourPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double progress;

  SimpleWaterPourPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    // Draw a simple vertical stream (thick solid bar)
    final streamPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Calculate stream length
    final streamLength = (end.dy - start.dy) * progress;
    final streamTop = start.dy;
    final streamBottom = start.dy + streamLength;
    
    // Draw thick vertical stream (like in the image)
    final streamWidth = 14.0;
    final streamRect = Rect.fromLTWH(
      start.dx - streamWidth / 2,
      streamTop,
      streamWidth,
      streamLength,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(streamRect, const Radius.circular(7)),
      streamPaint,
    );
    
    // Draw pool/blob at target when stream reaches
    if (progress > 0.2) {
      final poolProgress = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
      final poolSize = 8.0 + poolProgress * 12.0; // Grow from 8 to 20
      final poolPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(end, poolSize, poolPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SimpleWaterPourPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.start != start ||
           oldDelegate.end != end;
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

    // We want a straight vertical stream like the reference image.
    // The stream should fall vertically above the target tube.

    // Mouth position of the pouring tube (start of the stream)
    final mouth = start;

    // Impact point on the target tube (top center)
    final impact = end;

    // Use the target tube's x-coordinate so the stream is perfectly vertical.
    final streamX = impact.dx;

    // Total vertical distance from mouth to impact.
    final totalDy = impact.dy - mouth.dy;

    // Animate the length of the stream over time.
    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0));
    final currentDy = totalDy * t;

    // Current end of the stream (cannot go below impact point).
    final currentEndY = (mouth.dy + currentDy).clamp(mouth.dy, impact.dy);
    final startPoint = Offset(streamX, mouth.dy);
    final endPoint = Offset(streamX, currentEndY);

    // Main stream
    final streamPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    canvas.drawLine(startPoint, endPoint, streamPaint);

    // Soft outer glow to match the polished look.
    final glowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14.0;
    canvas.drawLine(startPoint, endPoint, glowPaint);

    // Circular pool at the impact point, grows slightly during the pour.
    if (progress > 0.25) {
      final poolT = Curves.easeOut.transform(((progress - 0.25) / 0.75).clamp(0.0, 1.0));
      final poolRadius = 8.0 + 4.0 * poolT;

      final poolPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final poolGlowPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      final poolCenter = Offset(streamX, impact.dy + 4);

      canvas.drawCircle(poolCenter, poolRadius + 2, poolGlowPaint);
      canvas.drawCircle(poolCenter, poolRadius, poolPaint);
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
    // Constants matching the Vector Art style
    const double tubeWidth = 50.0;
    const double tubeHeight = 190.0;
    const double wallThickness = 2.0;
    const double liquidPadding = 0.0; 
    const double bottomRadius = 35.0;
    const Color glassBorderColor = Color(0xFFD0D0E0); // Light Grey/White-ish

    // Rotation for pouring animation (tilt more when pouring, similar to reference image)
    final double rotation = isAnimatingSource ? 0.8 : 0.0;

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
          width: tubeWidth,
          height: tubeHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // 1. The Glass Body (Background & Border)
              Container(
                width: tubeWidth,
                height: tubeHeight - 17, // Subtract rim height
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04), // Dark interior
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(bottomRadius),
                    bottomRight: Radius.circular(bottomRadius),
                  ),
                  border: Border.all(
                    color: glassBorderColor,
                    width: wallThickness,
                  ),
                ),
              ),

              // 2. The Liquid Column
              Positioned(
                bottom: wallThickness, // Sit above the bottom border
                left: wallThickness + liquidPadding, // Sit inside left border
                right: wallThickness + liquidPadding, // Sit inside right border
                top: 25, // Push down below rim
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildLiquidStack(
                    bottomRadius - wallThickness - liquidPadding,
                  ),
                ),
              ),

              // 3. Glossy Reflections (Vector Style)
              // Left Highlight
              Positioned(
                left: 10,
                top: 25,
                bottom: 25,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Right Highlight (Small)
              Positioned(
                right: 10,
                top: 25,
                height: 30,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 4. The Top Rim (Lip)
              Positioned(
                top: 0,
                child: Container(
                  width: tubeWidth + 8, // Slightly wider than body
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: glassBorderColor,
                      width: wallThickness,
                    ),
                  ),
                  // The "Highlight" on the rim
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 15,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Selection Arrow
              if (isSelected && !isAnimatingSource)
                const Positioned(
                  top: -40,
                  child: Icon(Icons.arrow_downward,
                      color: Colors.yellowAccent, size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLiquidStack(double internalRadius) {
    int totalSlots = kTubeCapacity;
    int filledSlots = data.colors.length;
    int emptySlots = totalSlots - filledSlots;

    List<Widget> widgets = [];

    // 1. Add Empty Slots (Transparent)
    for (int i = 0; i < emptySlots; i++) {
      widgets.add(Expanded(child: Container(color: Colors.transparent)));
    }

    // 2. Add Colored Slots (Reversed loop because column is Top-Down)
    // data.colors[0] is Bottom. data.colors[last] is Top.
    for (int i = filledSlots - 1; i >= 0; i--) {
      String colorKey = data.colors[i];
      bool isBottomLiquid = (i == 0); 

      widgets.add(
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 0), // Flat stacking
            decoration: BoxDecoration(
              color: kColors[colorKey] ?? Colors.red,
              // Only round the bottom of the very last liquid
              borderRadius: isBottomLiquid
                  ? BorderRadius.vertical(bottom: Radius.circular(internalRadius))
                  : BorderRadius.zero,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}