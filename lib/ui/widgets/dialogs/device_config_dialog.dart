import 'package:flutter/material.dart';
import '../../../data/models.dart';

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
    _deviceEuiController = TextEditingController(
      text: widget.device?.deviceEui ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.device?.accessKey ?? '',
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Colors.red,
        ),
      );
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
    return AlertDialog(
      title: Text(widget.device == null ? 'Add New Device' : 'Edit Device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g., Gallery Monitor 1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _appIdController,
              decoration: const InputDecoration(
                labelText: 'TTN App ID',
                hintText: 'e.g., app@ttn',
                border: OutlineInputBorder(),
              ),
              readOnly: widget.device != null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brokerController,
              decoration: const InputDecoration(
                labelText: 'MQTT Broker',
                hintText: 'e.g., eu1.cloud.thethings.network',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _deviceType,
              decoration: const InputDecoration(
                labelText: 'Device Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'TTN',
                  child: Text('TTN / Standard LoRaWAN'),
                ),
                DropdownMenuItem(
                  value: 'Dragino',
                  child: Text('Dragino LPS8v2'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _deviceType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _batteryMode, 
              decoration: const InputDecoration(
                labelText: 'Battery Display Mode',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.battery_std),
              ),
              items: const [
                DropdownMenuItem(value: 'voltage', child: Text('Voltage (V)')),
                DropdownMenuItem(
                  value: 'percentage',
                  child: Text('Percentage (%)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _batteryMode = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceEuiController,
              decoration: const InputDecoration(
                labelText: 'Device EUI',
                hintText: 'Format: eui-xxxxxxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'NNSXS...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Can Control (Send Downlink Commands)'),
              value: _canControl,
              onChanged: (value) {
                setState(() {
                  _canControl = value ?? false;
                });
              },
            ),

            if (_canControl) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Alarm Stop Command",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _controlPortController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _controlPayloadController,
                            decoration: const InputDecoration(
                              labelText: 'Hex Payload (e.g. A0)',
                              hintText: '01',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),  
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(widget.device == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}