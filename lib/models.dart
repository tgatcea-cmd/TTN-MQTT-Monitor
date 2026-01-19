import 'dart:math';

class TTNProfile {
  final String name;
  final String appId;
  final String broker;
  String? accessKey;
  final bool canControl;
  final String? defaultDeviceId;

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

  final Map<String, dynamic>? customFields;
  final String? deviceType;

  SensorData({
    this.temperature,
    this.humidity,
    this.co2,
    this.battery,
    required this.dewPoint,
    required this.timestamp,
    this.customFields,
    this.deviceType,
  });
}

double calculateDewPoint(double temp, double rh) {
  const b = 17.62;
  const c = 243.12;
  double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
  return (c * gamma) / (b - gamma);
}

double? findValue(Map<String, dynamic> payload, String baseKey) {
  if (payload.containsKey(baseKey)) return payload[baseKey]?.toDouble();

  for (var key in payload.keys) {
    if (key.startsWith('${baseKey}_')) return payload[key]?.toDouble();
  }

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
