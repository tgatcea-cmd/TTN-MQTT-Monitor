import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';

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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.share2, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Export Configuration",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.device.name,
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Create an encrypted backup of this device configuration to import into another system.",
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 24),
          
          // Password Field
          TextField(
            controller: _passwordController,
            obscureText: _obsecureText,
            decoration: InputDecoration(
              labelText: 'Encryption Password',
              hintText: 'Required to decrypt later',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.blue),
              ),
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obsecureText ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 18,
                ),
                onPressed: () => setState(() => _obsecureText = !_obsecureText),
              ),
              isDense: true,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Options
          InkWell(
            onTap: () => setState(() => _includeSecrets = !_includeSecrets),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _includeSecrets,
                    onChanged: (v) => setState(() => _includeSecrets = v!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Include API Keys & Secrets",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
             if (_passwordController.text.isEmpty) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Password is required for export")),
               );
               return;
             }
             widget.onExport(_passwordController.text, _includeSecrets);
             Navigator.pop(context);
          },
          icon: const Icon(LucideIcons.download, size: 16),
          label: const Text('Export JSON'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF18181B),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}