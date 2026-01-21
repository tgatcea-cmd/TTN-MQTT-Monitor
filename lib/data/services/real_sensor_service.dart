import 'package:flutter/foundation.dart';
import '../sensor_repository.dart';
import '../models.dart';
import 'monitoring_service.dart';
import 'database_service.dart';

class RealSensorService implements SensorRepository {
  final _monitor = MonitoringService();
  final _db = DatabaseService();

  @override
  ValueNotifier<bool> get isMonitoring => _monitor.isMonitoring;
  @override
  ValueNotifier<String> get statusLog => _monitor.statusLog;

  @override
  SensorData? getLastReading(String deviceId) => _monitor.getLastReading(deviceId);

  @override
  Future<void> startMonitoring(List<Device> devices) async {
    await _monitor.startMonitoring(devices);
  }

  @override
  void stopMonitoring() {
    _monitor.stopMonitoring();
  }


  @override
  Stream<SensorData> getLiveReadings(String deviceId) {
    return _monitor.getStream(deviceId);
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String deviceId) {
    return _db.getSensorReadings(deviceId: deviceId, limit: 100);
  }

  @override
  Future<void> sendCommand(Device device) async {
    await _monitor.sendStopCommand(device);
  }
}
