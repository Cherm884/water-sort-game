// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:water_sort/screens/home_screen.dart';


void main() {
  runApp(const WaterSortApp());
}

class WaterSortApp extends StatelessWidget {
  const WaterSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChromaFlow',
      theme: ThemeData(
        fontFamily: 'Outfit',
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

