import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mqtt_wrapper/mqtt_wrapper.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'models.dart';
import 'services.dart';
import 'config.dart';
import 'database_service.dart';

class MqttDashboard extends StatefulWidget {
  const MqttDashboard({super.key});

  @override
  State<MqttDashboard> createState() => _MqttDashboardState();
}

class _MqttDashboardState extends State<MqttDashboard> {
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();
  late MqttWrapper mqtt;

  bool isConnected = false;
  bool isLoadingKeys = true;

  TTNProfile? selectedProfile;
  SensorData? currentReading;

  // Status Log for the UI
  String lastLog = "Ready to connect.";

  // History view
  List<Map<String, dynamic>> _historicalData = [];
  bool _showHistory = false;

  // Device ID controller
  final TextEditingController deviceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  // --- Logic A: Load Keys on Startup ---
  Future<void> _loadKeys() async {
    for (var profile in ttnProfiles) {
      String? storedKey = await _storageService.getKey(profile.appId);
      if (storedKey != null && storedKey.isNotEmpty) {
        profile.accessKey = storedKey;
      }
    }
    setState(() {
      isLoadingKeys = false;
      selectedProfile = ttnProfiles.last; // Default to RAK since it's critical
      // Set initial device ID
      if (selectedProfile?.defaultDeviceId != null) {
        deviceIdController.text = selectedProfile!.defaultDeviceId!;
      }
    });
  }

