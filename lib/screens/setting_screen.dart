import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _soundVolume = 1.0;
  double _musicVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _musicEnabled = prefs.getBool('musicEnabled') ?? true;
      _soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      _musicVolume = prefs.getDouble('musicVolume') ?? 1.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('soundEnabled', _soundEnabled);
    prefs.setBool('musicEnabled', _musicEnabled);
    prefs.setDouble('soundVolume', _soundVolume);
    prefs.setDouble('musicVolume', _musicVolume);
  }

  void _resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All progress and settings reset!')),
    );
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Audio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Sound Effects'),
                    value: _soundEnabled,
                    onChanged: (val) {
                      setState(() => _soundEnabled = val);
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Music'),
                    value: _musicEnabled,
                    onChanged: (val) {
                      setState(() => _musicEnabled = val);
                      _saveSettings();
                    },
                  ),
                  ListTile(
                    title: const Text('Sound Volume'),
                    subtitle: Slider(
                      value: _soundVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (val) {
                        setState(() => _soundVolume = val);
                        _saveSettings();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Music Volume'),
                    subtitle: Slider(
                      value: _musicVolume,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (val) {
                        setState(() => _musicVolume = val);
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Reset Progress
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Reset Progress'),
              onTap: _resetProgress,
            ),
          ),
        ],
      ),
    );
  }
}
