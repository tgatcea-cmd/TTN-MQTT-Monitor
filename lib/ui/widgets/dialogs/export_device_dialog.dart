// ui/widgets/dialogs/export_device_dialog.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';
import '../../theme.dart';

class ExportDeviceDialog extends StatefulWidget {
  final Device device;
  final Function(String password, bool includeSecrets) onExport;

  const ExportDeviceDialog({
    super.key,
    required this.device,
    required this.onExport,
  });

  @override
  State<ExportDeviceDialog> createState() => _ExportDeviceDialogState();
}

class _ExportDeviceDialogState extends State<ExportDeviceDialog> {
  final _passwordController = TextEditingController();
  bool _includeSecrets = true;
  bool _obsecureText = true;

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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(LucideIcons.share2, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Export Config", style: AppTheme.theme.textTheme.headlineSmall),
                      Text(widget.device.name, style: AppTheme.theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: AppTheme.secondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                "Create an encrypted backup file (.sam) to transfer this configuration.",
                style: AppTheme.theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: _obsecureText,
                decoration: InputDecoration(
                  labelText: 'Encryption Password',
                  hintText: 'Required to decrypt',
                  suffixIcon: IconButton(
                    icon: Icon(_obsecureText ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
                    onPressed: () => setState(() => _obsecureText = !_obsecureText),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Option Checkbox
              InkWell(
                onTap: () => setState(() => _includeSecrets = !_includeSecrets),
                child: Row(
                  children: [
                    SizedBox(
                      height: 24, width: 24,
                      child: Checkbox(
                        value: _includeSecrets,
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _includeSecrets = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("Include API Keys", style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                       if (_passwordController.text.isEmpty) return;
                       widget.onExport(_passwordController.text, _includeSecrets);
                       Navigator.pop(context);
                    },
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('Generate File'),
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