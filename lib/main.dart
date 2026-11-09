import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/photo_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'Pixora',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const HomeScreen(),
        );
      },
    );
  }
}

/// Blu principale usato per bottoni, selezioni e rifiniture.
const _brandBlue = Color(0xFF1E6FE8);

/// Tema chiaro: sfondo bianco con elementi blu. Tema scuro derivato dallo stesso blu.
ThemeData _buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: _brandBlue, brightness: brightness);

  final scheme = isLight
      ? base.copyWith(
          // Blu per gli elementi interattivi
          primary: _brandBlue,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE6F0FD),
          onPrimaryContainer: const Color(0xFF0B3B8C),
          secondary: _brandBlue,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE6F0FD),
          onSecondaryContainer: const Color(0xFF0B3B8C),
          // Superfici bianche e grigi neutri (senza sfumature colorate)
          surface: Colors.white,
          onSurface: const Color(0xFF1A1F2B),
          onSurfaceVariant: const Color(0xFF5B6474),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF6F8FB),
          surfaceContainer: const Color(0xFFF1F4F8),
          surfaceContainerHigh: const Color(0xFFEDF1F6),
          surfaceContainerHighest: const Color(0xFFE5EAF1),
          outline: const Color(0xFFC3CBD7),
          outlineVariant: const Color(0xFFE3E8EF),
          surfaceTint: Colors.transparent,
        )
      : base;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
