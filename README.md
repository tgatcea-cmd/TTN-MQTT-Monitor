# Safe-Art Monitor – Architecture Report

**Safe-Art Monitor** is a Flutter-based IoT application designed to monitor environmental conditions (Temperature, Humidity, CO2) for art preservation. It connects to LoRaWAN devices (via The Things Network) using **MQTT** for real-time data and utilizes **Supabase** for historical persistence and user authentication.

The architecture follows a **Service-Oriented** approach where UI components interact with Singleton services to handle business logic, data persistence, and network communication.

<br />

# 1. High-Level Architecture Design

```
lib/
├── main.dart                  # Entry Point & App Lifecycle
├── boot_service.dart          # App Initialization & Credential Check
├── data/                      # Backend: Logic, Services, & Models
│   ├── models.dart            # Data Definitions (Immutable)
│   └── services/              # The "Engine Room" (MQTT, DB, Crypto)
└── ui/                        # Frontend: Visuals & User Interaction
    ├── screens/               # Full-page views
    ├── widgets/               # Reusable components
    └── theme.dart             # Design System (Colors, Typography)

lib/
└── ui
    ├── screens
    │   └── dashboard_screen.dart
    ├── theme.dart
    └── widgets
        ├── charts
        │   └── sensor_chart.dart
        ├── common
        │   ├── device_sidebar.dart
        │   └── metrics_dashboard.dart
        ├── device_camera_roll.dart
        ├── dialogs
        │   ├── database_config_dialog.dart
        │   ├── device_config_dialog.dart
        │   ├── export_device_dialog.dart
        │   └── import_device_dialog.dart
        └── history_view.dart    
```
<br />

## A - The Entry Point & Bootstrapping

Before the app can show any data, it must establish secure connections. We handle this via a dedicated "Bootstrap" layer.

### lib/main.dart

It does not handle business logic; its only job is to decide which app to launch based on the configuration state.

* **Role**: Initializes Flutter bindings and calls the `BootDatabaseStorageService`.

* **Logic**:
  - If Supabase credentials exist → Launch `DashboardScreen` (The Main App).
  - If credentials are missing → Launch `SetupScreen` (The Config Wizard).

* **Key Concept**: This prevents the main app from ever loading in an invalid state.

### lib/boot_service.dart

This is a specialized service that sits outside the main data layer because it is needed before the dependency injection container (`AppController`) is built.

* **Role**: Securely reads the *Supabase URL* and *Anon Key* from the device's encrypted storage (`FlutterSecureStorage`).

* **Key Concept**: It decouples "App Configuration" from "App Runtime Features."

<br />

## B - The Data Layer `lib/data/`

This folder contains all the logic that makes the application work. It is built to be completely UI-agnostic.

### lib/data/models.dart
Contains the Device and SensorData classes. These are immutable data structures that define the shape of our information.

### lib/data/services/
Contains the heavy machinery and auxiliar components, highlighting:

* `AppController`: The central state manager (Facade Pattern). It connects the UI to the underlying services.

* `MonitoringService`: Manages MQTT connections and raw byte decoding.

* `DatabaseService`: Handles Cloud synchronization (Supabase).

* `SecureStorageService`: Handles AES-GCM encryption for importing/exporting device configs.

<br />

## C - The UI Layer `lib/ui/`

This layer is purely reactive. It listens to data changes and paints pixels.

* `screens/`: High-level pages (e.g., `DashboardScreen`). These are the "Containers" that instantiate the `AppController`.

* `widgets/`: Reusable "Atoms" and "Molecules" (e.g., SensorChart, MetricsDashboard). These are dumb components; they take data in and emit events out.

* `theme.dart`: The Design System. It enforces the "Swiss Spa" aesthetic (Zinc colors, Inter font, 4pt spacing grid) across the entire app.

<br />
<br />
<br />

# 2. The Data Layer `lib/data/` [Backend]

The `./data/` folder is the brain of the application. It operates independently of the UI, meaning it contains purely Dart code without any Flutter Widgets. This separation ensures the business logic is testable, robust, and reusable.

```
lib/
├── data                                      # Backend: Logic, Services, & Models
│   ├── models.dart                           # Data Definitions (Immutable)
│   ├── sensor_repository.dart                # Data Fetching Swapper (for Debugging purposes)
│   └── services                              # The "Engine Room" (MQTT, DB, Crypto)
│       ├── app_controller.dart               # The Entry Point for the UI (or CLI)
│       ├── database_service.dart             # Persists Historical Data to the Cloud
│       ├── device_mapper.dart
│       ├── device_service.dart               # Local CRUD for the Device List
│       ├── mock_data_service.dart
│       ├── monitoring_service.dart           # Manages the Active MQTT Connection Stream
│       ├── mqtt_wrapper.dart
│       ├── real_sensor_service.dart
│       └── secure_storage_service.dart       # Handles the Device Import/Export Cryptography
```

<br />

## A - Data Design `./models.dart`
We use immutable data structures to ensure thread safety and predictable state flow.

### The Device Model
Represents the configuration of a physical IoT sensor.

* **Key Fields**: *deviceEui, appId* (TTN Application), *broker,* and *accessKey.*
* **Logic**: It includes flags like canControl to determine if the UI should show actuator buttons, and batteryMode to interpret voltage vs. percentage.
* **Immutability**: Modifications are done via a .copyWith() method, creating a new instance rather than mutating the old one.

