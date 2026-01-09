import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Secure Storage Service ---
class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveKey(String appId, String key) async {
    await _storage.write(key: appId, value: key);
  }

  Future<String?> getKey(String appId) async {
    return await _storage.read(key: appId);
  }
}