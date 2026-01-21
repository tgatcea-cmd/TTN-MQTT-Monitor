import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../sensor_repository.dart';
import 'mock_data_service.dart';
import 'real_sensor_service.dart';
import 'device_service.dart';
import 'monitoring_service.dart';
import 'database_service.dart';

class AppController {
  
  // ############################################################
  static const bool USE_DEMO_MODE = false; // Cambiar a 'true' para usar datos simulados
  // ############################################################
  late final SensorRepository _repository;
  
  AppController() {
    // DEPENDENCY INJECTION (The "Plug")
    if (USE_DEMO_MODE) {
      _repository = MockDataService();
      debugPrint("⚠️ RUNNING IN DEMO MODE (Mock Data)");
    } else {
      _repository = RealSensorService();
    }
  }

  // Parametros locales
  final DeviceService _deviceService = DeviceService();

  // Notificadores de Estado -> Los consume el Frontend
  final ValueNotifier<List<Device>> devices = ValueNotifier([]);
  final ValueNotifier<bool> isLoading = ValueNotifier(true);
  final ValueNotifier<Map<String, List<Map<String, dynamic>>>> historyCache =
      ValueNotifier({});

  // Notificador de Estado de Monitoreo
  ValueNotifier<bool> get isMonitoring => _repository.isMonitoring;
  ValueNotifier<String> get statusLog => _repository.statusLog;

  // Obtener Stream de Datos en Vivo para un Dispositivo
  Stream<SensorData> getDeviceStream(String deviceId) => 
        _repository.getLiveReadings(deviceId);

  Future<void> init() async {
    await _deviceService.init();
    await refreshDevices();
  }

  Future<void> refreshDevices() async {
    isLoading.value = true;
    try {
      var fetchedDevices = await _deviceService.getAllDevices();
      List<Device> fullDevices = [];
      for (var d in fetchedDevices) {
        final key = await _deviceService.getDeviceApiKey(d.appId);
        fullDevices.add(key != null ? d.copyWith(accessKey: key) : d);
      }
      devices.value = fullDevices;
    } catch (e) {
      debugPrint("Error loading devices: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadHistoryFor(Device device) async {
    try {
      final data = await _repository.getHistory(device.deviceEui);
      final newCache = Map<String, List<Map<String, dynamic>>>.from(
        historyCache.value,
      );
      newCache[device.id] = data;
      historyCache.value = newCache;
    } catch (e) {
      debugPrint("History Load Error: $e");
    }
  }

  void toggleMonitoring() {
    if (_repository.isMonitoring.value) {
      _repository.stopMonitoring();
    } else {
      _repository.startMonitoring(devices.value);
    }
  }

  Future<void> sendStopCommand(Device device) async {
    await _repository.sendCommand(device);
  }

  Future<void> addDevice(Device d, String apiKey) async {
    await _deviceService.addDevice(
      name: d.name,
      appId: d.appId,
      broker: d.broker,
      deviceEui: d.deviceEui,
      accessKey: apiKey,
      canControl: d.canControl,
      batteryMode: d.batteryMode,
    );
    await refreshDevices();
  }

  Future<void> updateDevice(Device d, String? apiKey) async {
    await _deviceService.updateDevice(
      id: d.id,
      name: d.name,
      broker: d.broker,
      deviceEui: d.deviceEui,
      accessKey: apiKey,
      canControl: d.canControl,
      batteryMode: d.batteryMode,
    );
    await refreshDevices();
  }

  Future<void> deleteDevice(Device d) async {
    await _deviceService.deleteDevice(d.id);
    await refreshDevices();
  }
  
  SensorData? getLastKnownData(String deviceId) {
    return _repository.getLastReading(deviceId);
  }
}
