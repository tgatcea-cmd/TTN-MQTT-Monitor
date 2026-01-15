# Architecture Diagram - Multi-Device Monitor

## System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        SAFE-ART MONITOR                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │              DASHBOARD (Orchestrator)                   │   │
│  │  ├─ Device lifecycle management                        │   │
│  │  ├─ MQTT connection coordination                       │   │
│  │  ├─ State management (readings map)                    │   │
│  │  └─ Navigation between components                      │   │
│  └────────────────────────────────────────────────────────┘   │
│                         │                                      │
│      ┌──────────────────┼──────────────────┐                  │
│      │                  │                  │                  │
│      ▼                  ▼                  ▼                  │
│  ┌─────────┐        ┌──────────┐      ┌──────────┐         │
│  │ SIDEBAR │        │CAMERA    │      │  HISTORY │         │
│  │         │        │  ROLL    │      │   VIEW   │         │
│  │ - Add   │        │          │      │          │         │
│  │ - Edit  │◄─────►│- Swipe   │      │- All     │         │
│  │ - Delete│        │- Dots    │      │  readings│         │
│  │ - List  │        │- Counter │      │- Timeline│         │
│  └─────────┘        └──────────┘      └──────────┘         │
│                         │                                      │
│                         ▼                                      │
│                  ┌──────────────┐                             │
│                  │ DEVICE VIEW  │                             │
│                  │              │                             │
│                  │- Metrics Card│                             │
│                  │- Status      │                             │
│                  │- Alerts      │                             │
│                  └──────────────┘                             │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌──────────┐    ┌─────────┐
    │ DEVICE  │    │  MQTT    │    │ DATABASE│
    │ SERVICE │    │ HANDLERS │    │ SERVICE │
    │         │    │          │    │         │
    │- Add    │    │- Parse   │    │- Insert │
    │- Update │    │- Route   │    │- Query  │
    │- Delete │    │- Decode  │    │- Export │
    │- Query  │    │- Validate│    │         │
    └─────────┘    └──────────┘    └─────────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────────────────────────────────────┐
    │     PERSISTENCE LAYER                   │
    ├─────────────────────────────────────────┤
    │                                         │
    │ SharedPreferences: Device metadata      │
    │ ├─ Device list (JSON)                   │
    │ ├─ Device count                         │
    │ └─ Last sync time                       │
    │                                         │
    │ FlutterSecureStorage: API Keys          │
    │ ├─ mqtt_device_key_*                    │
    │ ├─ Encrypted                            │
    │ └─ Per-device                           │
    │                                         │
    │ SQLite Database: Sensor Readings        │
    │ ├─ Timestamp                            │
    │ ├─ Device ID                            │
    │ ├─ Profile Name                         │
    │ ├─ Temperature                          │
    │ ├─ Humidity                             │
    │ ├─ CO2                                  │
    │ ├─ Battery                              │
    │ └─ Dew Point                            │
    │                                         │
    └─────────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
    ┌──────────────┐            ┌─────────────────┐
    │   MQTT       │            │   MQTT CLIENT   │
    │   HANDLERS   │  ◄────────►│   (Per Device)  │
    │              │            │                 │
    │ - Subscribe  │            │  Device 1: mqtt1│
    │ - Publish    │            │  Device 2: mqtt2│
    │ - Disconnect │            │  Device 3: mqtt3│
    └──────────────┘            └─────────────────┘
                                        │
                                        ▼
                                    ┌───────────┐
                                    │ TTN Cloud │
                                    │           │
                                    │ v3/app/   │
                                    │ devices/+ │
                                    │ /up       │
                                    └───────────┘
