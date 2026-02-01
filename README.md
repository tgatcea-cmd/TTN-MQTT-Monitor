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
    ├── theme.dart             # Design System (Colors, Typography)
    ├── screens/               # Full-page views
    └── widgets/               # Reusable components
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

Here is the final section of your Architecture Report, covering the **UI Layer**.

I have structured it to match the style of your previous sections: distinguishing between the **Layout/Container** logic, the **Component** library, and the **Design System**.

<br />
<br />
<br />

# 3. The UI Layer `lib/ui/` [Frontend]

The Frontend is designed to be **purely reactive**. It does not store business state; instead, it listens to the `AppController` and repaints automatically when data changes. The architecture prioritizes responsiveness, adapting seamlessly between Desktop (Sidebar layout) and Mobile (Drawer/AppBar layout).

```text     
lib/
└── ui
    ├── theme.dart                            # The Central Design System
    ├── screens                               # High-Level Layout Containers
    │   └── dashboard_screen.dart             # Binder between the backend and the widget tree
    └── widgets                               # Reusable UI Components
        ├── device_camera_roll.dart           # Swipeable Device View
        ├── history_view.dart                 # Chronological log of received transmissions
        ├── charts                            # Data Visualization
        │   └── sensor_chart.dart             # Visualizes historical trends
        ├── common                            # Shared Layout Elements (Sidebar, Dashboard Grid)
        │   ├── device_sidebar.dart           # The navigation hub
        │   └── metrics_dashboard.dart        # Live view sensors renderer
        └── dialogs                           # Modal Interactions (Forms, Configs)
            ├── database_config_dialog.dart   # Enabler of the project's Cloud ecosystem
            ├── device_config_dialog.dart     # Handles the creation/editing of devices
            ├── export_device_dialog.dart     # UI for the export cryptographic service
            └── import_device_dialog.dart     # UI for the import cryptographic service
```

<br />

## A - High-Level Layout `./screens/`

### `./dashboard_screen.dart`

The main orchestrator of the visual experience. It acts as the "Binder" between the `AppController` and the widget tree.

* **Responsive Logic**: It uses a `LayoutBuilder` to switch strategies based on screen width:
* **Desktop (>896)**: Displays a persistent **Row** layout with `DeviceSidebar` on the left and `MainContent` on the right.
* **Mobile**: Switches to a standard **Scaffold** with an `AppBar` and a hidden `Drawer` for navigation.


* **State Management**: It holds transient UI state (like `_showHistory` toggle or `_selectedDevice`) but delegates all data fetching to the Controller.

<br />

## B - Core Components `./widgets/`

We follow an "Atomic Design" philosophy where widgets are specialized and composable.

### `./device_camera_roll.dart`

* **Role**: Provides a swipeable, paginated view of active devices.
* **UX**: Uses a `PageView` with custom physics (`BouncingScrollPhysics`) and smooth animations (`Curves.easeOutQuart`) to create a premium "Camera Roll" feel when switching between sensors.

### `./history_view.dart` 

* **Role**: Provides a detailed, real-time chronological log of received transmissions. It is the primary component of the "Historical Analysis" tab.
* **Real-time Sync Logic**:
  * Unlike a static view, this widget implements a StreamSubscription directly connected to the DatabaseService.
  * *Duplicate Detection*: When receiving new packets via the stream, it uses a Set of IDs to compare incoming readings with those in memory, ensuring the list is accurate and has no visual jumps.
  * *Memory Management*: To maintain optimal performance on mobile devices, the widget implements a "Rolling Buffer" that limits the view to the last 150 readings, automatically removing older ones.
* **Key Concept**: Acts as a hybrid bridge; it loads initial history from Supabase and then stays "alive" by listening for direct insertions, eliminating the need for the user to manually refresh the screen.

### `./common/metrics_dashboard.dart`

* **Role**: The primary data display. It renders the "Live" view of a sensor.
* **Adaptive Grid**: Automatically switches between **2 columns** (Mobile) and **4 columns** (Desktop) to display metrics like Temperature, Humidity, and CO2.
* **Visual Feedback**:
  * *Alert Banners*: Dynamically inserts "Signal Lost" or "Anomaly" warnings based on the `alarmStatus` map.
  * *Oscillation Index (MHO)*: A dedicated wide-card for displaying the daily thermal stress calculation.

### `./common/device_sidebar.dart`

* **Role**: The navigation hub. It lists all available devices and allows CRUD operations.
* **Status Indicators**: Uses color-coded dots (Emerald for Online, Amber for Alarm, Grey for Offline) to give an at-a-glance system health report.

### `./charts/sensor_chart.dart`

* **Role**: Visualizes historical trends using `fl_chart`.
* **Aesthetics**: Implements a "Floating" look by removing outer borders and using dashed grid lines. It features a gradient fill under the curve to emphasize data volume.

<br />

## C - Interaction Design `./widgets/dialogs/`

Complex user flows are encapsulated in modal dialogs to keep the main screen clean.

* `database_config_dialog.dart`: It is the "Enabler" of the project's Cloud ecosystem. Without a successful configuration, the app remains in SetupScreen mode, blocking access to the dashboard to prevent null pointer errors or authentication failures in data services. The URL and Anon Key data is persisted in the device's encrypted storage, allowing the main() function to initialize the Supabase client during the next startup before building the widget tree.
* `device_config_dialog.dart`: Handles the creation/editing of devices. It includes logic for toggling "Remote Control" capabilities and selecting Battery Modes (Voltage vs Percentage).
* `import_device_dialog.dart` & `export_device_dialog.dart`: These are the frontend interfaces for the cryptographic services, handling password inputs and file picking/saving.

<br />

## D - The Design System `./theme.dart`

The application enforces a strict "Swiss Spa" aesthetic, defined in `AppTheme`.

* **Color Palette (Zinc)**:
  * The app avoids pure black (`#000000`).
  * **Primary**: Zinc 950 (`#18181B`) for high-contrast text.
  * **Surface**: Zinc 50 (`#FAFAFA`) for backgrounds and White (`#FFFFFF`) for cards.
  * **Accents**: Desaturated, professional tones—Teal 600 (Action), Rose 700 (Error), Amber 700 (Warning).


* **Typography**:
  * Font Family: **Inter** (for high legibility on screens).
  * Hierarchy: Uses a scaling system from `DisplayLarge` (32px) down to `LabelSmall` (11px).


* **Shape & Spacing**:
  * **Borders**: Thin, subtle borders (Zinc 200) replace heavy drop shadows.
  * **Grid**: A consistent **4pt spacing grid** (padding/margins are multiples of 4: 8, 12, 16, 24, 32).
