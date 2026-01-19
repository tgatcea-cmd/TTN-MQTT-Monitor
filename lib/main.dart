import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'config.dart';
import 'dashboard.dart';
import 'services.dart';
import 'widgets/database_config_dialog.dart'; // Asegúrate de importar esto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Intentar cargar configuración guardada
  final storage = StorageService();
  final dbConfig = await storage.getDatabaseConfig();
  
  bool isConfigured = false;

  // 2. Inicializar Supabase si hay datos
  if (dbConfig['url'] != null && dbConfig['key'] != null && 
      dbConfig['url']!.isNotEmpty && dbConfig['key']!.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: dbConfig['url']!,
        anonKey: dbConfig['key']!,
      );
      isConfigured = true;
    } catch (e) {
      debugPrint("Error inicializando Supabase con credenciales guardadas: $e");
      // Si falla, dejaremos que la app inicie en modo "Configuración necesaria"
    }
  }

  runApp(MainApp(isConfigured: isConfigured));
}

// Enable scrolling with mouse drag on desktop
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
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      // Si está configurado, vamos al Dashboard. Si no, a una pantalla de espera/setup
      home: isConfigured ? const MqttDashboard() : const SetupScreen(),
    );
  }
}

// Pantalla simple para cuando no hay configuración
// Simple screen for when configuration is missing
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FIXED: Changed to a valid icon
            Icon(Icons.settings_suggest, size: 64, color: Colors.orange),
            SizedBox(height: 20),
            Text('Configuration Required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                          content: Text('Configuration saved. Please restart the app.'),
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