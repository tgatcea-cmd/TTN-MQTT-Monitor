import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services.dart';
import 'services/iot_brain.dart';
import 'design/cyber_theme.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final dbConfig = await storage.getDatabaseConfig();

  if (dbConfig['url'] != null &&
      dbConfig['key'] != null &&
      dbConfig['url']!.isNotEmpty &&
      dbConfig['key']!.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: dbConfig['url']!,
        anonKey: dbConfig['key']!,
      );
    } catch (e) {
      debugPrint("Supabase Init Error: $e");
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IoTBrain()),
      ],
      child: const MainApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe-Art Monitor',
      scrollBehavior: AppScrollBehavior(),
      theme: CyberTheme.theme,
      home: const SafeArtDashboard(),
    );
  }
}