### The SensorData Model
A Normalized representation of incoming telemetry.

* **Purpose**: Regardless of the source (MQTT payload, HTTP fetch, Mock data), all readings are converted into this standard format (temperature, humidity, co2, dewPoint, etc.).
* **Smart Constructor**: `SensorData.fromPayload()` contains the logic to inspect raw JSON and auto-detect field names (e.g., handling TempC_SHT vs temperature), making the system compatible with different hardware vendors (Dragino, Milesight, etc.).

<br />

## B - Architecture Patterns

We employ two primary patterns to keep the code clean and modular:

### The Facade Pattern `./services/app_controller.dart`
It is the entry point for the UI. The UI never speaks to the database or MQTT services directly. It only speaks to the `AppController`. The Controller exposes reactive state: *devices, isLoading, alarmStatus*. It manages Dependency Injection, deciding whether to load the Real services or Mock services.

### The Repository Pattern `./sensor_repository.dart` 
An Abstract Interface that defines the contract for fetching data. It allows us to swap the entire backend engine with a single line of code (e.g., for testing or demo mode).

- **Implementations:**
  - *RealSensorService*: Connects to live MQTT and Supabase.
  - *MockDataService*: Generates fake sine-wave data for demos.

<br />

## C - Service Breakdown `./services/`

This folder contains the specialized "worker" classes. Each service has a single responsibility.

### `./monitoring_service.dart`

* **Responsibility**: Manages the active MQTT connection stream.
* **Key Logic**: Maintains a map of MqttWrapper clients (one per unique App ID).
  * **Decoder Pipeline**: Checks if the Network Server (TTN) already decoded the payload. If not, falls back to a Manual CayenneLPP Decoder, handling binary parsing, Endianness, and custom types like BatV or CO2.
  * **Alarm System**: Compares new timestamps against the last received data to detect "Silence/Offline" anomalies or "High Frequency" spam.

### `./database_service.dart`

* **Responsibility**: Persists historical data to the Cloud (Supabase).
* **Key Logic**:
  * **insertSensorReading**: Saves every incoming MQTT packet to the sensor_readings table.
  * **getDailyStats**: specific SQL query optimization to calculate min/max/avg and MHO (Oscillation Index) on the server side.

### `./secure_storage_service.dart`

* **Responsibility**: Handles the Import/Export cryptography.
* **Encryption**: Uses AES-GCM (256-bit).
* **File Format**: .sam (Safe-Art Monitor).
* **Process**:
  * **Export**: Derives a key from a user password (PBKDF2), encrypts the device JSON configuration (including secrets), and prepends a custom header + Salt + IV.
  * **Import**: Validates the "SAM" magic header, extracts the salt, derives the key, and attempts decryption.

### `./device_service.dart`

* **Responsibility**: Local CRUD (Create, Read, Update, Delete) for the device list.
* **Storage**:
  * Non-sensitive data (Names, EUIs) → SharedPreferences.
  * Sensitive data (API Keys) → FlutterSecureStorage (Encrypted Keystore/Keychain).


<br >

## D - Adapters & Drivers `./services/`

These classes handle the translation between our internal domain objects (*Device, SensorData*) and the outside world (Files, MQTT Protocols, Testing).

### `./device_mapper.dart`

The Translation Layer for our custom file format.

* **Role**: It converts the internal Device object into the specific JSON Schema required for .sam (Safe-Art Monitor) export files.

* **Why it exists**: We don't just dump the raw database row to a file. The Mapper:

  * Adds metadata (version 1.0, export date).
  * *Flattens/Nests Structure*: It groups *controlPort* and *controlPayload* into a nested *control_config* object to keep the file clean.
  * *Security Logic*: conditionally includes or excludes the sensitive *access_key* based on the user's choice during export.

### `./mqtt_wrapper.dart`

The Low-Level Driver. It wraps the generic *mqtt_client* package to provide a simplified interface tailored for The Things Network (TTN).

* **Role**: Manages the raw TCP/IP socket connection to the broker.
* **Key Features**:
  * *Auto-Secure*: Automatically sets the port to 8883 (SSL) for TTN or 1883 for local brokers.
  * *Certificate Handling*: Implements a security context that accepts TTN's self-signed or specific root certificates (vital for avoiding handshake errors on some Android versions).
  * *Stream Exposure*: Exposes a clean `Stream<String>` messages so the *MonitoringService* doesn't need to know how the connection works, only that data is arriving.

### `./mock_data_service.dart`

The Simulator. This is a critical architectural component that implements `SensorRepository` but generates fake data instead of connecting to the internet.

* **Role**: Allows the app to be demonstrated or developed without physical hardware.
* **Simulation Logic**: It uses a sine wave function (`sin(timeOffset)`) to generate "breathing" temperature values, making the charts look alive rather than static.
* **Usage**: It is swapped in by `AppController` when `USE_DEMO_MODE` is set to `true`.

### `./real_sensor_service.dart`

The Production Implementation. This is the concrete class that ties the "Live" and "Historic" data sources together.

* **Role**: It implements the `SensorRepository` interface for the actual production app.
* **The Aggregator**:
  * For Live Data, it delegates to MonitoringService (MQTT).
  * For History, it delegates to DatabaseService (Supabase).
* **Why?**: The `AppController` doesn't want to know about MQTT or SQL. It just asks RealSensorService for data, and this class figures out where to get it.