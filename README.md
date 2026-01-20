# Safe-Art Monitor – Architecture Report

## 1. Executive Summary

**Safe-Art Monitor** is a Flutter-based IoT application designed to monitor environmental conditions (Temperature, Humidity, CO2) for art preservation. It connects to LoRaWAN devices (via The Things Network or Dragino) using **MQTT** for real-time data and utilizes **Supabase** for historical persistence and user authentication.

The architecture follows a **Service-Oriented** approach where UI components interact with Singleton services to handle business logic, data persistence, and network communication.

---

## 2. High-Level Architecture Diagram

The application is structured into three distinct layers: **Presentation**, **Domain/Service**, and **Data**.

```mermaid
graph TD
    subgraph Presentation Layer
        Dashboard[MqttDashboard]
        Widgets[Widgets: Charts, CameraRoll, Metrics]
    end

    subgraph Service Layer
        DevService[DeviceService]
        MonService[MonitoringService]
        DBService[DatabaseService]
        MQTT[MqttWrapper]
    end

    subgraph Data Layer
        Local[Secure Storage / SharedPrefs]
        CloudDB[Supabase (PostgreSQL)]
        Broker[MQTT Broker (TTN)]
    end

    Dashboard --> DevService
    Dashboard --> MonService
    Dashboard --> DBService
    
    MonService --> MQTT
    MonService --> DBService
    
    DevService --> Local
    DBService --> CloudDB
    MQTT <--> Broker

```

---

## 3. Tech Stack & Dependencies

* **Framework:** Flutter (Dart)
* **State Management:** `setState`, `ValueNotifier`, and Streams.
* **Connectivity:**
* **MQTT:** `mqtt_client` (for real-time sensor data).
* **Backend:** `supabase_flutter` (for database and auth).


* **Storage:**
* `shared_preferences` (for non-sensitive device lists).
* `flutter_secure_storage` (for API Keys and DB credentials).


* **Visualization:** `fl_chart` (for historical temperature graphs).

---

## 4. Core Modules & Services

The logic is encapsulated in the `lib/services/` directory.

### 4.1. Monitoring Service (`monitoring_service.dart`)

This is the heart of the real-time engine.

* **Pattern:** Singleton.
* **Responsibilities:**
* Manages multiple `MqttWrapper` instances (one per device App ID).
* Exposes a `Stream<SensorData>` for UI consumption.
* Parses raw JSON payloads into `SensorData` objects.
* Triggering database inserts upon receiving messages.
* Handling Downlink commands (e.g., stopping alarms).



### 4.2. Database Service (`database_service.dart`)

Handles all interactions with the Supabase backend.

* **Pattern:** Singleton.
* **Responsibilities:**
* Inserts sensor readings (`insertSensorReading`).
* Fetches historical data blocks (`getSensorReadings`).
* Calculates statistics (Min/Max/Avg) and Daily MHO (Oscillation).
* Provides real-time subscription streams via Supabase Realtime.



### 4.3. Device Service (`device_service.dart`)

Manages the configuration of local devices.

* **Storage Strategy:** Hybrid.
* **Device Metadata** (Name, EUI, Type)  Stored as JSON in `SharedPreferences`.
* **Sensitive Data** (Access Keys)  Stored in Encrypted `FlutterSecureStorage`.


* **CRUD Operations:** Add, Update, Delete devices.

### 4.4. MQTT Wrapper (`mqtt_wrapper.dart`)

A low-level wrapper around the `mqtt_server_client`.

* **Features:** Handles TLS/SSL connections (port 8883) for TTN, subscription management, and auto-reconnection logic.

---

## 5. Data Models (`models.dart`)

The application uses two primary data models which handle the normalization of incoming data.

### 5.1. Device

Represents a physical LoRaWAN node.

* **Fields:** `id`, `name`, `deviceEui`, `broker`, `accessKey`, `deviceType` (TTN/Dragino).
* **Configuration:** Includes UI preferences like `batteryMode` (Voltage vs Percentage).

### 5.2. SensorData

The normalized payload object.

* **Factory `fromPayload**`: This is a critical piece of logic. It standardizes data from different manufacturers.
* **Dragino Logic:** Looks for `TempC_SHT`, `BatV`.
* **TTN Logic:** Looks for `temperature`, `humidity`, `analog_in`.


* **Calculated Fields:** Automatically calculates **Dew Point** based on temperature and humidity using the Magnus formula.

---

## 6. User Interface (UI) Structure

The UI is built using a responsive layout rooted in `dashboard.dart`.

### 6.1. Navigation & Layout

* **Sidebar (`device_sidebar.dart`):** A collapsible drawer for selecting, adding, and editing devices.
* **Main View:** Switches between **Live View** and **History View**.

### 6.2. Live View Components

* **DeviceCameraRoll (`device_camera_roll.dart`):** A customized `PageView` that allows swiping between devices physically. It mimics iOS/Android camera rolls with a distinct pagination indicator.
* **MetricsDashboard (`metrics_dashboard.dart`):**
* Displays real-time gauges.
* **Visual Alerting:** Shows a red "FIRE RISK DETECTED" banner if CO2 > 1000.
* **Offline Logic:** Gray scales the UI if the last packet received was > 15 minutes ago.
* **MHO Indicator:** Displays Daily Thermal Oscillation (MHO) to warn about thermal stress on art.



### 6.3. History View Components

* **HistoryView (`history_view.dart`):** A list of historical records. It uses a hybrid approach: loads initial data from REST, then listens to a Supabase subscription for live appends.
* **SensorChart (`sensor_chart.dart`):** Uses `fl_chart` to render a line graph of the last 50 temperature readings.

---

## 7. Data Flow & Lifecycle

### 7.1. Startup Sequence (`main.dart`)

1. Initialize Flutter bindings.
2. Check `StorageService` for Supabase credentials.
3. **If configured:** Launch `MqttDashboard`.
4. **If not configured:** Launch `SetupScreen` to prompt user for DB URL/Key.

### 7.2. Real-time Telemetry Flow

1. **Sensor** transmits LoRaWAN packet.
2. **TTN Broker** publishes MQTT message.
3. **App** (`MqttWrapper`) receives message.
4. **MonitoringService** parses JSON  `SensorData`.
5. **MonitoringService** adds data to:
* Local Stream  UI updates (`MetricsDashboard`).
* DatabaseService  Supabase Insert.



---

## 8. Security Considerations

1. **Key Storage:** API Keys (TTN) and Database Anon Keys are never stored in plain text. The app uses `FlutterSecureStorage` which utilizes Keystore (Android) and Keychain (iOS).
2. **Supabase Auth:** The app uses Anonymous Sign-In (`signInAnonymously`) to interact with Supabase RLS (Row Level Security) policies.
3. **TLS:** MQTT connections to The Things Network are secured via TLS on port 8883.

## 9. Future Scalability Notes

* **State Management:** Currently relies heavily on `setState` and `ValueNotifier`. As the app grows, migrating to Riverpod or Bloc would improve testability.
* **Device Provisioning:** Currently manual. QR Code scanning for Device EUI/App Key could be added.
* **Offline Support:** While the app detects offline devices, it does not currently cache outgoing data if the phone itself loses internet connection.