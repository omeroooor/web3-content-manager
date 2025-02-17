import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/collection_provider.dart';
import 'services/content_service.dart';
import 'services/collection_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(
          create: (_) => ContentService(),
        ),
        Provider(
          create: (_) => CollectionService(),
        ),
        ChangeNotifierProvider(
          create: (context) => ContentProvider(
            context.read<ContentService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CollectionProvider(
            context.read<CollectionService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Portable Content Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
