import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/content_provider.dart';
import 'providers/electrum_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/content_service.dart';
import 'services/electrum_service.dart';
import 'screens/content_list_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final settingsProvider = SettingsProvider(prefs);
  final themeProvider = ThemeProvider(prefs);
  final electrumProvider = ElectrumProvider();
  
  // Initialize providers
  electrumProvider.initialize(settingsProvider);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => electrumProvider),
        ChangeNotifierProvider(create: (_) => settingsProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'W3CM',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showFilterDialog(BuildContext context, ContentProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Standard:'),
            const SizedBox(height: 8),
            DropdownButton<String?>(
              value: provider.selectedStandard,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Standards'),
                ),
                ...provider.availableStandards.map(
                  (standard) => DropdownMenuItem<String?>(
                    value: standard,
                    child: Text(standard),
                  ),
                ),
              ],
              onChanged: (value) {
                provider.setSelectedStandard(value);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Show Registered Only'),
                const Spacer(),
                Switch(
                  value: provider.showRegisteredOnly,
                  onChanged: (value) {
                    provider.setShowRegisteredOnly(value);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, contentProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const AppLogo(),
                const SizedBox(width: 8),
                const Text('W3CM'),
              ],
            ),
            actions: [
              // Create Content button
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => contentProvider.createContent(context),
                tooltip: 'Create Content',
              ),
              // Import Content button
              IconButton(
                icon: const Icon(Icons.file_upload),
                onPressed: () => contentProvider.importContent(),
                tooltip: 'Import Content',
              ),
              // Refresh button
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => contentProvider.refresh(),
                tooltip: 'Refresh',
              ),
              // Settings button
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                tooltip: 'Settings',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name, hash, or standard...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: contentProvider.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    contentProvider.clearSearch();
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        ),
                        onChanged: contentProvider.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: contentProvider.selectedStandard != null
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filter by Standard',
                        onPressed: () => _showFilterDialog(context, contentProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: const ContentListScreen(),
        );
      },
    );
  }
}
