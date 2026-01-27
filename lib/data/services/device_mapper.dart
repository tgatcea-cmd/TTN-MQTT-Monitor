import 'dart:convert';
import '../models.dart';

class DeviceMapper {
  /// Converts a Device to the specific SAM JSON Schema
  static Map<String, dynamic> toExportJson(Device device, {bool includeSecrets = false}) {
    return {
      "meta": {
        "version": "1.0",
        "type": "single_device_export",
        "exported_at": DateTime.now().toIso8601String(),
      },
      "device": {
        "id": device.id,
        "name": device.name,
        "app_id": device.appId,
        "broker": device.broker,
        "device_eui": device.deviceEui,
        "device_type": device.deviceType,
        "battery_mode": device.batteryMode,
        "can_control": device.canControl,
        "created_at": device.createdAt.toIso8601String(),
        
        // Nested Configuration
        "control_config": {
          "port": device.controlPort,
          "payload_hex": device.controlPayload,
        },

        // Sensitive Data Logic
        "access_key": includeSecrets ? device.accessKey : null,
      }
    };
  }

  /// Parses the SAM JSON Schema back to a Device object
  static Device fromExportJson(String jsonString) {
    final Map<String, dynamic> root = jsonDecode(jsonString);
    
    // Basic validation
    if (!root.containsKey('device')) throw FormatException("Missing 'device' root key");
    final d = root['device'];
    final config = d['control_config'] ?? {};

    return Device(
      id: d['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback if ID missing
      name: d['name'],
      appId: d['app_id'],
      broker: d['broker'],
      deviceEui: d['device_eui'],
      accessKey: d['access_key'], // Nullable in your model
      canControl: d['can_control'] ?? false,
      deviceType: d['device_type'] ?? 'TTN',
      batteryMode: d['battery_mode'] ?? 'voltage',
      
      // Flattening the nested config back to the model
      controlPort: config['port'] ?? 1,
      controlPayload: config['payload_hex'] ?? '01',
      
      createdAt: d['created_at'] != null 
          ? DateTime.parse(d['created_at']) 
          : DateTime.now(),
    );
  }
}