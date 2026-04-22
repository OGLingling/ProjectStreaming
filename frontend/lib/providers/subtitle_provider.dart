import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubtitleProvider extends ChangeNotifier {
  bool _showSubtitles = true;
  Color _subtitleColor = Colors.white;
  
  // Claves para SharedPreferences
  static const String _keyShowSubtitles = 'pref_show_subtitles';
  static const String _keySubtitleColor = 'pref_subtitle_color';

  bool get showSubtitles => _showSubtitles;
  Color get subtitleColor => _subtitleColor;

  SubtitleProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cargar visibilidad
    if (prefs.containsKey(_keyShowSubtitles)) {
      _showSubtitles = prefs.getBool(_keyShowSubtitles)!;
    }
    
    // Cargar color (se guarda como entero)
    if (prefs.containsKey(_keySubtitleColor)) {
      final colorValue = prefs.getInt(_keySubtitleColor);
      if (colorValue != null) {
        _subtitleColor = Color(colorValue);
      }
    }
    notifyListeners();
  }

  Future<void> toggleSubtitles(bool value) async {
    _showSubtitles = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowSubtitles, value);
  }

  Future<void> updateColor(Color color) async {
    _subtitleColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySubtitleColor, color.toARGB32());
  }
}