```

## Data Flow: Adding a Device

```
┌──────────────────┐
│  User Action:    │
│  "+ Add Device"  │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  Device Config Dialog       │
│  (user enters details)      │
└────────┬────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  DeviceService.addDevice()           │
│                                      │
│  1. Create Device object             │
│  2. Save to SharedPreferences (JSON) │
│  3. Save API Key securely            │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  Dashboard state update              │
│  - Add to devices list               │
│  - Initialize device readings entry  │
│  - Refresh sidebar                   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  UI Updated                          │
│  - Sidebar shows new device          │
│  - Can be included in monitoring     │
└──────────────────────────────────────┘
```

## Data Flow: Receiving a Message

```
┌──────────────────────────┐
│  TTN Cloud sends data:   │
│  v3/app/devices/+/up     │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  MQTT Client receives message    │
│  (device-specific client)        │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  Message Listener                    │
│  (in dashboard)                      │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  MqttHandlers.handleMessage()        │
│                                      │
│  1. Extract Device ID from message  │
│  2. Parse JSON payload              │
│  3. Validate device ID matches      │
│  4. Calculate dew point             │
│  5. Create SensorData object        │
└────────┬─────────────────────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌────────────────────┐    ┌─────────────────────┐
│ DatabaseService    │    │ onSensorDataUpdated │
│.insertSensorReading│    │ callback            │
│                    │    │                     │
│ Save to SQLite:    │    │ Update readings map:│
│- Timestamp         │    │deviceReadings[id]=  │
│- Device ID         │    │  newSensorData      │
│- Profile Name      │    │                     │
│- Temperature       │    │ setState() → UI     │
│- Humidity          │    │ refresh             │
│- CO2               │    └─────────────────────┘
│- Battery           │
│- Dew Point         │
└────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│  Data Persisted & UI Updated │
│  ✓ Database has reading      │
│  ✓ Dashboard shows data      │
│  ✓ History updated           │
└──────────────────────────────┘
```

## Device State Machine

```
┌─────────────┐
│   CREATED   │
│             │
│ New device  │
│ config set  │
└──────┬──────┘
       │
       │ Add Device
       ▼
┌──────────────────────┐
│   IN_DEVICE_LIST     │
│                      │
│ Device stored in     │
│ SharedPreferences    │
│ Ready to monitor     │
└──────┬───────────────┘
       │
       ├─────────────────────────────────┐
       │                                 │
       │ Start Monitoring                │ Edit Device
       │                                 │
       ▼                                 ▼
┌──────────────────────┐         ┌──────────────────────┐
│   MONITORING_ACTIVE  │         │    DEVICE_EDITED     │
│                      │         │                      │
│ MQTT client created  │         │ Config updated in    │
│ Receiving data       │         │ SharedPreferences    │
│ Saving to database   │         │                      │
└──────┬───────────────┘         └──────┬───────────────┘
       │                                 │
       │                                 │ Re-enable monitoring
       │◄────────────────────────────────┘
       │
       │ Stop Monitoring or Delete
       │
       ▼
┌──────────────────────┐
│    MONITORING_IDLE   │
│                      │
│ MQTT client closed   │
│ Device config intact │
│ Ready to restart     │
└──────┬───────────────┘
       │
       │ Delete Device
       │
       ▼
┌──────────────────────┐
│    DELETED           │
│                      │
│ Removed from config  │
│ (data stays in DB)   │
└──────────────────────┘
```

## Key Interactions

### Dashboard ↔ Device Service
```
dashboard.dart
    │
    ├─ _deviceService.init()
    ├─ _deviceService.getAllDevices()
    ├─ _deviceService.addDevice(...)
    ├─ _deviceService.updateDevice(...)
    ├─ _deviceService.deleteDevice(...)
    └─ _deviceService.getDeviceApiKey(...)
```

### Dashboard ↔ MQTT Handlers
```
dashboard.dart
    │
    ├─ _mqttHandlers.handleMessage(msg, deviceEui, deviceId)
    │   └─ onSensorDataUpdated callback → setState()
    │
    └─ _mqttHandlers.sendStopAlarm(mqttClient, appId, deviceEui)
```

### Dashboard ↔ UI Components
```
dashboard.dart
    │
    ├─ Sidebar
    │   ├─ onDeviceSelected
    │   ├─ onAddDevice
    │   ├─ onEditDevice
    │   └─ onDeleteDevice
    │
    ├─ Camera Roll
    │   ├─ onDeviceChanged
    │   └─ deviceViewBuilder
    │
    └─ Config Dialog
        └─ onSave
```
