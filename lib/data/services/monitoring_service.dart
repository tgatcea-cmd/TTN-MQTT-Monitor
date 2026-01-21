import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../models.dart';
import 'mqtt_wrapper.dart';
import 'database_service.dart';

class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final DatabaseService _db = DatabaseService();
  final Map<String, MqttWrapper> _clients = {};
  final Map<String, StreamController<SensorData>> _deviceStreams = {};

  final ValueNotifier<bool> isMonitoring = ValueNotifier(false);
  final ValueNotifier<String> statusLog = ValueNotifier("System Ready");

  final Map<String, SensorData> _lastReadings = {};
  SensorData? getLastReading(String deviceId) => _lastReadings[deviceId];

  Stream<SensorData> getStream(String deviceId) {
    if (!_deviceStreams.containsKey(deviceId)) {
      _deviceStreams[deviceId] = StreamController<SensorData>.broadcast();
    }
    return _deviceStreams[deviceId]!.stream;
  }

  Future<void> startMonitoring(List<Device> devices) async {
    int connected = 0;
    statusLog.value = "Initializing connections...";

    for (var device in devices) {
      if (device.accessKey == null || device.accessKey!.isEmpty) continue;
      if (_clients.containsKey(device.appId)) continue;

      final isTTN =
          device.broker.contains('thethings') || device.broker.contains('ttn');

      final client = MqttWrapper(
        appId: device.appId,
        accessKey: device.accessKey!,
        broker: device.broker,
        port: isTTN ? 8883 : 1883,
        secure: isTTN,
      );

      client.messages.listen((msg) => _handleRawMessage(msg, device));

      try {
        await client.connect();
        if (client.client.connectionStatus?.state ==
            MqttConnectionState.connected) {
          _clients[device.appId] = client;
          connected++;
        } else {
          debugPrint("Connection failed for ${device.name}");
        }
      } catch (e) {
        debugPrint("Connection failed for ${device.name}: $e");
      }
    }

    if (connected > 0) {
      isMonitoring.value = true;
      statusLog.value = "Monitoring $connected networks active";
    } else {
      isMonitoring.value = false;
      statusLog.value = "Connection Failed: Check API Keys";
    }
  }

  void stopMonitoring() {
    for (var c in _clients.values) {
      c.disconnect();
    }
    _clients.clear();
    isMonitoring.value = false;
    statusLog.value = "Monitoring Stopped";
  }

  Future<void> sendStopCommand(Device device) async {
    final client = _clients[device.appId];
    if (client == null) {
      debugPrint('Error: No conectado');
      return;
    }

    int port = device.controlPort;
    List<int> bytes = [];
    String hex = device.controlPayload.replaceAll('0x', '').replaceAll(' ', '');
    try {
      for (int i = 0; i < hex.length; i += 2) {
        String byteStr = hex.substring(i, i + 2);
        bytes.add(int.parse(byteStr, radix: 16));
      }
    } catch (e) {
      debugPrint("Error parsing hex payload: $hex");
      bytes = [0x01]; // Fallback
    }



    String base64Payload = base64Encode(bytes);
    Map<String, dynamic> jsonMap = {
      "downlinks": [
        {"f_port": port, "frm_payload": base64Payload, "priority": "NORMAL"},
      ],
    };

    final payload = jsonEncode(jsonMap);

    final topic = 'v3/${device.appId}/devices/${device.deviceEui}/down/push';

    debugPrint("🚀 Sending Downlink to $topic");
    debugPrint("📦 Payload: $payload");

    client.publish(topic, payload);
    statusLog.value = "Command sent to ${device.name}";
  }

  Future<void> _handleRawMessage(String msg, Device config) async {
    try {
      debugPrint(
        "📥 [Monitor] Processing for ${config.name} (${config.deviceEui})",
      );

      if (!msg.contains('{')) return;
      final jsonStr = msg.substring(msg.indexOf('{'), msg.lastIndexOf('}') + 1);
      final Map<String, dynamic> payload = jsonDecode(jsonStr);

      final String packetDevId = payload['end_device_ids']?['device_id'] ?? '';

      debugPrint(
        "🆔 [Monitor] Packet ID: '$packetDevId' vs Config ID: '${config.deviceEui}'",
      );

      SensorData data;
      if (payload.containsKey('uplink_message')) {
        var decoded = payload['uplink_message']['decoded_payload'] ?? {};
        data = SensorData.fromPayload(decoded, config.deviceType);
      } else {
        
        debugPrint("⚠️ [Monitor] Message was not an uplink.");
        
        return;
      }

      if (packetDevId.toLowerCase().contains(config.deviceEui.toLowerCase()) ||
          config.deviceEui.isEmpty) {
        
        debugPrint("✅ [Monitor] MATCH! Updating Stream & DB...");
        
        _lastReadings[config.id] = data;

        if (_deviceStreams.containsKey(config.id)) {
          _deviceStreams[config.id]!.add(data);
        }

        await _db.insertSensorReading(config.deviceEui, config.name, data);

        statusLog.value =
            "Rx: ${config.name} @ ${DateTime.now().hour}:${DateTime.now().minute}";
      }
    } catch (e) {
      debugPrint("Parse Error: $e");
    }
  }
}
