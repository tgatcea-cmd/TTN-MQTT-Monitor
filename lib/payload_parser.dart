import 'dart:math';
import 'models.dart';

class PayloadParser {
  static SensorData parse(Map<String, dynamic> payload, String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'dragino':
        return _parseDragino(payload);
      case 'ttn':
      default:
        return _parseTTN(payload);
    }
  }

  static SensorData _parseTTN(Map<String, dynamic> payload) {
    final temp = findValue(payload, 'temperature');
    final humidity = findValue(payload, 'humidity');
    final co2 = findValue(payload, 'co2');
    final battery = findValue(payload, 'battery');

    final dew = (temp != null && humidity != null)
        ? _calculateDewPoint(temp, humidity)
        : 0.0;

    return SensorData(
      temperature: temp,
      humidity: humidity,
      co2: co2,
      battery: battery,
      dewPoint: dew,
      timestamp: DateTime.now(),
      deviceType: 'TTN',
    );
  }

  static SensorData _parseDragino(Map<String, dynamic> payload) {
    double? temperature = _getDraginoTemperature(payload);
    double? humidity = findValue(payload, 'Hum_SHT');
    double? battery = findValue(payload, 'BatV');

    final dew = (temperature != null && humidity != null)
        ? _calculateDewPoint(temperature, humidity)
        : 0.0;

    final customFields = <String, dynamic>{
      'door_status': payload['Door_status'] ?? 'N/A',
      'adc_ch0v': findValue(payload, 'ADC_CH0V'),
      'digital_istatus': payload['Digital_IStatus'] ?? 'N/A',
      'exti_trigger': payload['EXTI_Trigger'] ?? 'N/A',
      'work_mode': payload['Work_mode'] ?? 'N/A',
    };

    return SensorData(
      temperature: temperature,
      humidity: humidity,
      co2: null,
      battery: battery,
      dewPoint: dew,
      timestamp: DateTime.now(),
      deviceType: 'Dragino',
      customFields: customFields,
    );
  }

  static double? _getDraginoTemperature(Map<String, dynamic> payload) {
    return findValue(payload, 'TempC_SHT') ?? findValue(payload, 'TempC1');
  }

  static double _calculateDewPoint(double temp, double rh) {
    const b = 17.62;
    const c = 243.12;
    double gamma = (log(rh / 100.0) + ((b * temp) / (c + temp)));
    return (c * gamma) / (b - gamma);
  }
}

double? findValue(Map<String, dynamic> payload, String baseKey) {
  if (payload.containsKey(baseKey)) {
    final val = payload[baseKey];
    return val is num ? val.toDouble() : double.tryParse(val.toString());
  }

  for (var key in payload.keys) {
    if (key.toLowerCase().startsWith(baseKey.toLowerCase())) {
      final val = payload[key];
      return val is num ? val.toDouble() : double.tryParse(val.toString());
    }
  }

  return null;
}
