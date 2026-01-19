import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MqttWrapper {
  late MqttServerClient client;
  final String appId;
  final String accessKey;
  final String broker;
  final int port;
  final bool secure;

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  Stream<String> get messages => _messageController.stream;

  MqttWrapper({
    required this.appId,
    required this.accessKey,
    this.broker = 'eu1.cloud.thethings.network',
    this.port = 8883,
    this.secure = true,
  }) {
    String clientId =
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}_${appId.split('@')[0]}';
    client = MqttServerClient(broker, clientId);
    client.port = port;
    client.secure = secure;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    if (secure) {
      client.onBadCertificate = (dynamic cert) => true;
      client.securityContext = SecurityContext.defaultContext;
    }

    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
  }

  Future<void> connect() async {
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .authenticateAs(appId, accessKey)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint('MQTT client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      debugPrint('Socket exception - $e');
      client.disconnect();
    } catch (e) {
      debugPrint('Generic MQTT exception - $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('TTN MQTT client connected');

      client.subscribe('v3/$appId/devices/+/#', MqttQos.atLeastOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        try {
          Map<String, dynamic> data = json.decode(pt);
          String deviceId = data['end_device_ids']['device_id'] ?? 'unknown';
          String type = 'Unknown';
          String payload = 'No payload';
          if (data.containsKey('uplink_message')) {
            type = 'Uplink';
            var uplink = data['uplink_message'];
            var decodedPayload = uplink['decoded_payload'];
            payload = decodedPayload != null
                ? jsonEncode(decodedPayload)
                : uplink['payload'] ?? 'no payload';
          } else if (data.containsKey('downlink_queued')) {
            type = 'Downlink Queued';
            payload = data['downlink_queued'].toString();
          } else if (data.containsKey('downlink_sent')) {
            type = 'Downlink Sent';
            payload = data['downlink_sent'].toString();
          }
          _messageController.add(
            '$type - Device: $deviceId\nPayload: $payload',
          );
        } catch (e) {
          _messageController.add('Error parsing message: $pt');
        }
      });
    } else {
      debugPrint(
        'TTN MQTT client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      client.disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    _messageController.close();
  }

  void publish(String topic, String message) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void onConnected() {
    debugPrint('Connected to TTN MQTT broker');
  }

  void onDisconnected() {
    debugPrint('Disconnected from TTN MQTT broker');
  }

  void onSubscribed(String topic) {
    debugPrint('Subscribed to $topic');
  }
}
