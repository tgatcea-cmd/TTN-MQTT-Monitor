# Safe-Art Monitor – Architecture Report

## 1. Executive Summary

**Safe-Art Monitor** is a Flutter-based IoT application designed to monitor environmental conditions (Temperature, Humidity, CO2) for art preservation. It connects to LoRaWAN devices (via The Things Network) using **MQTT** for real-time data and utilizes **Supabase** for historical persistence and user authentication.

The architecture follows a **Service-Oriented** approach where UI components interact with Singleton services to handle business logic, data persistence, and network communication.

---

## 2. High-Level Architecture Diagram

-UI (Frontend)
  |
  |- theme.dart
  |- SCREENS
  |- WIDGETS

-DATA (Backend)
  |
  |- models.dart
  |- sensor_repository.dart
  |- SERVICES

-main.dart
-services.dart

---

## 3. Tech Stack & Dependencies


---

## 4. Core Modules & Services

The logic is encapsulated in the `lib/data/services` directory.

---

## 5. Data Models (`lib/data/models.dart`)

The application uses two primary data models which handle the normalization of incoming data.

### 5.1. Device

### 5.2. SensorData

---

## 6. User Interface (UI) Structure

---

## 7. Data Flow & Lifecycle

---

## 8. Security Considerations

1. **Key Storage:** API Keys (TTN) and Database Anon Keys are never stored in plain text. The app uses `FlutterSecureStorage` which utilizes Keystore (Android) and Keychain (iOS).
2. **Supabase Auth:** The app uses Anonymous Sign-In (`signInAnonymously`) to interact with Supabase RLS (Row Level Security) policies.
3. **TLS:** MQTT connections to The Things Network are secured via TLS on port 8883.