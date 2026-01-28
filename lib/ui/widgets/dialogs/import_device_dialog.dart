// ui/widgets/dialogs/import_device_dialog.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme.dart';

class ImportDeviceDialog extends StatefulWidget {
  final Function(List<PlatformFile> files, String password) onImport;

  const ImportDeviceDialog({super.key, required this.onImport});

  @override
  State<ImportDeviceDialog> createState() => _ImportDeviceDialogState();
}

class _ImportDeviceDialogState extends State<ImportDeviceDialog> {
  final _passwordController = TextEditingController();
  final List<PlatformFile> _selectedFiles = [];
  bool _obsecureText = true;

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['sam'],
      );
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (!_selectedFiles.any((f) => f.name == file.name && f.size == file.size)) {
              _selectedFiles.add(file);
            }
          }
        });
      }
    } catch (e) {
      // Error handling
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
                  const Icon(LucideIcons.import, color: AppTheme.primary),
                  const SizedBox(width: 16),
                  Text("Import Backup", style: AppTheme.theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 24),

              // Drop Zone Visual
              InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.uploadCloud, size: 32, color: AppTheme.tertiary),
                      const SizedBox(height: 12),
                      Text("Select .sam files", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      const SizedBox(height: 4),
                      Text("or click to browse", style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                    ],
                  ),
                ),
              ),

              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _selectedFiles.map((file) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.fileJson, size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(file.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            InkWell(
                              onTap: () => setState(() => _selectedFiles.remove(file)),
                              child: const Icon(LucideIcons.x, size: 16, color: AppTheme.tertiary),
                            )
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: _obsecureText,
                decoration: InputDecoration(
                  labelText: 'Decryption Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obsecureText ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
                    onPressed: () => setState(() => _obsecureText = !_obsecureText),
                  ),
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
                    onPressed: _selectedFiles.isEmpty ? null : () {
                      widget.onImport(_selectedFiles, _passwordController.text);
                      Navigator.pop(context);
                    },
                    child: Text('Import (${_selectedFiles.length})'),
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