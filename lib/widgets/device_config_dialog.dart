import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceConfigDialog extends StatefulWidget {
  final Device? device; // null for new device, otherwise edit existing
  final Function(Device) onSave;

  const DeviceConfigDialog({
    super.key,
    this.device,
    required this.onSave,
  });

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.name ?? '');
    _appIdController = TextEditingController(text: widget.device?.appId ?? '');
    _brokerController =
        TextEditingController(text: widget.device?.broker ?? 'eu.cloud.thingnetwork.org');
    _deviceEuiController =
        TextEditingController(text: widget.device?.deviceEui ?? '');
    _apiKeyController = TextEditingController(text: widget.device?.accessKey ?? '');
    _canControl = widget.device?.canControl ?? false;
    _deviceType = widget.device?.deviceType ?? 'TTN';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appIdController.dispose();
    _brokerController.dispose();
    _deviceEuiController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.isEmpty ||
        _appIdController.text.isEmpty ||
        _deviceEuiController.text.isEmpty ||
        _apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All fields are required'), backgroundColor: Colors.red),
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
      createdAt: widget.device?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
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
              decoration: InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g., Gallery Monitor 1',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _appIdController,
              decoration: InputDecoration(
                labelText: 'TTN App ID',
                hintText: 'e.g., app@ttn',
                border: OutlineInputBorder(),
              ),
              readOnly: widget.device != null, // Can't change ID on edit
            ),
            SizedBox(height: 12),
            TextField(
              controller: _brokerController,
              decoration: InputDecoration(
                labelText: 'MQTT Broker',
                hintText: 'e.g., eu.cloud.thingnetwork.org',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _deviceType,
              decoration: InputDecoration(
                labelText: 'Device Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'TTN', child: Text('TTN / Standard LoRaWAN')),
                DropdownMenuItem(value: 'Dragino', child: Text('Dragino LPS8v2')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _deviceType = value;
                  });
                }
              },
            ),
            SizedBox(height: 12),
            TextField(
              controller: _deviceEuiController,
              decoration: InputDecoration(
                labelText: 'Device EUI',
                hintText: 'Format: eui-xxxxxxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'NNSXS...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            SizedBox(height: 12),
            CheckboxListTile(
              title: Text('Can Control (Send Downlink Commands)'),
              value: _canControl,
              onChanged: (value) {
                setState(() {
                  _canControl = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(widget.device == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
