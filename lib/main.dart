// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_sort/screens/home_screen.dart';


void main() {
  runApp(const WaterSortApp());
}

class WaterSortApp extends StatefulWidget {
  const WaterSortApp({super.key});

  @override
  State<WaterSortApp> createState() => _WaterSortAppState();
}

class _WaterSortAppState extends State<WaterSortApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('darkMode') ?? true;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', mode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChromaFlow',
      theme: ThemeData(
        fontFamily: 'Outfit',
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Outfit',
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: HomeScreen(
        onThemeModeChanged: updateThemeMode,
      ),
    );
  }
}

