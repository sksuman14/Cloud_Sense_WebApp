import 'package:flutter/material.dart';
import 'package:cloud_sense_webapp/src/utils/api_keys.dart';

class DeviceParameter {
  final String key;
  final String displayName;
  final String unit;
  final bool isSpecial; // For wind, air quality, etc.
  final bool isMetadata; // For Longitude, Latitude, Firmware, etc.

  DeviceParameter({
    required this.key,
    required this.displayName,
    required this.unit,
    this.isSpecial = false,
    this.isMetadata = false,
  });
}

class DeviceTypeConfig {
  final String prefix;
  final List<DeviceParameter> parameters;
  final String? apiTemplate; // Template for standard range
  final String? historyApiTemplate; // Template for 7-day range if different
  final String? monthHistoryApiTemplate; // Template for 30-day range
  final bool hasWind;
  final bool hasRainfall;
  final bool hasAirQuality;
  final bool hasWeatherForecasting;

  DeviceTypeConfig({
    required this.prefix,
    required this.parameters,
    this.apiTemplate,
    this.historyApiTemplate,
    this.monthHistoryApiTemplate,
    this.hasWind = false,
    this.hasRainfall = false,
    this.hasAirQuality = false,
    this.hasWeatherForecasting = false,
  });
}

class DeviceConfig {
  static final Map<String, DeviceTypeConfig> _configs = {
    'WQ': DeviceTypeConfig(
      prefix: 'WQ',
      apiTemplate:
          'https://oy7qhc1me7.execute-api.us-west-2.amazonaws.com/default/k_wqm_api?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      parameters: [
        DeviceParameter(key: 'temp', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(key: 'TDS', displayName: 'TDS', unit: 'ppm'),
        DeviceParameter(key: 'COD', displayName: 'COD', unit: 'mg/L'),
        DeviceParameter(key: 'BOD', displayName: 'BOD', unit: 'mg/L'),
        DeviceParameter(key: 'pH', displayName: 'pH', unit: ''),
        DeviceParameter(key: 'DO', displayName: 'DO', unit: 'mg/L'),
        DeviceParameter(key: 'EC', displayName: 'EC', unit: 'mS/cm'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'FS': DeviceTypeConfig(
      prefix: 'FS',
      apiTemplate:
          'https://d11aiifadm1oq5.cloudfront.net/default/SSMet_Forest_API_func?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'Radiation', displayName: 'Radiation', unit: 'W/m²'),
        DeviceParameter(
            key: 'RainfallDaily', displayName: 'Rain Level', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SS': DeviceTypeConfig(
      prefix: 'SS',
      apiTemplate:
          'https://yebtmt03od.execute-api.us-east-1.amazonaws.com/default/SSMet_Soil_Api_Func?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_Soil/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'Nitrogen', displayName: 'Nitrogen', unit: 'mg/kg'),
        DeviceParameter(
            key: 'Phosphorus', displayName: 'Phosphorus', unit: 'mg/kg'),
        DeviceParameter(
            key: 'ElectricalConductivity',
            displayName: 'Electrical Conductivity',
            unit: 'µS/cm'),
        DeviceParameter(
            key: 'Potassium', displayName: 'Potassium', unit: 'mg/kg'),
        DeviceParameter(key: 'pH', displayName: 'pH', unit: ''),
        DeviceParameter(key: 'Salinity', displayName: 'Salinity', unit: 'mg/L'),
        DeviceParameter(
            key: 'Layer1_15cm', displayName: 'Layer 1 (15cm)', unit: '%'),
        DeviceParameter(
            key: 'Layer2_30cm', displayName: 'Layer 2 (30cm)', unit: '%'),
        DeviceParameter(
            key: 'Layer3_45cm', displayName: 'Layer 3 (45cm)', unit: '%'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SI': DeviceTypeConfig(
      prefix: 'SI',
      apiTemplate:
          'https://wr8ort42hi.execute-api.us-east-1.amazonaws.com/default/SSMet_Custom_API_func?deviceid={strDeviceId}&startdate={startdate}&enddate={enddate}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=SSMet_custom_1225&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/SSMet/custom/1225/C0/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'AirTemperature', displayName: 'Air Temperature', unit: '°C'),
        DeviceParameter(
            key: 'SoilTemperature',
            displayName: 'Soil Temperature',
            unit: '°C'),
        DeviceParameter(
            key: 'AirHumidity', displayName: 'Air Humidity', unit: '%'),
        DeviceParameter(
            key: 'SoilHumidity', displayName: 'Soil Humidity', unit: '%'),
        DeviceParameter(
            key: 'Nitrogen', displayName: 'Nitrogen', unit: 'mg/kg'),
        DeviceParameter(
            key: 'Phosphorus', displayName: 'Phosphorus', unit: 'mg/kg'),
        DeviceParameter(
            key: 'Potassium', displayName: 'Potassium', unit: 'mg/kg'),
        DeviceParameter(key: 'pH', displayName: 'pH', unit: ''),
        DeviceParameter(key: 'Salinity', displayName: 'Salinity', unit: 'mg/L'),
        DeviceParameter(
            key: 'Radiation', displayName: 'Radiation', unit: 'W/m²'),
        DeviceParameter(
            key: 'ElectricalConductivity',
            displayName: 'Electrical Conductivity',
            unit: 'µS/cm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'RainfallMinutly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'CB': DeviceTypeConfig(
      prefix: 'CB',
      apiTemplate:
          'https://a9z5vrfpkd.execute-api.us-east-1.amazonaws.com/default/CloudSense_BOD_COD_Api_func?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      parameters: [
        DeviceParameter(key: 'temp', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(key: 'COD', displayName: 'COD', unit: 'mg/L'),
        DeviceParameter(key: 'BOD', displayName: 'BOD', unit: 'mg/L'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'NH': DeviceTypeConfig(
      prefix: 'NH',
      apiTemplate:
          'https://qgbwurafri.execute-api.us-east-1.amazonaws.com/default/CloudSense_NH_Data_Api_function?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      parameters: [
        DeviceParameter(key: 'AMMONIA', displayName: 'Ammonia', unit: 'PPM'),
        DeviceParameter(key: 'TEMP', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(key: 'HUMIDITY', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'DO': DeviceTypeConfig(
      prefix: 'DO',
      apiTemplate:
          'https://br2s08as9f.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_2_function?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      parameters: [
        DeviceParameter(
            key: 'Temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(key: 'DO Value', displayName: 'DO Value', unit: 'mg/L'),
        DeviceParameter(
            key: 'DO Percentage', displayName: 'DO Percentage', unit: '%'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'NA': DeviceTypeConfig(
      prefix: 'NA',
      apiTemplate:
          'https://d3g5fo66jwc4iw.cloudfront.net/ssmetnarldata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_NARL/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'RainfallDaily', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'PC': DeviceTypeConfig(
      prefix: 'PC',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/polytechnicdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_Polytechnic/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),

    'GP': DeviceTypeConfig(
      prefix: 'GP',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/gcpdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),

    'WT': DeviceTypeConfig(
      prefix: 'WT',
      apiTemplate:
          'https://p3jativhq1.execute-api.us-east-1.amazonaws.com/default/Weather_Sensor_Api_Function?DeviceId={deviceId}&start_date={startdate}&end_date={enddate}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'BME680_Temp', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'BME680_Humidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'BME680_Pressure', displayName: 'Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'Lux', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(key: 'Rain', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'VD': DeviceTypeConfig(
      prefix: 'VD',
      apiTemplate:
          'https://d3g5fo66jwc4iw.cloudfront.net/vanixdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourlyComulative',
            displayName: 'Rainfall',
            unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'CP': DeviceTypeConfig(
      prefix: 'CP',
      apiTemplate:
          'https://d3g5fo66jwc4iw.cloudfront.net/campusdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_Campus&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_Campus/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      hasAirQuality: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(key: 'SEN66_PM1', displayName: 'PM1.0', unit: 'µg/m³'),
        DeviceParameter(key: 'SEN66_PM25', displayName: 'PM2.5', unit: 'µg/m³'),
        DeviceParameter(key: 'SEN66_PM4', displayName: 'PM4', unit: 'µg/m³'),
        DeviceParameter(key: 'SEN66_PM10', displayName: 'PM10', unit: 'µg/m³'),
        DeviceParameter(key: 'SEN66_CO2', displayName: 'CO₂', unit: 'ppm'),
        DeviceParameter(key: 'SEN66_VOC', displayName: 'VOC', unit: ''),
        DeviceParameter(key: 'SEN66_NOx', displayName: 'NOx', unit: ''),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SV': DeviceTypeConfig(
      prefix: 'SV',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/svpudata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourlyComulative',
            displayName: 'Rainfall',
            unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'IT': DeviceTypeConfig(
      prefix: 'IT',
      apiTemplate:
          'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceId={deviceId}&startdate={startdate}&enddate={enddate}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/Awadh_IIT_B/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'RainfallDaily', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'Visibility', displayName: 'Visibility', unit: 'm'),
        DeviceParameter(
            key: 'Radiation', displayName: 'Radiation', unit: 'W/m²'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'DM': DeviceTypeConfig(
      prefix: 'DM',
      apiTemplate:
          'https://defj3npj8k.execute-api.us-east-1.amazonaws.com/default/Demo_Device_API_Function?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'CF': DeviceTypeConfig(
      prefix: 'CF',
      apiTemplate:
          'https://d3g5fo66jwc4iw.cloudfront.net/colonelfarmdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_Campus&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_Campus/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SW': DeviceTypeConfig(
      prefix: 'SW',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_SSMET_1225&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMET_1225/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      hasWeatherForecasting: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'WJ': DeviceTypeConfig(
      prefix: 'WJ',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0126data?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_SSMet_0126&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_0126/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'WF': DeviceTypeConfig(
      prefix: 'WF',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0226data?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_SSMet_0226&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_0226/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'WA': DeviceTypeConfig(
      prefix: 'WA',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/annam0426data?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_Annam_0426&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_Annam_0426/{deviceId}/{year}/{monthAbbr}.json',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
        DeviceParameter(
            key: 'SunshineHours', displayName: 'Sunshine Hours', unit: 'Hrs'),
        DeviceParameter(key: 'PAR', displayName: 'PAR', unit: 'µmol/m²/s'),
        DeviceParameter(
            key: 'UVRadiation', displayName: 'UV Radiation', unit: 'W/m²'),
        DeviceParameter(
            key: 'SolarRadiation',
            displayName: 'Solar Radiation',
            unit: 'W/m²'),
      ],
    ),
    'WM': DeviceTypeConfig(
      prefix: 'WM',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/annam0526data?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_Annam_0526&DeviceId={deviceId}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall Hourly', unit: 'mm'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    // ── WN: Winds Weather Sensors (Winds_WS_Data_API) ──
    'WN': DeviceTypeConfig(
      prefix: 'WN',
      apiTemplate:
          'https://dwqomhli00.execute-api.us-east-1.amazonaws.com/default/Winds_WS_Data_API?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentRelativeHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(key: 'Rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'CurrentWindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'CurrentWindDirection',
            displayName: 'Wind Direction',
            unit: '°'),
        DeviceParameter(
            key: 'MaximumWindGustSpeed',
            displayName: 'Max Wind Gust',
            unit: 'm/s'),
        DeviceParameter(
            key: 'MaxWindGustTime',
            displayName: 'Max Gust Time',
            unit: '',
            isMetadata: true),
        DeviceParameter(
            key: 'SquallWindSpeed',
            displayName: 'Squall Wind Speed',
            unit: 'm/s',
            isMetadata: true),
        DeviceParameter(
            key: 'SquallWindDirection',
            displayName: 'Squall Wind Direction',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'SquallWindTime',
            displayName: 'Squall Wind Time',
            unit: '',
            isMetadata: true),
        DeviceParameter(
            key: 'DailyMaximumTemperature',
            displayName: 'Daily Max Temp',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'DailyMinimumTemperature',
            displayName: 'Daily Min Temp',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'PanelVoltage',
            displayName: 'Panel Voltage',
            unit: 'V',
            isMetadata: true),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    // ── JW: JIO WINDS Logger Devices ──
    'JW': DeviceTypeConfig(
      prefix: 'JW',
      apiTemplate:
          'https://0tolwzsmde.execute-api.us-east-1.amazonaws.com/default/WS_Winds_Jio_Logger_API?annam_id={deviceId}&startdate={startdate}&enddate={enddate}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'now_temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'now_relative_humidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(key: 'rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'now_wind_speed', displayName: 'Wind Speed', unit: 'knots'),
        DeviceParameter(
            key: 'now_wind_direction',
            displayName: 'Wind Direction',
            unit: '°'),
        DeviceParameter(
            key: 'max_wind_gust', displayName: 'Max Wind Gust', unit: 'knots'),
        DeviceParameter(
            key: 'Squall_wind_speed',
            displayName: 'Squall Wind Speed',
            unit: 'knots',
            isMetadata: true),
        DeviceParameter(
            key: 'Squall_wind_direction',
            displayName: 'Squall Wind Direction',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'daily_maximum_temperature',
            displayName: 'Daily Max Temp',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'daily_minimum_temperature',
            displayName: 'Daily Min Temp',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'Panel_Voltage',
            displayName: 'Panel Voltage',
            unit: 'V',
            isMetadata: true),
        DeviceParameter(
            key: 'Battery_Voltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'Signal_Strength',
            displayName: 'Signal Strength',
            unit: 'dBm'),
      ],
    ),
    // ── KR: Kerala Devices ──
    'KR': DeviceTypeConfig(
      prefix: 'KR',
      apiTemplate:
          'https://gj6wsq3214.execute-api.us-east-1.amazonaws.com/default/WS_Kerala_API?ANNAM_ID=WS_{deviceId}&startdate={startdate_yyyy_mm_dd}&enddate={enddate_yyyy_mm_dd}&key=${ApiKeys.annamApiKey}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'now_temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'now_relative_humidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(key: 'rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'now_wind_speed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'now_wind_direction',
            displayName: 'Wind Direction',
            unit: '°'),
        DeviceParameter(
            key: 'max_wind_gust', displayName: 'Max Wind Gust', unit: 'm/s'),
        DeviceParameter(
            key: 'max_wind_direction_gust',
            displayName: 'Max Wind Direction Gust',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'now_light', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'now_pressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'max_wind_gust_time',
            displayName: 'Max Gust Time',
            unit: '',
            isMetadata: true),
        DeviceParameter(
            key: 'Panel_Voltage',
            displayName: 'Panel Voltage',
            unit: 'V',
            isMetadata: true),
        DeviceParameter(
            key: 'Battery_Voltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'Signal_Strength',
            displayName: 'Signal Strength',
            unit: 'dBm'),
      ],
    ),
    // ── AW: AWS Devices ──
    'AW': DeviceTypeConfig(
      prefix: 'AW',
      apiTemplate:
          'https://ag25teqhvi.execute-api.us-east-1.amazonaws.com/default/AWS_Api_Function?ANNAM_ID=AWS_{deviceId}&startdate={startdate_yyyy_mm_dd}&enddate={enddate_yyyy_mm_dd}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'now_temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'now_relative_humidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(key: 'rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'now_wind_speed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'now_wind_direction',
            displayName: 'Wind Direction',
            unit: '°'),
        DeviceParameter(
            key: 'max_wind_gust', displayName: 'Max Wind Gust', unit: 'm/s'),
        DeviceParameter(
            key: 'max_wind_direction_gust',
            displayName: 'Max Wind Direction Gust',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'now_light', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'now_pressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'max_wind_gust_time',
            displayName: 'Max Gust Time',
            unit: '',
            isMetadata: true),
        DeviceParameter(
            key: 'Panel_Voltage',
            displayName: 'Panel Voltage',
            unit: 'V',
            isMetadata: true),
        DeviceParameter(
            key: 'Battery_Voltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'Signal_Strength',
            displayName: 'Signal Strength',
            unit: 'dBm'),
      ],
    ),
    'KJ': DeviceTypeConfig(
      prefix: 'KJ',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kjscedata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_KJSCE/{deviceId}/{year}/{monthAbbr}.json',
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'Potassium', displayName: 'Potassium', unit: 'mg/kg'),
        DeviceParameter(key: 'pH', displayName: 'pH', unit: ''),
        DeviceParameter(
            key: 'Nitrogen', displayName: 'Nitrogen', unit: 'mg/kg'),
        DeviceParameter(key: 'Salinity', displayName: 'Salinity', unit: 'mg/L'),
        DeviceParameter(
            key: 'ElectricalConductivity',
            displayName: 'Electrical Conductivity',
            unit: 'µS/cm'),
        DeviceParameter(
            key: 'Phosphorus', displayName: 'Phosphorus', unit: 'mg/kg'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'MY': DeviceTypeConfig(
      prefix: 'MY',
      apiTemplate:
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/mysurudata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}&key=${ApiKeys.annamApiKey}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SM': DeviceTypeConfig(
      prefix: 'SM',
      apiTemplate:
          'https://n42fiw7l89.execute-api.us-east-1.amazonaws.com/default/SSMet_API_Func?device_id={deviceId}&start_date={startdate}&end_date={enddate}&key=${ApiKeys.annamApiKey}',
      historyApiTemplate:
          'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_SSMet_Railway&DeviceId={deviceId}',
      monthHistoryApiTemplate:
          'https://d2c53xydfx4tqe.cloudfront.net/WS_SSMet_Railway/{deviceId}/{year}/{monthAbbr}.json',
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'RainfallWeekly', displayName: 'Rainfall Weekly', unit: 'mm'),
        DeviceParameter(
            key: 'RainfallWeeklyComulative',
            displayName: 'Rainfall Weekly ',
            unit: 'mm'),
        DeviceParameter(
            key: 'RainfallDaily', displayName: 'Rainfall Daily', unit: 'mm'),
        DeviceParameter(
            key: 'RainfallDailyComulative',
            displayName: 'Rainfall Daily ',
            unit: 'mm'),
        DeviceParameter(
            key: 'RainfallHourly', displayName: 'Rainfall Hourly', unit: 'mm'),
        DeviceParameter(
            key: 'RainfallHourlyComulative',
            displayName: 'Rainfall Hourly ',
            unit: 'mm'),
        DeviceParameter(
            key: 'RainfallMinutly',
            displayName: 'Rainfall Minutely',
            unit: 'mm'),
        DeviceParameter(
            key: 'RainfallMinutlyComulative',
            displayName: 'Rainfall Minutely ',
            unit: 'mm'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'WD': DeviceTypeConfig(
      prefix: 'WD',
      apiTemplate:
          'https://62f4ihe2lf.execute-api.us-east-1.amazonaws.com/CloudSense_Weather_data_api_function?DeviceId={deviceId}&startdate={startdate}&enddate={enddate}',
      hasWind: true,
      hasRainfall: true,
      hasWeatherForecasting: true,
      parameters: [
        DeviceParameter(
            key: 'CurrentTemperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'CurrentHumidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(
            key: 'LightIntensity', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'Radiation', displayName: 'Radiation', unit: 'W/m²'),
        DeviceParameter(
            key: 'AtmPressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'WindSpeed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'WindDirection', displayName: 'Wind Direction', unit: '°'),
        DeviceParameter(
            key: 'BatteryVoltage',
            displayName: 'Battery Percentage',
            unit: '%'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'CL': DeviceTypeConfig(
      prefix: 'CL',
      apiTemplate:
          'https://b0e4z6nczh.execute-api.us-east-1.amazonaws.com/CloudSense_Chloritrone_api_function?deviceid={deviceId}&startdate={startdate}&enddate={enddate}',
      parameters: [
        DeviceParameter(
            key: 'chlorine', displayName: 'Chlorine Level', unit: 'mg/L'),
        DeviceParameter(
            key: 'Temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    '20': DeviceTypeConfig(
      prefix: '20',
      apiTemplate:
          'https://7m6s58n0y1.execute-api.us-east-1.amazonaws.com/default/Rain_Sensor_Api_function?DeviceId={deviceId}&startdate={startdate}&enddate={enddate}',
      hasRainfall: true,
      parameters: [
        DeviceParameter(key: 'Rainfall', displayName: 'Rain Level', unit: 'mm'),
        DeviceParameter(
            key: 'BatteryVoltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'SignalStrength', displayName: 'Signal Strength', unit: 'dBm'),
      ],
    ),
    'SH': DeviceTypeConfig(
      prefix: 'SH',
      apiTemplate:
          'https://bne596pwxi.execute-api.us-east-1.amazonaws.com/default/WS_Shobha_Api?ANNAM_ID=WS_Shobha_{deviceId}&startdate={startdate_yyyy_mm_dd}&enddate={enddate_yyyy_mm_dd}',
      hasRainfall: true,
      parameters: [
        DeviceParameter(key: 'rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'Rainfall_Cumulative',
            displayName: 'Rainfall Cumulative',
            unit: 'mm'),
        DeviceParameter(
            key: 'Battery_Voltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'Signal_Strength',
            displayName: 'Signal Strength',
            unit: 'dBm'),
      ],
    ),
    // ── AT: AWS Testing Devices ──
    'AT': DeviceTypeConfig(
      prefix: 'AT',
      apiTemplate:
          'https://2xdgr2sgud.execute-api.us-east-1.amazonaws.com/default/AWS_Testing_API?ANNAM_ID={deviceId}&startdate={startdate_yyyy_mm_dd}&enddate={enddate_yyyy_mm_dd}',
      hasWind: true,
      hasRainfall: true,
      parameters: [
        DeviceParameter(
            key: 'now_temperature', displayName: 'Temperature', unit: '°C'),
        DeviceParameter(
            key: 'now_relative_humidity', displayName: 'Humidity', unit: '%'),
        DeviceParameter(key: 'rainfall', displayName: 'Rainfall', unit: 'mm'),
        DeviceParameter(
            key: 'now_wind_speed', displayName: 'Wind Speed', unit: 'm/s'),
        DeviceParameter(
            key: 'now_wind_direction',
            displayName: 'Wind Direction',
            unit: '°'),
        DeviceParameter(
            key: 'max_wind_gust', displayName: 'Max Wind Gust', unit: 'm/s'),
        DeviceParameter(
            key: 'max_wind_direction_gust',
            displayName: 'Max Wind Direction Gust',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'average_wind_speed',
            displayName: 'Avg Wind Speed',
            unit: 'm/s',
            isMetadata: true),
        DeviceParameter(
            key: 'average_wind_direction',
            displayName: 'Avg Wind Direction',
            unit: '°',
            isMetadata: true),
        DeviceParameter(
            key: 'now_light', displayName: 'Light Intensity', unit: 'Lux'),
        DeviceParameter(
            key: 'now_pressure', displayName: 'Atm Pressure', unit: 'hPa'),
        DeviceParameter(
            key: 'Maximum_Temperature',
            displayName: 'Max Temperature',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'Minimum_Temperature',
            displayName: 'Min Temperature',
            unit: '°C',
            isMetadata: true),
        DeviceParameter(
            key: 'Maximum_Relative_Humidity',
            displayName: 'Max Humidity',
            unit: '%',
            isMetadata: true),
        DeviceParameter(
            key: 'Minimum_Relative_Humidity',
            displayName: 'Min Humidity',
            unit: '%',
            isMetadata: true),
        DeviceParameter(
            key: 'max_wind_gust_time',
            displayName: 'Max Gust Time',
            unit: '',
            isMetadata: true),
        DeviceParameter(
            key: 'Panel_Voltage',
            displayName: 'Panel Voltage',
            unit: 'V',
            isMetadata: true),
        DeviceParameter(
            key: 'Battery_Voltage', displayName: 'Battery Voltage', unit: 'V'),
        DeviceParameter(
            key: 'Signal_Strength',
            displayName: 'Signal Strength',
            unit: 'dBm'),
      ],
    ),
  };

  static DeviceTypeConfig? getConfig(String deviceName) {
    for (var prefix in _configs.keys) {
      if (deviceName.startsWith(prefix)) {
        return _configs[prefix];
      }
    }
    return null;
  }

  static String getPrefix(String deviceName) {
    for (var prefix in _configs.keys) {
      if (deviceName.startsWith(prefix)) {
        return prefix;
      }
    }
    return '';
  }
}
