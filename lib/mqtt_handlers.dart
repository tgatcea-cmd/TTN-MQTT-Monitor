import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mqtt_wrapper/mqtt_wrapper.dart';
import 'models.dart';
import 'database_service.dart';
import 'payload_parser.dart';

/// Handles all MQTT-related operations and message processing
class MqttHandlers {
  final DatabaseService _databaseService;
  final Function(String) onMessageReceived;
  // CHANGED: Added profileName string to callback signature
  final Function(SensorData, String) onSensorDataUpdated;
  final Function(String) onStatusUpdated;

  MqttHandlers({
    required DatabaseService databaseService,
    required this.onMessageReceived,
    required this.onSensorDataUpdated,
    required this.onStatusUpdated,
  }) : _databaseService = databaseService;

  /// Process incoming MQTT message
  Future<void> handleMessage(
    String message,
    String? targetDeviceId,
    String? profileName, [
    String deviceType = 'TTN',
  ]) async {
    // 1. Extract Device ID from formatted message
    String deviceId = '';
    if (message.contains('Device: ')) {
      int start = message.indexOf('Device: ') + 8;
      int end = message.indexOf('\n', start);
      if (end == -1) end = message.length;
      deviceId = message.substring(start, end).trim();
    }

    // 2. Extract JSON payload
    if (!message.contains('{')) return;
    String cleanJson = message.substring(
      message.indexOf('{'),
      message.lastIndexOf('}') + 1,
    );

    try {
      Map<String, dynamic> payload = jsonDecode(cleanJson);

      // 3. Filter by target device ID
      if (targetDeviceId != null &&
          targetDeviceId.isNotEmpty &&
          deviceId.toLowerCase() != targetDeviceId.toLowerCase()) {
        debugPrint("Ignoring data from $deviceId (Target is $targetDeviceId)");
        return;
      }

      // 4. Parse sensor data using flexible parser
      final sensorData = PayloadParser.parse(payload, deviceType);

      // CHANGED: Pass profileName back to the UI handler
      onSensorDataUpdated(sensorData, profileName ?? 'Unknown');
      
      onStatusUpdated(
          "Rx: ${DateTime.now().toLocal().toString().split('.')[0].split(' ')[1]} ($profileName)");

      // 5. Save to database
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

  /// Send STOP alarm command via downlink
  void sendStopAlarm(
    MqttWrapper mqtt,
    String appId,
    String deviceId,
  ) {
    String topic = 'v3/$appId/devices/$deviceId/down/push';
    String message = jsonEncode({
      "downlinks": [
        {"f_port": 1, "frm_payload": "AQ==", "priority": "NORMAL"},
      ],
    });

    mqtt.publish(topic, message);
  }
}

/// Helper function from models.dart - finds value in payload
double? findValue(Map<String, dynamic> payload, String baseKey) {
  if (payload.containsKey(baseKey)) return payload[baseKey]?.toDouble();
  for (var key in payload.keys) {
    if (key.toLowerCase().startsWith(baseKey.toLowerCase())) {
      return payload[key]?.toDouble();
    }
  }
  return null;
}

/// Helper function from models.dart - calculates dew point
double calculateDewPoint(double temp, double rh) {
  const b = 17.62;
  const c = 243.12;
  double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
  return (c * gamma) / (b - gamma);
}