import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Impostazioni dell'interfaccia, salvate in modo persistente nel database del server.
class SettingsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  ThemeMode _themeMode = ThemeMode.light;
  bool _showPhotoNames = true;
  bool _showSearchBar = true;

  ThemeMode get themeMode => _themeMode;
  bool get showPhotoNames => _showPhotoNames;
  bool get showSearchBar => _showSearchBar;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _apiService.getAllSettings();
      _themeMode = settings['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _showPhotoNames = settings['show_photo_names'] != 'false';
      _showSearchBar = settings['show_search_bar'] != 'false';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _save('theme', _themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> setShowPhotoNames(bool value) async {
    _showPhotoNames = value;
    notifyListeners();
    await _save('show_photo_names', '$value');
  }

  Future<void> setShowSearchBar(bool value) async {
    _showSearchBar = value;
    notifyListeners();
    await _save('show_search_bar', '$value');
  }

  Future<void> _save(String key, String value) async {
    try {
      await _apiService.updateSetting(key, value);
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }
}
