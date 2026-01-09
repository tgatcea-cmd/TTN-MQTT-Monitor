import 'dart:math';

// --- Data Models ---
class TTNProfile {
  final String name;
  final String appId;
  final String broker;
  String? accessKey;
  final bool canControl; // Does this device accept "Stop Alarm"?
  final String? defaultDeviceId; // Preferred device for this profile

  TTNProfile({
    required this.name,
    required this.appId,
    required this.broker,
    this.accessKey,
    this.canControl = false,
    this.defaultDeviceId,
  });
}

class SensorData {
  final double? temperature;
  final double? humidity;
  final double? co2;
  final double? battery;
  final double dewPoint;
  final DateTime timestamp;

  SensorData({
    this.temperature,
    this.humidity,
    this.co2,
    this.battery,
    required this.dewPoint,
    required this.timestamp,
  });
}

// --- Utility Functions ---
double calculateDewPoint(double temp, double rh) {
  const b = 17.62;
  const c = 243.12;
  double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
  return (c * gamma) / (b - gamma);
}

// Smart Finder: Finds 'temperature', 'temperature_1', etc.
double? findValue(Map<String, dynamic> payload, String baseKey) {
  if (payload.containsKey(baseKey)) return payload[baseKey]?.toDouble();

  // Scan for CayenneLPP suffixes (e.g., temperature_1)
  for (var key in payload.keys) {
    if (key.startsWith('${baseKey}_')) return payload[key]?.toDouble();
  }

  // Special Mappings
  if (baseKey == 'humidity') {
    for (var key in payload.keys) {
      if (key.startsWith('relative_humidity_')) return payload[key]?.toDouble();
    }
  }
  if (baseKey == 'battery') {
    for (var key in payload.keys) {
      if (key.startsWith('analog_in_')) return payload[key]?.toDouble();
    }
  }
  return null;
}