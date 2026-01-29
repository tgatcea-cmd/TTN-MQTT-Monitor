# Safe-Art Monitor – Architecture Report

## Executive Summary

**Safe-Art Monitor** is a Flutter-based IoT application designed to monitor environmental conditions (Temperature, Humidity, CO2) for art preservation. It connects to LoRaWAN devices (via The Things Network) using **MQTT** for real-time data and utilizes **Supabase** for historical persistence and user authentication.

The architecture follows a **Service-Oriented** approach where UI components interact with Singleton services to handle business logic, data persistence, and network communication.


# High-Level Architecture Diagram

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
```


## 1. The Entry Point & Bootstrapping

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



## 2. The Data Layer (lib/data/)

This folder contains all the logic that makes the application work. It is built to be completely UI-agnostic.

### lib/data/models.dart
Contains the Device and SensorData classes. These are immutable data structures that define the shape of our information.

### lib/data/services/
Contains the heavy machinery:

* `AppController`: The central state manager (Facade Pattern). It connects the UI to the underlying services.

* `MonitoringService`: Manages MQTT connections and raw byte decoding.

* `DatabaseService`: Handles Cloud synchronization (Supabase).

* `SecureStorageService`: Handles AES-GCM encryption for importing/exporting device configs.

## 3. The UI Layer (lib/ui/)

This layer is purely reactive. It listens to data changes and paints pixels.

* `screens/`: High-level pages (e.g., `DashboardScreen`). These are the "Containers" that instantiate the `AppController`.

* `widgets/`: Reusable "Atoms" and "Molecules" (e.g., SensorChart, MetricsDashboard). These are dumb components; they take data in and emit events out.

* `theme.dart`: The Design System. It enforces the "Swiss Spa" aesthetic (Zinc colors, Inter font, 4pt spacing grid) across the entire app.