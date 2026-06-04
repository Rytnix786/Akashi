/// WeatherProvider — OpenWeatherMap API
library;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';

class WeatherData {
  final double tempC;
  final double humidity;
  final double windKmh;
  final double rainChance; // 0-100
  final String condition;
  final String conditionIcon; // Material Symbol name
  final List<DayForecast> forecast;

  const WeatherData({
    required this.tempC,
    required this.humidity,
    required this.windKmh,
    required this.rainChance,
    required this.condition,
    required this.conditionIcon,
    required this.forecast,
  });
}

class DayForecast {
  final String dayName; // Bengali day name
  final double maxTempC;
  final double minTempC;
  final double rainChance;
  final String icon;

  const DayForecast({
    required this.dayName,
    required this.maxTempC,
    required this.minTempC,
    required this.rainChance,
    required this.icon,
  });
}

class WeatherProvider extends ChangeNotifier {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  WeatherData? _weather;
  bool _isLoading = false;
  String? _error;

  WeatherData? get weather => _weather;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True if rain > 70% in next 3 days (triggers Bengali advisory)
  bool get highRainWarning {
    if (_weather == null) return false;
    final next3 = _weather!.forecast.take(3);
    return next3.any((d) => d.rainChance > 70);
  }

  Future<void> loadWeather({
    double lat = AppConfig.bangladeshLat,
    double lon = AppConfig.bangladeshLon,
    String? accessToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = accessToken ?? "mock_jwt_token_demo";
      final response = await _dio.get(
        '${AppConfig.apiBaseUrl}/weather/$lat/$lon',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _weather = _parseBackendWeatherResponse(response.data);
    } catch (e) {
      _error = e.toString();
      _weather = _mockWeatherData(); // Fallback to mock on error
      debugPrint('WeatherProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  WeatherData _parseBackendWeatherResponse(Map<String, dynamic> data) {
    final current = data['current'] as Map<String, dynamic>;
    final forecastList = data['forecast'] as List;

    final forecasts = forecastList.map((item) {
      final dayForecast = item as Map<String, dynamic>;
      return DayForecast(
        dayName: dayForecast['day_name'] as String,
        maxTempC: (dayForecast['temp_max'] as num).toDouble(),
        minTempC: (dayForecast['temp_min'] as num).toDouble(),
        rainChance: (dayForecast['rain_probability'] as num).toDouble(),
        icon: _weatherIcon(dayForecast['condition_icon'] as String),
      );
    }).toList();

    return WeatherData(
      tempC: (current['temp'] as num).toDouble(),
      humidity: (current['humidity'] as num).toDouble(),
      windKmh: (current['wind_speed'] as num).toDouble() * 3.6,
      rainChance: forecasts.isNotEmpty ? forecasts.first.rainChance : 0.0,
      condition: current['condition_bn'] as String,
      conditionIcon: _weatherIcon(current['condition_icon'] as String),
      forecast: forecasts,
    );
  }

  WeatherData _parseWeatherResponse(Map<String, dynamic> data) {
    final list = data['list'] as List;
    final current = list[0] as Map<String, dynamic>;
    final main = current['main'] as Map<String, dynamic>;
    final weather = (current['weather'] as List)[0] as Map<String, dynamic>;
    final wind = current['wind'] as Map<String, dynamic>? ?? {};
    final rain = current['pop'] as double? ?? 0;

    // Build 7-day forecast from 3-hourly data
    final Map<String, List<Map<String, dynamic>>> byDay = {};
    for (final item in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (item['dt'] as int) * 1000);
      final key = '${dt.year}-${dt.month}-${dt.day}';
      byDay.putIfAbsent(key, () => []).add(item as Map<String, dynamic>);
    }

    final forecasts = byDay.entries.take(7).map((entry) {
      final dayItems = entry.value;
      final temps = dayItems.map((i) => (i['main']['temp'] as num).toDouble());
      final maxPop = dayItems
          .map((i) => (i['pop'] as num).toDouble())
          .reduce((a, b) => a > b ? a : b);
      final dayDt = DateTime.fromMillisecondsSinceEpoch(
          (dayItems[0]['dt'] as int) * 1000);
      final icon = (dayItems[0]['weather'] as List)[0]['main'] as String;

      return DayForecast(
        dayName: _bengaliDay(dayDt.weekday),
        maxTempC: temps.reduce((a, b) => a > b ? a : b),
        minTempC: temps.reduce((a, b) => a < b ? a : b),
        rainChance: (maxPop * 100),
        icon: _weatherIcon(icon),
      );
    }).toList();

    return WeatherData(
      tempC: (main['temp'] as num).toDouble(),
      humidity: (main['humidity'] as num).toDouble(),
      windKmh: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
      rainChance: (rain * 100),
      condition: weather['main'] as String,
      conditionIcon: _weatherIcon(weather['main'] as String),
      forecast: forecasts,
    );
  }

  String _bengaliDay(int weekday) {
    const days = ['', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
    return days[weekday];
  }

  String _weatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'sunny';
      case 'clouds':
        return 'partly_cloudy_day';
      case 'rain':
      case 'drizzle':
        return 'rainy';
      case 'thunderstorm':
        return 'thunderstorm';
      case 'snow':
        return 'weather_snowy';
      default:
        return 'cloud';
    }
  }

  WeatherData _mockWeatherData() {
    return WeatherData(
      tempC: 30,
      humidity: 65,
      windKmh: 12,
      rainChance: 10,
      condition: 'Partly Cloudy',
      conditionIcon: 'partly_cloudy_day',
      forecast: const [
        DayForecast(dayName: 'আজ', maxTempC: 30, minTempC: 24, rainChance: 10, icon: 'sunny'),
        DayForecast(dayName: 'সোম', maxTempC: 31, minTempC: 25, rainChance: 20, icon: 'partly_cloudy_day'),
        DayForecast(dayName: 'মঙ্গল', maxTempC: 28, minTempC: 23, rainChance: 60, icon: 'rainy'),
        DayForecast(dayName: 'বুধ', maxTempC: 26, minTempC: 22, rainChance: 80, icon: 'rainy'),
        DayForecast(dayName: 'বৃহ', maxTempC: 32, minTempC: 26, rainChance: 5, icon: 'sunny'),
        DayForecast(dayName: 'শুক্র', maxTempC: 33, minTempC: 27, rainChance: 5, icon: 'sunny'),
        DayForecast(dayName: 'শনি', maxTempC: 29, minTempC: 24, rainChance: 30, icon: 'partly_cloudy_day'),
      ],
    );
  }
}
