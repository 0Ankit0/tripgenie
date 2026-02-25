/// Comprehensive destination data enriched from multiple free sources.
class DestinationDetails {
  final String name;
  final String? country;
  final double? latitude;
  final double? longitude;

  // Overview
  final String? overview;
  final String? history;
  final String? culturalSignificance;

  // Travel Info
  final String? bestTimeToVisit;
  final Map<String, String>? monthlyWeather; // month -> description
  final String? language;
  final String? currency;
  final List<String>? languages;

  // Safety & Practical
  final List<String>? safetyTips;
  final String? emergencyNumbers;
  final String? visaRequirements;
  final String? localCustoms;

  // Budget
  final Map<String, double>? budgetEstimates; // low/medium/high daily budget

  // Categories
  final List<String>? topAttractions;
  final List<String>? hiddenGems;
  final List<String>? foodRecommendations;

  // Weather data (from Open-Meteo)
  final WeatherInfo? currentWeather;
  final List<WeatherForecast>? forecast;

  // Sustainability
  final String? ecoTourismInfo;

  DestinationDetails({
    required this.name,
    this.country,
    this.latitude,
    this.longitude,
    this.overview,
    this.history,
    this.culturalSignificance,
    this.bestTimeToVisit,
    this.monthlyWeather,
    this.language,
    this.currency,
    this.languages,
    this.safetyTips,
    this.emergencyNumbers,
    this.visaRequirements,
    this.localCustoms,
    this.budgetEstimates,
    this.topAttractions,
    this.hiddenGems,
    this.foodRecommendations,
    this.currentWeather,
    this.forecast,
    this.ecoTourismInfo,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'overview': overview,
        'history': history,
        'culturalSignificance': culturalSignificance,
        'bestTimeToVisit': bestTimeToVisit,
        'monthlyWeather': monthlyWeather,
        'language': language,
        'currency': currency,
        'languages': languages,
        'safetyTips': safetyTips,
        'emergencyNumbers': emergencyNumbers,
        'visaRequirements': visaRequirements,
        'localCustoms': localCustoms,
        'budgetEstimates': budgetEstimates,
        'topAttractions': topAttractions,
        'hiddenGems': hiddenGems,
        'foodRecommendations': foodRecommendations,
        'currentWeather': currentWeather?.toJson(),
        'forecast': forecast?.map((f) => f.toJson()).toList(),
        'ecoTourismInfo': ecoTourismInfo,
      };

  factory DestinationDetails.fromJson(Map<String, dynamic> json) =>
      DestinationDetails(
        name: json['name'] as String,
        country: json['country'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        overview: json['overview'] as String?,
        history: json['history'] as String?,
        culturalSignificance: json['culturalSignificance'] as String?,
        bestTimeToVisit: json['bestTimeToVisit'] as String?,
        monthlyWeather: (json['monthlyWeather'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())),
        language: json['language'] as String?,
        currency: json['currency'] as String?,
        languages: (json['languages'] as List<dynamic>?)?.cast<String>(),
        safetyTips: (json['safetyTips'] as List<dynamic>?)?.cast<String>(),
        emergencyNumbers: json['emergencyNumbers'] as String?,
        visaRequirements: json['visaRequirements'] as String?,
        localCustoms: json['localCustoms'] as String?,
        budgetEstimates: (json['budgetEstimates'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
        topAttractions:
            (json['topAttractions'] as List<dynamic>?)?.cast<String>(),
        hiddenGems: (json['hiddenGems'] as List<dynamic>?)?.cast<String>(),
        foodRecommendations:
            (json['foodRecommendations'] as List<dynamic>?)?.cast<String>(),
        currentWeather: json['currentWeather'] != null
            ? WeatherInfo.fromJson(
                json['currentWeather'] as Map<String, dynamic>)
            : null,
        forecast: (json['forecast'] as List<dynamic>?)
            ?.map((f) => WeatherForecast.fromJson(f as Map<String, dynamic>))
            .toList(),
        ecoTourismInfo: json['ecoTourismInfo'] as String?,
      );
}

class WeatherInfo {
  final double temperature;
  final double feelsLike;
  final String condition;
  final int humidity;
  final double windSpeed;
  final DateTime timestamp;

  WeatherInfo({
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'condition': condition,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'timestamp': timestamp.toIso8601String(),
      };

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
        temperature: (json['temperature'] as num).toDouble(),
        feelsLike: (json['feelsLike'] as num).toDouble(),
        condition: json['condition'] as String,
        humidity: json['humidity'] as int,
        windSpeed: (json['windSpeed'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class WeatherForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final String condition;
  final int precipitationChance;

  WeatherForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.condition,
    required this.precipitationChance,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'maxTemp': maxTemp,
        'minTemp': minTemp,
        'condition': condition,
        'precipitationChance': precipitationChance,
      };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        date: DateTime.parse(json['date'] as String),
        maxTemp: (json['maxTemp'] as num).toDouble(),
        minTemp: (json['minTemp'] as num).toDouble(),
        condition: json['condition'] as String,
        precipitationChance: json['precipitationChance'] as int,
      );
}
