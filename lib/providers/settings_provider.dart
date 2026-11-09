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

  // --- Barre laterali: visibilità e larghezza ---
  static const double leftDefaultWidth = 280;
  static const double leftMinWidth = 220;
  static const double leftMaxWidth = 480;
  static const double rightDefaultWidth = 300;
  static const double rightMinWidth = 280;
  static const double rightMaxWidth = 480;

  bool _leftSidebarVisible = true;
  bool _rightSidebarVisible = true;
  double _leftSidebarWidth = leftDefaultWidth;
  double _rightSidebarWidth = rightDefaultWidth;

  bool get leftSidebarVisible => _leftSidebarVisible;
  bool get rightSidebarVisible => _rightSidebarVisible;
  double get leftSidebarWidth => _leftSidebarWidth;
  double get rightSidebarWidth => _rightSidebarWidth;

  void toggleLeftSidebar() {
    _leftSidebarVisible = !_leftSidebarVisible;
    notifyListeners();
    _save('left_sidebar_visible', '$_leftSidebarVisible');
  }

  void toggleRightSidebar() {
    _rightSidebarVisible = !_rightSidebarVisible;
    notifyListeners();
    _save('right_sidebar_visible', '$_rightSidebarVisible');
  }

  /// Aggiorna la larghezza durante il trascinamento (senza salvare).
  void setLeftSidebarWidth(double width) {
    _leftSidebarWidth = width.clamp(leftMinWidth, leftMaxWidth);
    notifyListeners();
  }

  void setRightSidebarWidth(double width) {
    _rightSidebarWidth = width.clamp(rightMinWidth, rightMaxWidth);
    notifyListeners();
  }

  /// Salva le larghezze nel database (al rilascio del trascinamento).
  void saveSidebarWidths() {
    _save('left_sidebar_width', _leftSidebarWidth.round().toString());
    _save('right_sidebar_width', _rightSidebarWidth.round().toString());
  }

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _apiService.getAllSettings();
      _themeMode = settings['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _showPhotoNames = settings['show_photo_names'] != 'false';
      _showSearchBar = settings['show_search_bar'] != 'false';
      _leftSidebarVisible = settings['left_sidebar_visible'] != 'false';
      _rightSidebarVisible = settings['right_sidebar_visible'] != 'false';
      final left = double.tryParse(settings['left_sidebar_width'] ?? '');
      if (left != null) _leftSidebarWidth = left.clamp(leftMinWidth, leftMaxWidth);
      final right = double.tryParse(settings['right_sidebar_width'] ?? '');
      if (right != null) _rightSidebarWidth = right.clamp(rightMinWidth, rightMaxWidth);
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
