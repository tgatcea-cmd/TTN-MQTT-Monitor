// ui/widgets/dialogs/database_config_dialog.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../boot_service.dart';
import '../../theme.dart';

class DatabaseConfigDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const DatabaseConfigDialog({super.key, required this.onSaved});

  @override
  State<DatabaseConfigDialog> createState() => _DatabaseConfigDialogState();
}

class _DatabaseConfigDialogState extends State<DatabaseConfigDialog> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _storage = BootDatabaseStorageService();
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
    setState(() => _isLoading = true);
    await _storage.saveDatabaseConfig(_urlController.text.trim(), _keyController.text.trim());
    setState(() => _isLoading = false);
    if (mounted) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.database, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Text("Database Config", style: AppTheme.theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Configure external Supabase connection for persistent storage.",
                style: AppTheme.theme.textTheme.bodyMedium?.copyWith(color: AppTheme.secondary),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase URL',
                  hintText: 'https://xyz.supabase.co',
                  prefixIcon: Icon(LucideIcons.link, size: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Anon Key',
                  hintText: 'Public API Key',
                  prefixIcon: Icon(LucideIcons.key, size: 16),
                ),
              ),
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Connection'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}