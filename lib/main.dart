import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/bitcoin_provider.dart';
import 'providers/settings_provider.dart';
import 'services/content_service.dart';
import 'services/bitcoin_service.dart';
import 'screens/content_list_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_logo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (_) => ContentService(),
        ),
        Provider(
          create: (_) => BitcoinService(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProxyProvider<ContentService, ContentProvider>(
          create: (context) => ContentProvider(
            context.read<ContentService>(),
          ),
          update: (context, contentService, previous) =>
              previous ?? ContentProvider(contentService),
        ),
        ChangeNotifierProxyProvider2<BitcoinService, SettingsProvider, BitcoinProvider>(
          create: (context) => BitcoinProvider(
            context.read<BitcoinService>(),
          ),
          update: (context, bitcoinService, settings, previous) {
            if (settings.nodeSettings != null) {
              final nodeSettings = settings.nodeSettings!;
              bitcoinService.initialize(
                host: nodeSettings.host,
                port: nodeSettings.port,
                username: nodeSettings.username,
                password: nodeSettings.password,
              );
            }
            return previous ?? BitcoinProvider(bitcoinService);
          },
        ),
      ],
      child: MaterialApp(
        title: 'Web3 Content Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showFilterDialog(BuildContext context, ContentProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Standard'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile<String?>(
                title: const Text('All Standards'),
                value: null,
                groupValue: provider.selectedStandard,
                onChanged: (value) {
                  provider.setSelectedStandard(value);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...provider.availableStandards.map(
                (standard) => RadioListTile<String>(
                  title: Text(standard),
                  value: standard,
                  groupValue: provider.selectedStandard,
                  onChanged: (value) {
                    if (value != null) {
                      provider.setSelectedStandard(value);
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            title: const AppLogo(),
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
