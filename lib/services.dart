import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _dbUrlKey = 'supabase_url';
  static const String _dbAnonKey = 'supabase_anon_key';

  Future<void> saveKey(String appId, String key) async {
    await _storage.write(key: appId, value: key);
  }

  Future<String?> getKey(String appId) async {
    return await _storage.read(key: appId);
  }

  Future<void> saveDatabaseConfig(String url, String key) async {
    await _storage.write(key: _dbUrlKey, value: url);
    await _storage.write(key: _dbAnonKey, value: key);
  }

  Future<Map<String, String?>> getDatabaseConfig() async {
    final url = await _storage.read(key: _dbUrlKey);
    final key = await _storage.read(key: _dbAnonKey);
    return {'url': url, 'key': key};
  }

  Future<bool> hasDatabaseConfig() async {
    final config = await getDatabaseConfig();
    return config['url'] != null && config['key'] != null;
  }

  Future<void> clearDatabaseConfig() async {
    await _storage.delete(key: _dbUrlKey);
    await _storage.delete(key: _dbAnonKey);
  }
}
