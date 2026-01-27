import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';

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
  bool _isHovering = false;

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['sam', 'json', 'enc'],
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            final isDuplicate = _selectedFiles.any(
              (f) => f.name == file.name && f.size == file.size,
            );
            if (!isDuplicate) {
              _selectedFiles.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking files: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.bitLength - 1) ~/ 10;

    if (i < 0) i = 0;
    if (i >= suffixes.length) i = suffixes.length - 1;

    double size = bytes / (1 << (i * 10));
    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.import,
              color: Colors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Import Configuration",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Restore devices from local backup",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _pickFiles,
              onHover: (v) => setState(() => _isHovering = v),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _isHovering ? Colors.grey[50] : Colors.white,
                  border: Border.all(
                    color: _isHovering ? Colors.purple : Colors.grey[300]!,
                    width: _isHovering ? 1.5 : 1,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.uploadCloud,
                      size: 32,
                      color: _isHovering ? Colors.purple : Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Click to select files",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isHovering ? Colors.purple : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Supports .sam, .json, .enc",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_selectedFiles.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SELECTED FILES (${_selectedFiles.length})",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey[600],
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedFiles.clear()),
                    child: Text(
                      "Clear All",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                child: SingleChildScrollView(
                  child: Column(
                    children: _selectedFiles.asMap().entries.map((entry) {
                      final file = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.fileJson,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatBytes(file.size, 1),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeFile(entry.key),
                              icon: const Icon(
                                LucideIcons.x,
                                size: 14,
                                color: Colors.grey,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _passwordController,
              obscureText: _obsecureText,
              decoration: InputDecoration(
                labelText: 'Decryption Password',
                hintText: 'Enter password to unlock files',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(LucideIcons.key, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obsecureText ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obsecureText = !_obsecureText),
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedFiles.isEmpty || _passwordController.text.isEmpty
              ? null
              : () {
                  widget.onImport(_selectedFiles, _passwordController.text);
                  Navigator.pop(context);
                },
          icon: const Icon(LucideIcons.downloadCloud, size: 16),
          label: const Text('Import Devices'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18181B),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: Colors.grey[200],
            disabledForegroundColor: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
