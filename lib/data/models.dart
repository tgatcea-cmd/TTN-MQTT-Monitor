import 'dart:math';

class Device {
  final String id;
  final String name;
  final String appId;
  final String broker;
  final String deviceEui;
  final String? accessKey;
  final bool canControl;
  final String deviceType;
  final String batteryMode;
  
  final int controlPort;
  final String controlPayload;

  final DateTime createdAt;

  const Device({
    required this.id,
    required this.name,
    required this.appId,
    required this.broker,
    required this.deviceEui,
    this.accessKey,
    this.canControl = false,
    this.deviceType = 'TTN',
    this.batteryMode = 'voltage',

    this.controlPort = 1,
    this.controlPayload = '01',

    required this.createdAt,
  });

  Device copyWith({
    String? name,
    String? broker,
    String? deviceEui,
    String? accessKey,
    bool? canControl,
    String? deviceType,
    String? batteryMode,
    int? controlPort,
    String? controlPayload,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      appId: appId,
      broker: broker ?? this.broker,
      deviceEui: deviceEui ?? this.deviceEui,
      accessKey: accessKey ?? this.accessKey,
      canControl: canControl ?? this.canControl,
      deviceType: deviceType ?? this.deviceType,
      batteryMode: batteryMode ?? this.batteryMode,
      
      controlPort: controlPort ?? this.controlPort,
      controlPayload: controlPayload ?? this.controlPayload,
      
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'appId': appId,
        'broker': broker,
        'deviceEui': deviceEui,
        'deviceType': deviceType,
        'batteryMode': batteryMode,
        'canControl': canControl,

        'controlPort': controlPort,
        'controlPayload': controlPayload,

        'createdAt': createdAt.toIso8601String(),
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'],
        name: json['name'],
        appId: json['appId'],
        broker: json['broker'],
        deviceEui: json['deviceEui'],
        deviceType: json['deviceType'] ?? 'TTN',
        batteryMode: json['batteryMode'] ?? 'voltage',
        canControl: json['canControl'] ?? false,

        controlPort: json['controlPort'] ?? 1,
        controlPayload: json['controlPayload'] ?? '01',

        createdAt: DateTime.parse(json['createdAt']),
      );
}

// Unified Sensor Data Model
class SensorData {
  final double? temperature;
  final double? humidity;
  final double? co2;
  final double? battery;
  final double dewPoint;
  final DateTime timestamp;
  final Map<String, dynamic>? customFields;

  SensorData({
    this.temperature,
    this.humidity,
    this.co2,
    this.battery,
    required this.dewPoint,
    required this.timestamp,
    this.customFields,
  });

  factory SensorData.fromPayload(
      Map<String, dynamic> payload, String deviceType) {
    double? find(String key) {
      if (payload.containsKey(key)) return _toDouble(payload[key]);
      final lowerKey = key.toLowerCase();
      for (var k in payload.keys) {
        if (k.toLowerCase().startsWith(lowerKey)) return _toDouble(payload[k]);
      }
      return null;
    }

    double? temp, hum, co2, batt;

    if (deviceType.toLowerCase().contains('dragino')) {
      temp = find('TempC_SHT') ?? find('TempC1');
      hum = find('Hum_SHT');
      batt = find('BatV');
    } else {
      temp = find('temperature');
      hum = find('humidity') ?? find('relative_humidity');
      co2 = find('co2');
      batt = find('battery') ?? find('analog_in');
    }

    double dew = 0.0;
    if (temp != null && hum != null) {
      const b = 17.62;
      const c = 243.12;
      double gamma = (log(hum / 100.0) + ((b * temp) / (c + temp)));
      dew = (c * gamma) / (b - gamma);
    }

    return SensorData(
      temperature: temp,
      humidity: hum,
      co2: co2,
      battery: batt,
      dewPoint: dew,
      timestamp: DateTime.now(),
      customFields: payload,
    );
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }
}