// ui/widgets/dialogs/device_config_dialog.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models.dart';
import '../../theme.dart';

class DeviceConfigDialog extends StatefulWidget {
  final Device? device;
  final Function(Device) onSave;

  const DeviceConfigDialog({super.key, this.device, required this.onSave});

  @override
  State<DeviceConfigDialog> createState() => _DeviceConfigDialogState();
}

class _DeviceConfigDialogState extends State<DeviceConfigDialog> {
  late TextEditingController _nameController;
  late TextEditingController _appIdController;
  late TextEditingController _brokerController;
  late TextEditingController _deviceEuiController;
  late TextEditingController _apiKeyController;
  late bool _canControl;
  late String _deviceType;
  late String _batteryMode;
  late TextEditingController _controlPortController;
  late TextEditingController _controlPayloadController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.name ?? '');
    _appIdController = TextEditingController(text: widget.device?.appId ?? '');
    _brokerController = TextEditingController(
      text: widget.device?.broker ?? 'eu1.cloud.thethings.network',
    );
    _deviceEuiController = TextEditingController(text: widget.device?.deviceEui ?? '');
    _apiKeyController = TextEditingController(text: widget.device?.accessKey ?? '');
    _canControl = widget.device?.canControl ?? false;
    _deviceType = widget.device?.deviceType ?? 'TTN';
    _batteryMode = widget.device?.batteryMode ?? 'voltage';
    _controlPortController = TextEditingController(
      text: widget.device?.controlPort.toString() ?? '1',
    );
    _controlPayloadController = TextEditingController(
      text: widget.device?.controlPayload ?? '01',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appIdController.dispose();
    _brokerController.dispose();
    _deviceEuiController.dispose();
    _apiKeyController.dispose();
    _controlPortController.dispose();
    _controlPayloadController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.isEmpty ||
        _appIdController.text.isEmpty ||
        _deviceEuiController.text.isEmpty) {
      // Use a cleaner Snackbar or internal error state in a real app
      return;
    }

    final device = Device(
      id: widget.device?.id ?? _appIdController.text,
      name: _nameController.text,
      appId: _appIdController.text,
      broker: _brokerController.text,
      deviceEui: _deviceEuiController.text,
      accessKey: _apiKeyController.text,
      canControl: _canControl,
      deviceType: _deviceType,
      batteryMode: _batteryMode,
      controlPort: int.tryParse(_controlPortController.text) ?? 1,
      controlPayload: _controlPayloadController.text.trim(),
      createdAt: widget.device?.createdAt ?? DateTime.now(),
    );

    widget.onSave(device);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // We use a Dialog with specific constraints to prevent it from filling the screen
    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.settings, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.device == null ? 'New Device' : 'Configuration',
                    style: AppTheme.theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Identification"),
                    const SizedBox(height: 16),
                    _buildTextField("Device Name", _nameController, hint: "Gallery Monitor 1"),
                    const SizedBox(height: 16),
                    _buildTextField("Device EUI", _deviceEuiController, hint: "eui-xxxxxxxx"),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader("Connection"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("TTN App ID", _appIdController, readOnly: widget.device != null)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _deviceType,
                            decoration: const InputDecoration(labelText: 'Type'),
                            items: const [
                              DropdownMenuItem(value: 'TTN', child: Text('Standard')),
                              DropdownMenuItem(value: 'Dragino', child: Text('Dragino')),
                            ],
                            onChanged: (v) => setState(() => _deviceType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField("MQTT Broker", _brokerController),
                    const SizedBox(height: 16),
                    _buildTextField("API Key", _apiKeyController, obscureText: true),

                    const SizedBox(height: 32),
                    _buildSectionHeader("Capabilities"),
                    const SizedBox(height: 16),
                    
                    // Custom Checkbox Tile
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CheckboxListTile(
                        title: const Text("Remote Control Enabled", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text("Allows sending downlink commands", style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                        value: _canControl,
                        activeColor: AppTheme.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        onChanged: (v) => setState(() => _canControl = v ?? false),
                      ),
                    ),

                    if (_canControl) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: _buildTextField("Port", _controlPortController),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField("Payload (Hex)", _controlPayloadController),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(widget.device == null ? 'Create Device' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTheme.theme.textTheme.labelSmall,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false, bool readOnly = false, String? hint}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      style: AppTheme.theme.textTheme.bodyMedium?.copyWith(color: AppTheme.primary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }
}