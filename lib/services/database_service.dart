import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> insertSensorReading(
    String deviceId,
    String profileName,
    SensorData data,
  ) async {
    try {
      await _ensureAuth();

      await _client.from('sensor_readings').insert({
        'device_id': deviceId,
        'profile_name': profileName,
        'temperature': data.temperature,
        'humidity': data.humidity,
        'co2': data.co2,
        'battery': data.battery,
        'dew_point': data.dewPoint,
        'timestamp': data.timestamp.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Cloud DB Insert Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getLatestReadings({
    int limit = 50,
    bool ascending = false,
  }) async {
    try {
      final List<dynamic> response = await _client
          .from('sensor_readings')
          .select()
          .order('timestamp', ascending: ascending)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Cloud DB Fetch Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSensorReadings({
    String? deviceId,
    String? profileName,
    int? limit,
    DateTime? since,
  }) async {
    try {
      var filterQuery = _client.from('sensor_readings').select();

      if (deviceId != null) {
        filterQuery = filterQuery.eq('device_id', deviceId);
      }
      if (profileName != null) {
        filterQuery = filterQuery.eq('profile_name', profileName);
      }
      if (since != null) {
        filterQuery = filterQuery.gte('timestamp', since.toIso8601String());
      }

      var transformQuery = filterQuery.order('timestamp', ascending: false);
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }

      final List<dynamic> response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Cloud DB Query Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getStats({String? deviceId}) async {
    try {
      final data = await getSensorReadings(deviceId: deviceId, limit: 1000);

      if (data.isEmpty) return {};

      double sumTemp = 0;
      double minTemp = 999;
      double maxTemp = -999;
      int count = 0;

      for (var row in data) {
        if (row['temperature'] != null) {
          double t = (row['temperature'] as num).toDouble();
          sumTemp += t;
          if (t < minTemp) minTemp = t;
          if (t > maxTemp) maxTemp = t;
          count++;
        }
      }

      return {
        'total_readings': data.length,
        'avg_temperature': count > 0 ? sumTemp / count : 0,
        'min_temperature': minTemp == 999 ? 0 : minTemp,
        'max_temperature': maxTemp == -999 ? 0 : maxTemp,
      };
    } catch (e) {
      debugPrint('Stats Error: $e');
      return {};
    }
  }

  Future<void> clearAllData() async {
    await _client.from('sensor_readings').delete().neq('id', 0);
  }

  Stream<List<Map<String, dynamic>>> subscribeToReadings({
    String? deviceId,
    String? profileName,
  }) {
    final StreamController<List<Map<String, dynamic>>> controller =
        StreamController<List<Map<String, dynamic>>>();

    DateTime? lastTimestamp;

    final timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final data = await getSensorReadings(
          deviceId: deviceId,
          profileName: profileName,
          limit: 100,
          since: lastTimestamp,
        );

        if (data.isNotEmpty && !controller.isClosed) {
          if (data.first['timestamp'] != null) {
            lastTimestamp = DateTime.parse(data.first['timestamp']);
          }
          controller.add(data);
        }
      } catch (e) {
        debugPrint('Error fetching readings: $e');
      }
    });

    controller.onCancel = () {
      timer.cancel();
    };

    return controller.stream;
  }

  void unsubscribeFromReadings() {
    debugPrint('Unsubscribing from readings');
  }

  Future<void> _ensureAuth() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      await _client.auth.signInAnonymously();
    }
  }

  Future<void> insertTestSensorReading([SensorData? specificData]) async {
    try {
      SensorData data;

      if (specificData != null) {
        data = specificData;
      } else {
        final random = Random();
        final temperature = 15.0 + random.nextDouble() * 20.0;
        final humidity = 30.0 + random.nextDouble() * 50.0;
        final co2 = 400.0 + random.nextDouble() * 600.0;
        final battery = 2.8 + random.nextDouble() * 0.5;
        final dewPoint = _calculateDewPoint(temperature, humidity);

        data = SensorData(
          temperature: temperature,
          humidity: humidity,
          co2: co2,
          battery: battery,
          dewPoint: dewPoint,
          timestamp: DateTime.now(),
        );
      }

      await insertSensorReading(
        'euid-test_device',
        'Test Device (Simulated)',
        data,
      );

      debugPrint(
        '✅ Test reading inserted: ${data.temperature?.toStringAsFixed(1)}°C',
      );
    } catch (e) {
      debugPrint('Error inserting test data: $e');
      rethrow;
    }
  }

  double _calculateDewPoint(double temp, double rh) {
    const b = 17.62;
    const c = 243.12;
    double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
    return (c * gamma) / (b - gamma);
  }

  Future<Map<String, double>> getDailyStats(String deviceId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final response = await _client
          .from('sensor_readings')
          .select('temperature')
          .eq('device_id', deviceId)
          .gte('timestamp', startOfDay.toIso8601String())
          .lt('timestamp', endOfDay.toIso8601String());

      final List<dynamic> data = response as List<dynamic>;

      if (data.isEmpty) {
        return {'max': 0, 'min': 0, 'mho': 0, 'avg': 0};
      }

      double maxTemp = -999.0;
      double minTemp = 999.0;
      double sumTemp = 0.0;

      for (var row in data) {
        final double t = (row['temperature'] as num).toDouble();
        if (t > maxTemp) maxTemp = t;
        if (t < minTemp) minTemp = t;
        sumTemp += t;
      }

      return {
        'max': maxTemp,
        'min': minTemp,
        'mho': maxTemp - minTemp,
        'avg': sumTemp / data.length,
      };
    } catch (e) {
      debugPrint('Error calculando MHO: $e');
      return {'max': 0, 'min': 0, 'mho': 0, 'avg': 0};
    }
  }
}
