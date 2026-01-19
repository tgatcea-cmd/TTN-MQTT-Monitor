import 'package:flutter/material.dart';
import '../services.dart';

class DatabaseConfigDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const DatabaseConfigDialog({super.key, required this.onSaved});

  @override
  State<DatabaseConfigDialog> createState() => _DatabaseConfigDialogState();
}

class _DatabaseConfigDialogState extends State<DatabaseConfigDialog> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _storage = StorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await _storage.getDatabaseConfig();
    if (mounted) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _keyController.text = config['key'] ?? '';
      });
    }
  }

  Future<void> _save() async {
    if (_urlController.text.isEmpty || _keyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL y Key son obligatorias'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Guardar en almacenamiento seguro
    await _storage.saveDatabaseConfig(
      _urlController.text.trim(), 
      _keyController.text.trim()
    );

    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configuración guardada. Reinicia la app si es necesario.'), backgroundColor: Colors.green),
      );
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: Colors.indigo),
          SizedBox(width: 10),
          Text('Configurar Base de Datos'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Introduce las credenciales de Supabase. Se guardarán de forma encriptada en el dispositivo.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Supabase URL',
              hintText: 'https://xyz.supabase.co',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: 'Supabase Anon Key',
              hintText: 'eyJ...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
            obscureText: true, // Ocultar la clave visualmente
            maxLines: 1,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text('Guardar Conexión'),
        ),
      ],
    );
  }
}