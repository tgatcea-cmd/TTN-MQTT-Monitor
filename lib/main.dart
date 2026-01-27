import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/screens/dashboard_screen.dart'; 
import 'ui/widgets/dialogs/database_config_dialog.dart';
import 'ui/theme.dart';
import 'services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final dbConfig = await storage.getDatabaseConfig();

  bool isConfigured = false;

  if (dbConfig['url'] != null &&
      dbConfig['key'] != null &&
      dbConfig['url']!.isNotEmpty &&
      dbConfig['key']!.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: dbConfig['url']!,
        anonKey: dbConfig['key']!,
      );
      isConfigured = true;
    } catch (e) {
      debugPrint("Error inicializando Supabase con credenciales guardadas: $e");
    }
  }

  runApp(MainApp(isConfigured: isConfigured));
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
  final bool isConfigured;

  const MainApp({super.key, required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe-Art Monitor',
      scrollBehavior: AppScrollBehavior(),
      theme: AppTheme.theme,

      home: isConfigured ? const DashboardScreen() : const SetupScreen(),
    );
  }
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
            SizedBox(height: 20),
            Text(
              'Configuration Required',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Please configure the database connection.'),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.build),
              label: Text('Configure Now'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => DatabaseConfigDialog(
                    onSaved: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Configuration saved. Please restart the app.',
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
