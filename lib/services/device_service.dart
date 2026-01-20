import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models.dart'; // Correct Import

class DeviceService {
  static const String _devicesKey = 'mqtt_devices';
  static const String _keyPrefix = 'mqtt_device_key_';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<Device>> getAllDevices() async {
    await _ensurePrefs();
    final String? devicesJson = _prefs?.getString(_devicesKey);
    if (devicesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(devicesJson);
      return decoded
          .map((item) => Device.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading devices: $e');
      return [];
    }
  }

  Future<Device> addDevice({
    required String name,
    required String appId,
    required String broker,
    required String deviceEui,
    required String accessKey,
    bool canControl = false,
    String batteryMode = 'voltage',
  }) async {
    final device = Device(
      id: appId,
      name: name,
      appId: appId,
      broker: broker,
      deviceEui: deviceEui,
      canControl: canControl,
      batteryMode: batteryMode,
      createdAt: DateTime.now(),
    );

    await _secureStorage.write(key: '$_keyPrefix$appId', value: accessKey);

    final devices = await getAllDevices();
    devices.add(device);
    await _saveDevices(devices);

    return device;
  }

  Future<Device> updateDevice({
    required String id,
    String? name,
    String? broker,
    String? deviceEui,
    String? accessKey,
    bool? canControl,
    String? deviceType,
    String? batteryMode,
  }) async {
    final devices = await getAllDevices();
    final index = devices.indexWhere((d) => d.id == id);

    if (index == -1) {
      throw Exception('Device not found');
    }

    // copyWith handles the non-null logic internally
    Device updated = devices[index].copyWith(
      name: name,
      broker: broker,
      deviceEui: deviceEui,
      canControl: canControl,
      deviceType: deviceType,
      batteryMode: batteryMode,
    );

    if (accessKey != null) {
      await _secureStorage.write(
        key: '$_keyPrefix${updated.appId}',
        value: accessKey,
      );
    }

    devices[index] = updated;
    await _saveDevices(devices);

    return updated;
  }

  Future<void> deleteDevice(String id) async {
    final devices = await getAllDevices();
    devices.removeWhere((d) => d.id == id);
    await _saveDevices(devices);

    await _secureStorage.delete(key: '$_keyPrefix$id');
  }

  Future<String?> getDeviceApiKey(String appId) async {
    return await _secureStorage.read(key: '$_keyPrefix$appId');
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _saveDevices(List<Device> devices) async {
    await _ensurePrefs();
    final json = jsonEncode(devices.map((d) => d.toJson()).toList());
    await _prefs?.setString(_devicesKey, json);
  }
}