// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/destination_details.dart';
import '../models/transport_route.dart';

/// Enhanced Gemini service for comprehensive destination intelligence.
class DestinationIntelligenceService {
  final String apiKey;
  late final GenerativeModel _model;

  DestinationIntelligenceService(this.apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey.trim(),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
      ),
    );
  }

  /// Get comprehensive destination details from Gemini.
  Future<DestinationDetails?> getDestinationDetails(String destination) async {
    try {
      final prompt = '''
Provide comprehensive travel information about: $destination

Return ONLY a valid JSON object (no markdown, no code blocks) with this exact structure:
{
  "name": "$destination",
  "country": "country name",
  "latitude": 0.0,
  "longitude": 0.0,
  "overview": "2-3 sentence overview",
  "history": "Brief historical context (2-3 sentences)",
  "culturalSignificance": "Cultural importance (2-3 sentences)",
  "bestTimeToVisit": "Best months and why",
  "monthlyWeather": {
    "January": "Weather description",
    "February": "Weather description"
  },
  "language": "Primary language",
  "languages": ["Language 1", "Language 2"],
  "currency": "Currency code (e.g., USD)",
  "safetyTips": ["Tip 1", "Tip 2", "Tip 3"],
  "emergencyNumbers": "Police: XXX, Ambulance: XXX, Fire: XXX",
  "visaRequirements": "Brief visa info for tourists",
  "localCustoms": "Key customs and etiquette (3-4 points)",
  "budgetEstimates": {
    "low": 25.0,
    "medium": 50.0,
    "high": 100.0
  },
  "topAttractions": ["Attraction 1", "Attraction 2", "Attraction 3"],
  "hiddenGems": ["Hidden spot 1", "Hidden spot 2"],
  "foodRecommendations": ["Dish 1 (description)", "Dish 2 (description)"],
  "ecoTourismInfo": "Sustainability and eco-tourism notes"
}

IMPORTANT: Return ONLY the JSON object, no extra text.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      // Strip markdown code blocks if present
      var cleanJson = text;
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final json = parseJson(cleanJson);
      if (json == null) return null;

      return DestinationDetails.fromJson(json);
    } catch (e) {
      print('Error fetching destination details: $e');
      return null;
    }
  }

  /// Get transport routes to destination using Gemini's knowledge.
  Future<List<TransportRoute>> getTransportRoutes(
    String from,
    String to,
  ) async {
    try {
      final prompt = '''
Provide realistic transport options from "$from" to "$to".

Return ONLY a valid JSON array (no markdown, no code blocks) with this structure:
[
  {
    "mode": "flight",
    "from": "$from",
    "to": "$to",
    "departurePoint": "Airport/Station name",
    "arrivalPoint": "Airport/Station name",
    "duration": 180,
    "priceRange": "\$200-\$500",
    "provider": "Typical airline/bus company",
    "layovers": ["City if applicable"],
    "notes": "Direct flight or connection info"
  }
]

Include flight, bus, and train options where applicable.
Duration is in minutes.
IMPORTANT: Return ONLY the JSON array, no extra text.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';

      var cleanJson = text;
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final jsonList = parseJsonList(cleanJson);
      if (jsonList == null) return [];

      return jsonList.map((json) => TransportRoute.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching transport routes: $e');
      return [];
    }
  }

  dynamic parseJson(String text) {
    try {
      // Try direct parse first
      return _tryParse(text);
    } catch (e) {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        return _tryParse(jsonMatch.group(0)!);
      }
      return null;
    }
  }

  dynamic parseJsonList(String text) {
    try {
      return _tryParse(text);
    } catch (e) {
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (jsonMatch != null) {
        return _tryParse(jsonMatch.group(0)!);
      }
      return null;
    }
  }

  dynamic _tryParse(String text) {
    // Basic JSON validation and parse
    try {
      // Use a simple JSON parser
      return _simpleJsonParse(text);
    } catch (e) {
      print('JSON parse error: $e');
      return null;
    }
  }

  dynamic _simpleJsonParse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Use dart:convert's JSON decoder
    try {
      return jsonDecode(trimmed);
    } catch (e) {
      print('Failed to parse JSON: $e');
      return null;
    }
  }
}
