import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/bitcoin_provider.dart';
import 'providers/settings_provider.dart';
import 'services/content_service.dart';
import 'services/bitcoin_service.dart';
import 'screens/content_list_screen.dart';
import 'screens/settings_screen.dart';

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
        title: 'Portable Content Manager',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portable Content Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: const ContentListScreen(),
    );
  }
}
