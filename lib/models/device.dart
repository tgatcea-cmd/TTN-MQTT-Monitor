class Device {
  final String id; // Unique ID (usually appId)
  final String name; // User-friendly name
  final String appId; // TTN App ID
  final String broker; // MQTT broker
  final String deviceEui; // Device EUI
  final String? accessKey; // API key (optional, could be loaded from secure storage)
  final bool canControl; // Can send downlink commands?
  final String deviceType; // Device type: 'TTN', 'Dragino', etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  const Device({
    required this.id,
    required this.name,
    required this.appId,
    required this.broker,
    required this.deviceEui,
    this.accessKey,
    this.canControl = false,
    this.deviceType = 'TTN',
    required this.createdAt,
    required this.updatedAt,
  });

  Device copyWith({
    String? id,
    String? name,
    String? appId,
    String? broker,
    String? deviceEui,
    String? accessKey,
    bool? canControl,
    String? deviceType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      appId: appId ?? this.appId,
      broker: broker ?? this.broker,
      deviceEui: deviceEui ?? this.deviceEui,
      accessKey: accessKey ?? this.accessKey,
      canControl: canControl ?? this.canControl,
      deviceType: deviceType ?? this.deviceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'appId': appId,
      'broker': broker,
      'deviceEui': deviceEui,
      'accessKey': accessKey,
      'canControl': canControl,
      'deviceType': deviceType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      appId: json['appId'],
      broker: json['broker'],
      deviceEui: json['deviceEui'],
      deviceType: json['deviceType'] ?? 'TTN',
      accessKey: json['accessKey'],
      canControl: json['canControl'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          appId == other.appId &&
          broker == other.broker &&
          deviceEui == other.deviceEui &&
          accessKey == other.accessKey &&
          canControl == other.canControl &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      appId.hashCode ^
      broker.hashCode ^
      deviceEui.hashCode ^
      accessKey.hashCode ^
      canControl.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
