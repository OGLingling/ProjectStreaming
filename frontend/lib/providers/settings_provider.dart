import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _language = 'Español';
  bool _showSubtitles = true;
  Color _subtitleColor = Colors.white;

  static const String _keyLanguage = 'pref_language';
  static const String _keyShowSubtitles = 'pref_show_subtitles';
  static const String _keySubtitleColor = 'pref_subtitle_color';

  String get language => _language;
  bool get showSubtitles => _showSubtitles;
  Color get subtitleColor => _subtitleColor;

  // Propiedad derivada para el texto de ejemplo
  String get sampleText {
    if (_language == 'English') return "This is a sample text.";
    if (_language == 'Português') return "Este é um texto de exemplo.";
    return "Este es un texto de ejemplo."; // Español por defecto
  }

  // Helper para enviar a la DB (formato '#FFFFFF')
  String get subtitleColorHex {
    return '#${_subtitleColor.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(_keyLanguage)) {
      _language = prefs.getString(_keyLanguage)!;
    }

    if (prefs.containsKey(_keyShowSubtitles)) {
      _showSubtitles = prefs.getBool(_keyShowSubtitles)!;
    }

    if (prefs.containsKey(_keySubtitleColor)) {
      final colorValue = prefs.getInt(_keySubtitleColor);
      if (colorValue != null) {
        _subtitleColor = Color(colorValue);
      }
    }
    notifyListeners();
  }

  Future<void> updateSettings({
    String? newLanguage,
    bool? newShowSubtitles,
    Color? newSubtitleColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (newLanguage != null) {
      _language = newLanguage;
      await prefs.setString(_keyLanguage, newLanguage);
    }
    if (newShowSubtitles != null) {
      _showSubtitles = newShowSubtitles;
      await prefs.setBool(_keyShowSubtitles, newShowSubtitles);
    }
    if (newSubtitleColor != null) {
      _subtitleColor = newSubtitleColor;
      await prefs.setInt(_keySubtitleColor, newSubtitleColor.toARGB32());
    }

    notifyListeners();
  }
}
