# User Guide - Multi-Device Safe-Art Monitor

## 🚀 Getting Started

### 1. **Adding Your First Device**
```
Menu (≡) → "+ Add Device"
  ├─ Device Name: "Gallery 1"
  ├─ TTN App ID: "safe-art@ttn"
  ├─ MQTT Broker: "eu.cloud.thingnetwork.org"
  ├─ Device EUI: "eui-0000000000000001"
  ├─ API Key: "NNSXS...."
  └─ ✓ Save
```

### 2. **Start Monitoring**
```
Dashboard → "Start Monitoring" (Green button)
   ↓
System connects to ALL configured devices
   ↓
Status: "✅ Monitoring 3 Devices"
```

### 3. **View Device Readings**
```
Camera Roll View:
  ┌─────────────────────────────────┐
  │  [← SWIPE to next device →]     │
  │                                 │
  │  Temperature: 22.5°C            │
  │  Humidity: 65%                  │
  │  CO2: 450 ppm                   │
  │  Dew Point: 13.2°C              │
  │  Battery: 3.5V                  │
  │                                 │
  └─────────────────────────────────┘
  
  Gallery 1 [●] • • [2/3]
```

### 4. **Manage Devices**
```
Menu (≡) → Device List

Gallery 1
├─ ⋯ (menu)
│  ├─ Edit
│  └─ Delete

Gallery 2
├─ ⋯ (menu)
│  ├─ Edit
│  └─ Delete

[+ Add Device]
```

---

## 📊 Dashboard Views

### **Live View** (Default)
- Horizontal camera roll between devices
- Real-time readings per device
- Offline detection (grayscale + warning)
- Fire risk alerts (CO2 > 1000 ppm)
- Stop Alarm button (controllable devices only)

### **History View**
- Last 100 readings from ALL devices
- Timestamp, device name, device EUI
- Mini metrics (temp, humidity, CO2, battery)
- Global monitoring overview

---

## 🔧 Device Configuration

### **Edit Existing Device**
```
Menu (≡) → Long-press device → "Edit"
  ├─ Update name, broker, device EUI, API key
  ├─ Toggle "Can Control" flag for downlink
  └─ ✓ Update
```

### **Delete Device**
```
Menu (≡) → Long-press device → "Delete"
  ├─ Confirm deletion
  └─ ✓ Device removed (data stays in database)
```

---

## 🔐 Security

- **API Keys**: Stored securely in encrypted storage per device
- **Device Metadata**: Stored in local SharedPreferences
- **Database**: All readings persisted locally
- **No Cloud Dependency**: Everything runs offline

---

## 📈 Data Storage

### **Device Configuration**
- Location: `SharedPreferences` (local)
- Format: JSON per device
- API Keys: Encrypted secure storage

### **Sensor Readings**
- Location: SQLite database (local)
- Persists from all devices automatically
- Accessible via "History" view
- Can be exported/analyzed offline

---

## 💡 Tips

1. **Quick Device Switching**: Tap the dot indicators to jump to specific device
2. **Offline Detection**: Devices show grayscale when no data for >16 mins
3. **Fire Alerts**: Red banner appears when CO2 > 1000 ppm
4. **Downlinks**: Only devices with "Can Control" enabled can send stop commands
5. **Global History**: Shows readings from all monitored devices across time

---

## ⚙️ Technical Details

### **Multi-Device Architecture**
- Each device gets its own MQTT client
- Each device has independent readings stored
- Monitoring runs for ALL devices simultaneously
- No per-device start/stop (system-wide control only)

### **Message Routing**
```
MQTT Message → Extract Device EUI → Match to configured device
              ↓
         Parse JSON payload
              ↓
         Extract: temp, humidity, CO2, battery
              ↓
         Update device's current reading
              ↓
         Save to database
              ↓
         UI updates if device is selected
```

### **Offline Threshold**
- Default: 16 minutes (960 seconds)
- Device marked offline if no data received in this time
- Configurable in code: `_offlineThresholdSeconds`

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Could not connect to any devices" | Check all API keys are set and valid |
| Device not receiving data | Verify Device EUI matches TTN config |
| Data not saving to database | Check file system permissions |
| Readings show old data | Manual refresh: Stop → Start monitoring |
| API key not updating | Re-add device with new key, then start monitoring |

---

## 📝 Example Workflow

1. Add "Gallery A" with Device EUI `eui-123...`
2. Add "Gallery B" with Device EUI `eui-456...`
3. Add "Gallery C" with Device EUI `eui-789...`
4. Click "Start Monitoring"
5. Swipe between galleries to see live readings
6. Tap "History" to see all readings over time
7. Edit Gallery B name or settings
8. Continue monitoring - all data persists
9. Stop monitoring when not needed
10. Restart monitoring later - history preserved
