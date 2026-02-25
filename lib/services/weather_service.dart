// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/destination_details.dart';

/// Free weather service using Open-Meteo API (no key required).
/// https://open-meteo.com/
class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1';

  Future<WeatherInfo?> getCurrentWeather(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code'
        '&timezone=auto',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final current = data['current'];

      return WeatherInfo(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        condition: _weatherCodeToCondition(current['weather_code'] as int),
        humidity: current['relative_humidity_2m'] as int,
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        timestamp: DateTime.parse(current['time'] as String),
      );
    } catch (e) {
      print('Error fetching current weather: $e');
      return null;
    }
  }

  Future<List<WeatherForecast>> getWeatherForecast(
    double latitude,
    double longitude, {
    int days = 7,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?latitude=$latitude&longitude=$longitude'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
        '&timezone=auto&forecast_days=$days',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final daily = data['daily'];

      final forecasts = <WeatherForecast>[];
      final times = daily['time'] as List<dynamic>;

      for (var i = 0; i < times.length; i++) {
        forecasts.add(WeatherForecast(
          date: DateTime.parse(times[i] as String),
          maxTemp: (daily['temperature_2m_max'][i] as num).toDouble(),
          minTemp: (daily['temperature_2m_min'][i] as num).toDouble(),
          condition: _weatherCodeToCondition(daily['weather_code'][i] as int),
          precipitationChance:
              (daily['precipitation_probability_max'][i] as num?)?.toInt() ?? 0,
        ));
      }

      return forecasts;
    } catch (e) {
      print('Error fetching weather forecast: $e');
      return [];
    }
  }

  String _weatherCodeToCondition(int code) {
    // WMO Weather interpretation codes
    // https://open-meteo.com/en/docs
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rainy';
    if (code <= 77) return 'Snowy';
    if (code <= 82) return 'Showers';
    if (code <= 86) return 'Snow Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}
