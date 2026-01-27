import 'package:flutter/foundation.dart';
import 'models.dart';

abstract class SensorRepository {
  Stream<SensorData> getLiveReadings(String deviceId);
  Future<List<Map<String, dynamic>>> getHistory(String deviceId);
  Future<void> sendCommand(Device device);

  ValueNotifier<bool> get isMonitoring;
  ValueNotifier<String> get statusLog;

  ValueNotifier<Map<String, bool>> get alarmStatus;
  
  Future<void> startMonitoring(List<Device> devices);
  void stopMonitoring();

  SensorData? getLastReading(String deviceId);
}