import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models.dart';
import '../sensor_repository.dart'; // Import the interface

// 1. Implement the Interface
class MockDataService implements SensorRepository {
  @override
  final ValueNotifier<Map<String, bool>> alarmStatus = ValueNotifier({});
  @override
  final ValueNotifier<bool> isMonitoring = ValueNotifier(false);
  @override
  final ValueNotifier<String> statusLog = ValueNotifier("Demo System Ready");
  
  final Map<String, SensorData> _cache = {};
  @override
  SensorData? getLastReading(String deviceId) => _cache[deviceId];
  
  @override
  Future<void> startMonitoring(List<Device> devices) async {
    statusLog.value = "Initializing Demo Mode...";
    await Future.delayed(const Duration(milliseconds: 800)); // Fake loading
    
    isMonitoring.value = true;
    statusLog.value = "Demo Running: ${devices.length} simulated devices";
  }

  @override
  void stopMonitoring() {
    isMonitoring.value = false;
    statusLog.value = "Demo Stopped";
  }

  @override
  Stream<SensorData> getLiveReadings(String deviceId) {
    return Stream.periodic(const Duration(seconds: 1), (count) {
      if (!isMonitoring.value) {
        throw Exception("Monitoring is stopped");
      }
      final random = Random();

      double timeOffset = DateTime.now().millisecondsSinceEpoch / 10000;
      double wave = sin(timeOffset);

      final data = SensorData(
        temperature: 22 + (wave * 5) + (random.nextDouble() - 0.5),
        humidity: 50 + (random.nextDouble() * 10),
        co2: 400 + (count % 100).toDouble(),
        battery: 3.5 + (random.nextDouble() * 0.1),
        dewPoint: 15,
        timestamp: DateTime.now(),
      );
      
      _cache[deviceId] = data;
      return data;
    }).asBroadcastStream();
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String deviceId) async {
    return List.generate(50, (index) {
      final time = DateTime.now().subtract(Duration(minutes: index * 10));
      return {
        'timestamp': time.toIso8601String(),
        'temperature': 20 + Random().nextDouble() * 10,
        'humidity': 50 + Random().nextDouble() * 20,
        'co2': 400 + Random().nextInt(400),
      };
    });
  }

  @override
  Future<void> sendCommand(Device device) async {
    debugPrint("MOCK: Sending command to ${device.name}...");
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint("MOCK: Command delivered!");
  }
}