  Future<void> _showKeyInputDialog(TTNProfile profile) async {
    final keyController = TextEditingController(text: profile.accessKey ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setup Key for ${profile.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter your TTN API Key (NNSXS...)", style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 10),
            TextField(
              controller: keyController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "API Key",
                suffixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (keyController.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await _storageService.saveKey(profile.appId, keyController.text);
                if (!mounted) return;
                setState(() { profile.accessKey = keyController.text; });
                navigator.pop();
                messenger.showSnackBar(SnackBar(content: Text("Key saved securely!")));
              }
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  void _onMessageReceived(String message) async {
    // 1. Extract Device ID from formatted message
    String deviceId = '';
    if (message.contains('Device: ')) {
      int start = message.indexOf('Device: ') + 8;
      int end = message.indexOf('\n', start);
      if (end == -1) end = message.length;
      deviceId = message.substring(start, end).trim();
    }

    // 2. Extract JSON payload
    if (!message.contains('{')) return;
    String cleanJson = message.substring(message.indexOf('{'), message.lastIndexOf('}') + 1);

    try {
      Map<String, dynamic> payload = jsonDecode(cleanJson);

      // 3. Filter by target device ID
      String targetDeviceId = '';
      if (selectedProfile?.canControl == true && deviceIdController.text.isNotEmpty) {
        // For controllable devices, use manual input if provided
        targetDeviceId = deviceIdController.text;
      } else if (selectedProfile?.defaultDeviceId != null) {
        // For all devices, use profile's default device ID
        targetDeviceId = selectedProfile!.defaultDeviceId!;
      }
      
      if (targetDeviceId.isNotEmpty && deviceId.toLowerCase() != targetDeviceId.toLowerCase()) {
        debugPrint("Ignoring data from $deviceId (Target is $targetDeviceId)");
        return;
      }

      // 4. Parse sensor data
      setState(() {
        lastLog = "Updated: ${DateTime.now().toLocal().toString().split('.')[0].split(' ')[1]}";

        double? t = findValue(payload, 'temperature');
        double? h = findValue(payload, 'humidity');
        double? co2 = findValue(payload, 'co2');
        double? bat = findValue(payload, 'battery');

        double dp = (t != null && h != null) ? calculateDewPoint(t, h) : 0.0;

        currentReading = SensorData(
          temperature: t,
          humidity: h,
          co2: co2,
          battery: bat,
          dewPoint: dp,
          timestamp: DateTime.now(),
        );
      });

      // 5. Save to database
      try {
        await _databaseService.insertSensorReading(
          deviceId,
          selectedProfile?.name ?? 'Unknown',
          currentReading!,
        );
      } catch (e) {
        debugPrint("Database save error: $e");
      }
    } catch (e) {
      debugPrint("Error parsing message: $e");
    }
  }

  void disconnect() {
    if (isConnected) {
      mqtt.disconnect();
      setState(() {
        isConnected = false;
        currentReading = null;
        lastLog = "Disconnected";
      });
    }
  }

  void sendStopAlarm() {
    if (!isConnected || !selectedProfile!.canControl) return;

    // Construct Downlink: 0x01 (Base64: AQ==)
    String deviceId = deviceIdController.text;
    String topic = 'v3/${selectedProfile!.appId}/devices/$deviceId/down/push';
    String message = jsonEncode({
      "downlinks": [{ "f_port": 1, "frm_payload": "AQ==", "priority": "NORMAL" }]
    });

    mqtt.publish(topic, message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🛑 STOP Command Sent!'), backgroundColor: Colors.orange));
  }

  void connect() async {
    if (selectedProfile == null || selectedProfile!.accessKey == null) return;

    mqtt = MqttWrapper(
      appId: selectedProfile!.appId,
      accessKey: selectedProfile!.accessKey!,
      broker: selectedProfile!.broker,
    );

    mqtt.messages.listen(_onMessageReceived);

    setState(() => lastLog = "Connecting...");

    try {
      await mqtt.connect();

      // Check Status
      if (mqtt.client.connectionStatus?.state == MqttConnectionState.connected) {

        // --- CRITICAL FIX: Strip '@ttn' for the TOPIC subscription ---
        final String cleanAppId = selectedProfile!.appId.split('@')[0];
        final String topic = "v3/$cleanAppId/devices/+/up";

        mqtt.client.subscribe(topic, MqttQos.atMostOnce);

        setState(() {
          isConnected = true;
          lastLog = "✅ Live: $cleanAppId";
        });

      } else {
        // Handle Auth Failure
        final code = mqtt.client.connectionStatus?.returnCode;
        if (!mounted) {
          // Ensure we don't call stateful APIs when widget is gone
          mqtt.client.disconnect();
          return;
        }
        if (code == MqttConnectReturnCode.notAuthorized || code == MqttConnectReturnCode.badUsernameOrPassword) {
           _showErrorSnackBar("⛔ Auth Failed: Key Rejected");
        } else {
           _showErrorSnackBar("Connection Failed: $code");
        }
        disconnect();
      }
    } catch (e) {
      if (!mounted) {
        mqtt.client.disconnect();
        return;
      }
      _showErrorSnackBar("Network Error");
      disconnect();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _loadHistoricalData() async {
    try {
      final data = await _databaseService.getLatestReadings(limit: 100);
      setState(() {
        _historicalData = data;
      });
    } catch (e) {
      debugPrint("Error loading historical data: $e");
    }
  }

  // --- Logic D: UI Construction ---
  @override
  Widget build(BuildContext context) {
    if (isLoadingKeys) return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Safe-Art Monitor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Connection Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Dropdown
                    DropdownButtonFormField<TTNProfile>(
                      decoration: InputDecoration(
                        labelText: "Select Sensor Node",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      ),
                      initialValue: selectedProfile,
                      isExpanded: true,
                      onChanged: (p) {
                        disconnect();
                        setState(() { 
                          selectedProfile = p;
                          // Set device ID to profile's default
                          if (p != null && p.defaultDeviceId != null) {
                            deviceIdController.text = p.defaultDeviceId!;
                          } else {
                            deviceIdController.clear();
                          }
                        });
                      },
                      items: ttnProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    ),
                    SizedBox(height: 10),

// Device ID Input (Visible only if control is needed or has default)
                    if (selectedProfile?.canControl == true || selectedProfile?.defaultDeviceId != null)
                      TextField(
                        controller: deviceIdController,
                        readOnly: selectedProfile?.canControl != true, // Read-only for non-controllable
                        decoration: InputDecoration(
                          labelText: selectedProfile?.canControl == true 
                            ? 'Target Device EUI (editable)' 
                            : 'Preferred Device EUI (${selectedProfile?.defaultDeviceId ?? 'none'})',
                          border: OutlineInputBorder(),
                          helperText: selectedProfile?.canControl == true 
                            ? "Format: eui-xxxxxxxxxxxxxxxx" 
                            : "This profile monitors this specific device",
                        ),
                      ),

                    SizedBox(height: 15),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (selectedProfile?.accessKey != null && !isConnected) ? connect : null,
                            icon: Icon(Icons.bolt),
                            label: Text('CONNECT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12)
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        // Edit Key Button
                        OutlinedButton(
                          onPressed: selectedProfile == null ? null : () => _showKeyInputDialog(selectedProfile!),
                          child: Icon(Icons.vpn_key, color: (selectedProfile?.accessKey != null) ? Colors.green : Colors.grey),
                        ),
                         SizedBox(width: 10),
                         // Disconnect Button
                        if (isConnected)
                          IconButton(
                            onPressed: disconnect,
                            icon: Icon(Icons.power_settings_new, color: Colors.red),
                            tooltip: "Disconnect",
                          ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(lastLog, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Toggle between current and historical view
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showHistory = false),
                  icon: Icon(Icons.show_chart),
                  label: Text('Current'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showHistory ? Colors.indigo : Colors.grey,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    _loadHistoricalData();
                    setState(() => _showHistory = true);
                  },
                  icon: Icon(Icons.history),
                  label: Text('History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showHistory ? Colors.indigo : Colors.grey,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 2. Data Dashboard (Or Loading State)
            if (isConnected && !_showHistory) _buildDashboardArea(),
            if (_showHistory) _buildHistoryArea(),

            if (!isConnected && !_showHistory)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Opacity(opacity: 0.5, child: Icon(Icons.sensors_off, size: 80, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }


  bool isDeviceOffline(DateTime? timestamp) {
    if (timestamp == null) return true;
    // 15 minutes timeout as per PDF requirement
    return DateTime.now().difference(timestamp).inMinutes > 15;
  }

  Widget _buildDashboardArea() {
    if (currentReading == null) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Waiting for sensor packet...", style: TextStyle(color: Colors.grey)),
            Text("(This can take up to 15 mins)", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    bool offline = isDeviceOffline(currentReading!.timestamp);

    return Column(
      children: [
        // Offline Warning
        if (offline)
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(8),
          margin: EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 10),
              Text("DEVICE OFFLINE (No data > 15m)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // Alert Banner
        if ((currentReading!.co2 ?? 0) > 1000)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 10),
                Text("FIRE RISK DETECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),

        // Metrics Grid
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: offline ? 0.5 : 1.0,
                child: _buildMetricCard("Temperature", "${currentReading!.temperature?.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orange),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Opacity(
                opacity: offline ? 0.5 : 1.0,
                child: _buildMetricCard("Humidity", "${currentReading!.humidity?.toStringAsFixed(1)}%", Icons.water_drop, Colors.blue),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricCard("Dew Point", "${currentReading!.dewPoint.toStringAsFixed(1)}°C", Icons.cloud_queue, Colors.purple)),
            SizedBox(width: 10),
            // Dynamic: Show Battery for RAK, CO2 for others
            (currentReading!.co2 != null)
              ? Expanded(child: _buildMetricCard("CO2", "${currentReading!.co2?.toStringAsFixed(0)} ppm", Icons.air, Colors.blueGrey))
              : Expanded(child: _buildMetricCard("Battery", "${currentReading!.battery?.toStringAsFixed(2) ?? '--'} V", Icons.battery_charging_full, Colors.green)),
          ],
        ),

        SizedBox(height: 20),

        // Stop Alarm Button (Only for RAK)
        if (selectedProfile?.canControl == true)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: sendStopAlarm,
              icon: Icon(Icons.notifications_off),
              label: Text("STOP ALARM (DOWNLINK)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.all(20),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryArea() {
    if (_historicalData.isEmpty) {
      return Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Loading historical data...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          "Historical Sensor Readings",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          "Last 100 readings from database",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        SizedBox(height: 20),

        // Historical Data List
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _historicalData.length,
          itemBuilder: (context, index) {
            final reading = _historicalData[index];
            final timestamp = DateTime.parse(reading['timestamp']);
            final deviceId = reading['device_id'];
            final profileName = reading['profile_name'];

            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timestamp.toLocal().toString().split('.')[0],
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          "$profileName - $deviceId",
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        if (reading['temperature'] != null)
                          Expanded(
                            child: _buildMiniMetric("Temp", "${reading['temperature'].toStringAsFixed(1)}°C", Icons.thermostat, Colors.orange),
                          ),
                        if (reading['humidity'] != null)
                          Expanded(
                            child: _buildMiniMetric("Hum", "${reading['humidity'].toStringAsFixed(1)}%", Icons.water_drop, Colors.blue),
                          ),
                        if (reading['co2'] != null)
                          Expanded(
                            child: _buildMiniMetric("CO2", "${reading['co2'].toStringAsFixed(0)} ppm", Icons.air, Colors.blueGrey),
                          ),
                        if (reading['battery'] != null)
                          Expanded(
                            child: _buildMiniMetric("Batt", "${reading['battery'].toStringAsFixed(2)}V", Icons.battery_charging_full, Colors.green),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}