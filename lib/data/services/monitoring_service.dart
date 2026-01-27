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

  final ValueNotifier<Map<String, bool>> alarmStatus = ValueNotifier({});

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
    alarmStatus.value = {};
  }

  Future<void> sendStopCommand(Device device) async {
    final currentAlarms = Map<String, bool>.from(alarmStatus.value);
    if (currentAlarms.containsKey(device.id)) {
      currentAlarms[device.id] = false; // Turn off glow/dot
      alarmStatus.value = currentAlarms;
    }

    final client = _clients[device.appId];
    if (client == null) {
      debugPrint('Error: No conectado');
      return;
    }

    int port = device.controlPort;
    List<int> bytes = [];
    String hex = device.controlPayload.replaceAll('0x', '').replaceAll(' ', '');
    try {
      if (hex.length % 2 != 0) hex = '0$hex';
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
      if (!msg.contains('{')) return;
      final jsonStr = msg.substring(msg.indexOf('{'), msg.lastIndexOf('}') + 1);
      final Map<String, dynamic> payload = jsonDecode(jsonStr);

      final String packetDevId = payload['end_device_ids']?['device_id'] ?? '';

      // Check if the device matches before heavy processing
      if (!packetDevId.toLowerCase().contains(config.deviceEui.toLowerCase()) &&
          config.deviceEui.isNotEmpty) {
        return;
      }

      SensorData data;
      if (payload.containsKey('uplink_message')) {
        final uplink = payload['uplink_message'];
        Map<String, dynamic> decoded = {};

        // 2. If empty, manually decode the frm_payload
        if (decoded.isEmpty && uplink['frm_payload'] != null) {
          debugPrint("🛠 Manually decoding CayenneLPP from frm_payload...");
          Uint8List rawBytes = base64.decode(uplink['frm_payload']);
          decoded = decodeCayenneLPP(rawBytes);
        }

        if (decoded.isEmpty) {
          debugPrint(
            "⚠️ Could not parse payload (both decoded_payload and frm_payload failed).",
          );
          return;
        }

        data = SensorData.fromPayload(decoded, config.deviceType);
      } else {
        return;
      }

      // --- Start Alarm & DB Logic ---
      debugPrint("✅ [Monitor] MATCH! Updating Stream & DB...");

      bool shouldAlarm = false;
      if (_lastReadings.containsKey(config.id)) {
        final lastTime = _lastReadings[config.id]!.timestamp;
        final diff = data.timestamp.difference(lastTime).abs();
        // Alarm Logic: <= 3 mins is a trigger
        shouldAlarm = (diff.inMinutes <= 3);
      }

      final currentAlarms = Map<String, bool>.from(alarmStatus.value);
      if (currentAlarms[config.id] != shouldAlarm) {
        currentAlarms[config.id] = shouldAlarm;
        alarmStatus.value = currentAlarms;
      }

      _lastReadings[config.id] = data;
      _deviceStreams[config.id]?.add(data);
      await _db.insertSensorReading(config.deviceEui, config.name, data);

      statusLog.value =
          "Rx: ${config.name} @ ${DateTime.now().hour}:${DateTime.now().minute}";
    } catch (e) {
      debugPrint("Parse Error: $e");
    }
  }

  Map<String, dynamic> decodeCayenneLPP(Uint8List bytes) {
    Map<String, dynamic> decoded = {};
    int i = 0;

    while (i < bytes.length) {
      int channel = bytes[i++];
      int type = bytes[i++];

      switch (type) {
        case 0x00: // Digital Input (1 byte)
          decoded['digital_in_$channel'] = bytes[i++];
          break;
        case 0x01: // Digital Output (1 byte)
          decoded['digital_out_$channel'] = bytes[i++];
          break;
        case 0x02: // Analog Input (2 bytes, 0.01 signed)
          int val = (ByteData.sublistView(bytes, i, i + 2).getInt16(0));
          decoded['analog_in_$channel'] = val / 100.0;
          i += 2;
          break;
        case 0x67: // Temperature (2 bytes, 0.1°C signed)
          int val = (ByteData.sublistView(bytes, i, i + 2).getInt16(0));
          decoded['temperature_$channel'] = val / 10.0;
          i += 2;
          break;
        case 0x68: // Humidity (1 byte, 0.5% unsigned)
          decoded['humidity_$channel'] = bytes[i++] / 2.0;
          break;
        case 0x71: // Accelerometer (6 bytes, 0.001G signed per axis)
          decoded['accel_${channel}_x'] =
              (ByteData.sublistView(bytes, i, i + 2).getInt16(0)) / 1000.0;
          decoded['accel_${channel}_y'] =
              (ByteData.sublistView(bytes, i + 2, i + 4).getInt16(0)) / 1000.0;
          decoded['accel_${channel}_z'] =
              (ByteData.sublistView(bytes, i + 4, i + 6).getInt16(0)) / 1000.0;
          i += 6;
          break;
        case 0x88: // GPS (9 bytes)
          // Lat: 0.0001 signed, Lon: 0.0001 signed, Alt: 0.01 signed
          double lat =
              ((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]).toSigned(
                24,
              ) /
              10000.0;
          double lon =
              ((bytes[i + 3] << 16) | (bytes[i + 4] << 8) | bytes[i + 5])
                  .toSigned(24) /
              10000.0;
          double alt =
              ((bytes[i + 6] << 16) | (bytes[i + 7] << 8) | bytes[i + 8])
                  .toSigned(24) /
              100.0;
          decoded['gps_$channel'] = {
            "latitude": lat,
            "longitude": lon,
            "altitude": alt,
          };
          i += 9;
          break;
        default:
          debugPrint("Unknown LPP Type: $type at index $i");
          return decoded;
      }
    }
    return decoded;
  }
}
