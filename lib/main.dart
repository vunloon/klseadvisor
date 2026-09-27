import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/watchlist_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KlseAdvisorApp());
}

class KlseAdvisorApp extends StatelessWidget {
  const KlseAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme = ColorScheme.fromSeed(
        seedColor: seed, brightness: Brightness.dark);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (ctx) => WatchlistProvider(ctx.read<SettingsProvider>()),
        ),
      ],
      child: MaterialApp(
        title: 'KLSE Advisor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: scheme,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: scheme.surface,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          cardTheme: CardTheme(
            elevation: 0,
            color: scheme.surfaceContainerHighest.withOpacity(0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: darkScheme.surface,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 0,
            color: darkScheme.surfaceContainerHighest.withOpacity(0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
