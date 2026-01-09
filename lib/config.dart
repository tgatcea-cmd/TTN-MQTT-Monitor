import 'models.dart';

// --- Configuration ---
final List<TTNProfile> ttnProfiles = [
  TTNProfile(
    name: 'Dragino LSN50 (Outdoor)',
    appId: 'upvdisca-dragino-lsn50-app@ttn',
    broker: 'eu1.cloud.thethings.network',
    defaultDeviceId: 'eui-a84041f471868928',
  ),
  TTNProfile(
    name: 'Milesight EM320 (Indoor)',
    appId: 'upvdisca-mlsght-em320-th-app@ttn',
    broker: 'eu1.cloud.thethings.network',
    defaultDeviceId: '6785d19739180000',
  ),
  TTNProfile(
    name: 'Milesight EM500 (Fire/CO2)',
    appId: 'upvdisca-mlsght-em500-co2-app@ttn',
    broker: 'eu1.cloud.thethings.network',
    defaultDeviceId: '6126e03105036005',
  ),
  TTNProfile(
    name: 'RAK3172 (Critical)',
    appId: 'upvdisca-rakwireless-rak3172-app@ttn',
    broker: 'eu1.cloud.thethings.network',
    canControl: true,
    defaultDeviceId: 'eui-ac1f09fffe17155d',
  ),
];