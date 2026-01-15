import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Get the Supabase client instance
  SupabaseClient get _client => Supabase.instance.client;

  /// Insert a new reading into the Cloud DB
  Future<void> insertSensorReading(
      String deviceId, String profileName, SensorData data) async {
    try {
      await _client.from('sensor_readings').insert({
        'device_id': deviceId,
        'profile_name': profileName,
        'temperature': data.temperature,
        'humidity': data.humidity,
        'co2': data.co2,
        'battery': data.battery,
        'dew_point': data.dewPoint,
        'timestamp': data.timestamp.toIso8601String(),
        // Add custom fields if your Supabase schema supports JSONB
        // 'custom_fields': data.customFields, 
      });
    } catch (e) {
      debugPrint('Cloud DB Insert Error: $e');
      rethrow;
    }
  }

  /// Get latest readings (for History View)
  Future<List<Map<String, dynamic>>> getLatestReadings({int limit = 50}) async {
    try {
      final List<dynamic> response = await _client
          .from('sensor_readings')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Cloud DB Fetch Error: $e');
      return [];
    }
  }

  /// Get filtered readings with advanced queries
  Future<List<Map<String, dynamic>>> getSensorReadings({
    String? deviceId,
    String? profileName,
    int? limit,
    DateTime? since,
  }) async {
    try {
      var filterQuery = _client.from('sensor_readings').select();

      // Apply filters first
      if (deviceId != null) {
        filterQuery = filterQuery.eq('device_id', deviceId);
      }
      if (profileName != null) {
        filterQuery = filterQuery.eq('profile_name', profileName);
      }
      if (since != null) {
        filterQuery = filterQuery.gte('timestamp', since.toIso8601String());
      }

      // Then apply ordering and limiting (different type, use separate variable)
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

  /// Get statistics (min/max/avg) using Postgres aggregation
  /// Note: This requires creating a Database Function in Supabase
  /// or doing client-side calculation. Here is client-side for simplicity.
  Future<Map<String, dynamic>> getStats({String? deviceId}) async {
    try {
      // Fetch recent history for calc (doing full table agg on client is heavy)
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
    // Usually blocked by RLS (Row Level Security) for safety, 
    // but useful for dev.
    await _client.from('sensor_readings').delete().neq('id', 0); // Delete all
  }

  /// Subscribe to periodic updates of sensor readings (every 2 seconds)
  /// Returns a stream that emits latest readings
  Stream<List<Map<String, dynamic>>> subscribeToReadings({
    String? deviceId,
    String? profileName,
  }) {
    final StreamController<List<Map<String, dynamic>>> controller =
        StreamController<List<Map<String, dynamic>>>();

    DateTime? lastTimestamp;

    // Fetch new readings every 2 seconds
    final timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        // Only fetch readings newer than last known timestamp
        final data = await getSensorReadings(
          deviceId: deviceId,
          profileName: profileName,
          limit: 100,
          since: lastTimestamp,
        );

        if (data.isNotEmpty && !controller.isClosed) {
          // Update lastTimestamp to the newest reading
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

  /// Unsubscribe from updates (cancels the polling timer)
  void unsubscribeFromReadings() {
    // Streams handle their own cleanup via Timer.cancel() in onCancel
    debugPrint('Unsubscribing from readings');
  }

  /// Insert test sensor data for development/testing
  /// Creates a reading with random temperature/humidity values
  Future<void> insertTestSensorReading() async {
    try {
      final random = Random();
      final temperature = 15.0 + random.nextDouble() * 20.0; // 15-35°C
      final humidity = 30.0 + random.nextDouble() * 50.0; // 30-80%
      final co2 = 400.0 + random.nextDouble() * 600.0; // 400-1000 ppm
      final battery = 2.8 + random.nextDouble() * 0.5; // 2.8-3.3V

      final dewPoint = _calculateDewPoint(temperature, humidity);

      await insertSensorReading(
        'euid-test_device',
        'test_profile',
        SensorData(
          temperature: temperature,
          humidity: humidity,
          co2: co2,
          battery: battery,
          dewPoint: dewPoint,
          timestamp: DateTime.now(),
        ),
      );

      debugPrint(
          '✅ Test reading inserted: ${temperature.toStringAsFixed(1)}°C, ${humidity.toStringAsFixed(1)}%');
    } catch (e) {
      debugPrint('Error inserting test data: $e');
      rethrow;
    }
  }

  /// Calculate dew point from temperature and humidity
  double _calculateDewPoint(double temp, double rh) {
    const b = 17.62;
    const c = 243.12;
    double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
    return (c * gamma) / (b - gamma);
  }
}