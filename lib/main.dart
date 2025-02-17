import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/content_provider.dart';
import 'providers/bitcoin_provider.dart';
import 'services/content_service.dart';
import 'services/bitcoin_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final contentService = ContentService();
  await contentService.initialize();

  final bitcoinService = BitcoinService();
  await bitcoinService.initialize(
    host: 'localhost',
    port: 19332,
    username: 'user',
    password: 'pass',
  );

  runApp(MyApp(
    contentService: contentService,
    bitcoinService: bitcoinService,
  ));
}

class MyApp extends StatelessWidget {
  final ContentService contentService;
  final BitcoinService bitcoinService;

  const MyApp({
    super.key,
    required this.contentService,
    required this.bitcoinService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => contentService),
        Provider(create: (_) => bitcoinService),
        ChangeNotifierProvider(
          create: (context) => ContentProvider(contentService),
        ),
        ChangeNotifierProvider(
          create: (context) => BitcoinProvider(bitcoinService),
        ),
      ],
      child: MaterialApp(
        title: 'Portable Content Manager',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
