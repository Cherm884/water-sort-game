// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_sort/screens/setting_screen.dart';
import 'package:water_sort/src/constants.dart';
import 'package:water_sort/screens/game_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const HomeScreen({super.key, this.onThemeModeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _currentDifficulty = Difficulty.easy;
  int _maxLevels = 1;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDiff = prefs.getString('chromaflow_last_difficulty');

    Difficulty diff = Difficulty.easy;
    if (savedDiff != null) {
      diff = Difficulty.values.firstWhere(
        (e) => e.toString() == savedDiff,
        orElse: () => Difficulty.easy,
      );
    }

    final level = prefs.getInt('chromaflow_progress_$diff') ?? 1;

    setState(() {
      _currentDifficulty = diff;
      _maxLevels = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.indigo],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'CHROMA\nFLOW',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'WATER SORT PUZZLE',
                  style: TextStyle(
                    color: Colors.blue[200],
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                _MainMenuButton(
                  label:
                      'RESUME ${_currentDifficulty.name.toUpperCase().replaceAll('EXTRAHARD', 'EXPERT')}',
                  icon: Icons.play_arrow_rounded,
                  isPrimary: true,
                  subLabel: 'LEVEL $_maxLevels',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          difficulty: _currentDifficulty,
                          levelIndex: _maxLevels - 1,
                        ),
                      ),
                    ).then((_) => _loadProgress());
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MainMenuButton(
                        label: 'LEVELS',
                        icon: Icons.grid_view_rounded,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LevelsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MainMenuButton(
                        label: 'SETTINGS',
                        icon: Icons.settings,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) {
                            return SettingsScreen(
                              onThemeModeChanged: widget.onThemeModeChanged,
                            );
                          }));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainMenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final String? subLabel;

  const _MainMenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (subLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  subLabel!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<Difficulty, int> _progress = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllProgress();
  }

  Future<void> _loadAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    Map<Difficulty, int> temp = {};
    for (var d in Difficulty.values) {
      temp[d] = prefs.getInt('chromaflow_progress_$d') ?? 1;
    }
    setState(() => _progress = temp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1C2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Level',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'EASY'),
            Tab(text: 'MEDIUM'),
            Tab(text: 'HARD'),
            Tab(text: 'EXPERT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: Difficulty.values.map((diff) {
          final maxLevel = _progress[diff] ?? 1;
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: kLevelsPerDifficulty,
            itemBuilder: (ctx, index) {
              final levelNum = index + 1;
              final isLocked = levelNum > maxLevel;
              final isCurrent = levelNum == maxLevel;
              return GestureDetector(
                onTap: isLocked
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameScreen(
                              difficulty: diff,
                              levelIndex: levelNum - 1,
                            ),
                          ),
                        ).then((_) => _loadAllProgress());
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.blueAccent
                        : (isLocked
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isCurrent
                          ? Colors.blue
                          : Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isLocked
                        ? Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.white.withOpacity(0.3),
                          )
                        : Text(
                            '$levelNum',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
