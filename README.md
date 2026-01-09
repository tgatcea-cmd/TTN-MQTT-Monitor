# mqtt_wrapper

A Flutter wrapper for MQTT connections to The Things Network (TTN).

## Features
- Predefined TTN Connection Profiles (Block-1, Block-2, etc.)
- Connect to TTN MQTT broker
- Subscribe to uplinks and downlinks from all devices
- Send downlinks to devices
- Real-time message display with parsed payloads

## Usage

1. Select a TTN Profile from the dropdown (e.g., Block-1).
2. The credentials will be auto-filled.
3. Tap "Connect" to establish the MQTT connection.
4. Uplink and downlink messages will appear in the list.
5. To send a downlink: Enter Device ID and Payload, then tap "Send Downlink".

## Adding Profiles
Edit the `ttnProfiles` list in `lib/main.dart` to add more profiles with your TTN app details.
