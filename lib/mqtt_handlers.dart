import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mqtt_wrapper/mqtt_wrapper.dart';
import 'models.dart';
import 'database_service.dart';
import 'payload_parser.dart';

class MqttHandlers {
  final DatabaseService _databaseService;
  final Function(String) onMessageReceived;

  final Function(SensorData, String) onSensorDataUpdated;
  final Function(String) onStatusUpdated;

  MqttHandlers({
    required DatabaseService databaseService,
    required this.onMessageReceived,
    required this.onSensorDataUpdated,
    required this.onStatusUpdated,
  }) : _databaseService = databaseService;

  Future<void> handleMessage(
    String message,
    String? targetDeviceId,
    String? profileName, [
    String deviceType = 'TTN',
  ]) async {
    String deviceId = '';
    if (message.contains('Device: ')) {
      int start = message.indexOf('Device: ') + 8;
      int end = message.indexOf('\n', start);
      if (end == -1) end = message.length;
      deviceId = message.substring(start, end).trim();
    }

    if (!message.contains('{')) return;
    String cleanJson = message.substring(
      message.indexOf('{'),
      message.lastIndexOf('}') + 1,
    );

    try {
      Map<String, dynamic> payload = jsonDecode(cleanJson);

      if (targetDeviceId != null &&
          targetDeviceId.isNotEmpty &&
          deviceId.toLowerCase() != targetDeviceId.toLowerCase()) {
        debugPrint("Ignoring data from $deviceId (Target is $targetDeviceId)");
        return;
      }

      final sensorData = PayloadParser.parse(payload, deviceType);

      onSensorDataUpdated(sensorData, profileName ?? 'Unknown');

      onStatusUpdated(
        "Rx: ${DateTime.now().toLocal().toString().split('.')[0].split(' ')[1]} ($profileName)",
      );

      try {
        await _databaseService.insertSensorReading(
          deviceId,
          profileName ?? 'Unknown',
          sensorData,
        );
      } catch (e) {
        debugPrint("Database save error: $e");
      }
    } catch (e) {
      debugPrint("Error parsing message: $e");
    }

    onMessageReceived(message);
  }

  void sendStopAlarm(MqttWrapper mqtt, String appId, String deviceId) {
    String topic = 'v3/$appId/devices/$deviceId/down/push';
    String message = jsonEncode({
      "downlinks": [
        {"f_port": 1, "frm_payload": "AQ==", "priority": "NORMAL"},
      ],
    });

    mqtt.publish(topic, message);
  }
}

double? findValue(Map<String, dynamic> payload, String baseKey) {
  if (payload.containsKey(baseKey)) return payload[baseKey]?.toDouble();
  for (var key in payload.keys) {
    if (key.toLowerCase().startsWith(baseKey.toLowerCase())) {
      return payload[key]?.toDouble();
    }
  }
  return null;
}

double calculateDewPoint(double temp, double rh) {
  const b = 17.62;
  const c = 243.12;
  double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
  return (c * gamma) / (b - gamma);
}
