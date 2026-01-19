import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device.dart'; // Tu modelo original
import '../payload_parser.dart'; // Tu parser original
import '../models.dart'; // Para SensorData

class IoTBrain extends ChangeNotifier {
  MqttServerClient? _client;

  // Estado del Dispositivo Activo
  Device? activeDevice;
  bool isConnected = false;

  // Datos en tiempo real
  Map<String, SensorData> latestReadings = {};
  List<String> commandLog = [];

  // Historial para cálculo de MHO (Oscilación Térmica)
  final Map<String, List<double>> _tempHistory = {};

  // Cambiar dispositivo y reconectar
  Future<void> switchDevice(Device device) async {
    if (activeDevice?.id == device.id && isConnected) return;

    await disconnect();
    activeDevice = device;
    notifyListeners();

    if (device.accessKey != null && device.accessKey!.isNotEmpty) {
      await _connect(device);
    } else {
      _log("ERROR: Sin API Key para ${device.name}");
    }
  }

  Future<void> _connect(Device device) async {
    _log("INICIANDO SISTEMA: ${device.name.toUpperCase()}...");

    final String clientId = 'safe-art-${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient(device.broker, clientId);
    _client!.port = 8883;
    _client!.secure = true;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(device.appId, device.accessKey!)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _client!.connectionMessage = connMess;

    try {
      await _client!.connect();
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        isConnected = true;
        _log("ENLACE ESTABLECIDO CON TTN");

        // Suscripción dinámica usando el AppID del dispositivo
        final cleanAppId = device.appId.split('@')[0];
        final topic = "v3/$cleanAppId/devices/+/up";

        _client!.subscribe(topic, MqttQos.atMostOnce);
        _client!.updates!.listen(_onMessage);

        notifyListeners();
      }
    } catch (e) {
      _log("FALLO CRÍTICO DE CONEXIÓN: $e");
      isConnected = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    isConnected = false;
    latestReadings.clear(); // Limpiar datos visuales al cambiar
    notifyListeners();
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> c) {
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String pt = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    try {
      final json = jsonDecode(pt);
      final String devId = json['end_device_ids']['device_id'];

      // Filtramos para asegurar que es el dispositivo que queremos ver
      // (Opcional: Si quieres ver todos los dispositivos de esa AppID, quita este if)
      if (activeDevice != null &&
          !activeDevice!.deviceEui.contains(devId) &&
          devId != activeDevice!.deviceEui) {
        // Nota: A veces TTN manda el ID, a veces el EUI. Ajustar según necesidad.
      }

      Map<String, dynamic> uplink = json['uplink_message'];
      Map<String, dynamic> decoded = uplink['decoded_payload'] ?? {};

      // Usamos tu PayloadParser original
      final data = PayloadParser.parse(
        decoded,
        activeDevice?.deviceType ?? 'TTN',
      );

      latestReadings[activeDevice!.id] =
          data; // Guardamos asociado al ID interno
      _updateAnalytics(activeDevice!.id, data.temperature);
      _log("DATOS RECIBIDOS: ${data.temperature?.toStringAsFixed(1)}°C");

      notifyListeners();
    } catch (e) {
      debugPrint("Error parseo: $e");
    }
  }

  void _updateAnalytics(String id, double? temp) {
    if (temp == null) return;
    if (!_tempHistory.containsKey(id)) _tempHistory[id] = [];
    _tempHistory[id]!.add(temp);
    if (_tempHistory[id]!.length > 150) _tempHistory[id]!.removeAt(0);
  }

  double getMHO(String id) {
    final history = _tempHistory[id];
    if (history == null || history.isEmpty) return 0.0;
    return (history.reduce(max) - history.reduce(min));
  }

  // Comando Downlink para controlar el dispositivo
  void sendResetCommand() {
    if (!isConnected || activeDevice == null) return;
    if (!activeDevice!.canControl) {
      _log("ACCESO DENEGADO: Dispositivo de solo lectura");
      return;
    }

    final cleanAppId = activeDevice!.appId.split('@')[0];
    final topic = "v3/$cleanAppId/devices/${activeDevice!.deviceEui}/down/push";

    final builder = MqttClientPayloadBuilder();
    // Payload estándar para resetear alarma (ejemplo: 0x01 en puerto 1)
    final jsonCmd = jsonEncode({
      "downlinks": [
        {"f_port": 1, "frm_payload": "AQ==", "priority": "NORMAL"},
      ],
    });

    builder.addString(jsonCmd);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    _log("COMANDO ENVIADO: RESET ALARMA");
  }

  void _log(String msg) {
    commandLog.insert(
      0,
      "${DateTime.now().toString().split(' ')[1].substring(0, 8)} > $msg",
    );
    if (commandLog.length > 50) commandLog.removeLast();
    notifyListeners();
  }
}
