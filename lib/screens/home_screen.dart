import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';
import 'discovery_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    final wp = context.read<WatchlistProvider>();
    Future.microtask(() async {
      await sp.load();
      await wp.load();
      wp.restartAutoRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    const screens = [
      WatchlistScreen(),
      DiscoveryScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (_tab == 0) {
            await context.read<WatchlistProvider>().refresh();
          }
        },
        child: screens[_tab],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
