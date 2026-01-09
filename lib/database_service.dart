import 'dart:async';
import 'package:path/path.dart';
import 'models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal() {
    // Initialize sqflite for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sensor_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sensor_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        profile_name TEXT NOT NULL,
        temperature REAL,
        humidity REAL,
        co2 REAL,
        battery REAL,
        dew_point REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertSensorReading(String deviceId, String profileName, SensorData data) async {
    final db = await database;
    await db.insert(
      'sensor_readings',
      {
        'device_id': deviceId,
        'profile_name': profileName,
        'temperature': data.temperature,
        'humidity': data.humidity,
        'co2': data.co2,
        'battery': data.battery,
        'dew_point': data.dewPoint,
        'timestamp': data.timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSensorReadings({
    String? deviceId,
    String? profileName,
    int? limit,
    DateTime? since,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += 'device_id = ?';
      whereArgs.add(deviceId);
    }

    if (profileName != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'profile_name = ?';
      whereArgs.add(profileName);
    }

    if (since != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(since.toIso8601String());
    }

    String query = 'SELECT * FROM sensor_readings';
    if (whereClause.isNotEmpty) {
      query += ' WHERE $whereClause';
    }
    query += ' ORDER BY timestamp DESC';

    if (limit != null) {
      query += ' LIMIT $limit';
    }

    return await db.rawQuery(query, whereArgs);
  }

  Future<List<Map<String, dynamic>>> getLatestReadings({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'sensor_readings',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<void> deleteOldReadings(Duration olderThan) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(olderThan);
    await db.delete(
      'sensor_readings',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<Map<String, dynamic>> getStats({String? deviceId, String? profileName}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += 'device_id = ?';
      whereArgs.add(deviceId);
    }

    if (profileName != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'profile_name = ?';
      whereArgs.add(profileName);
    }

    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_readings,
        AVG(temperature) as avg_temperature,
        MIN(temperature) as min_temperature,
        MAX(temperature) as max_temperature,
        AVG(humidity) as avg_humidity,
        MIN(humidity) as min_humidity,
        MAX(humidity) as max_humidity,
        AVG(co2) as avg_co2,
        MIN(co2) as min_co2,
        MAX(co2) as max_co2,
        AVG(battery) as avg_battery,
        MIN(battery) as min_battery,
        MAX(battery) as max_battery,
        MIN(timestamp) as first_reading,
        MAX(timestamp) as last_reading
      FROM sensor_readings
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
    ''', whereArgs);

    return result.first;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sensor_readings');
  }
}