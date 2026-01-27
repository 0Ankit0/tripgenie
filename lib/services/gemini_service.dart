import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/place.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;
  static const _uuid = Uuid();

  GeminiService(this.apiKey) {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: trimmedKey,
    );
  }

  Future<List<Place>> searchPlaces(String destination) async {
    // DEBUG: Print the API key to help the user verify it
    print('DEBUG: Using Gemini API Key: $apiKey');

    final prompt = '''
I am planning a trip to $destination. 
Please find 5 to 8 specific popular tourist attractions or places to visit in $destination.

For each place, you MUST provide the following details:
1. Name
2. A short description (under 20 words)
3. Approximate Latitude
4. Approximate Longitude
5. Opening Hours (e.g., "9 AM - 5 PM" or "24 hours" or "See website")
6. Official Website URL (or "N/A" if not available)
7. A summary of 3 distinct user reviews (separated by semicolons, e.g. "Great view; Crowded; Expensive")
8. Average Rating (e.g. "4.5" or "N/A")

CRITICAL OUTPUT FORMAT:
Do not use Markdown tables. Use the following custom delimiter format exactly.
Separate fields with "|||" and separate places with "###".

Format:
Name ||| Description ||| Latitude ||| Longitude ||| Opening Hours ||| Website ||| Review 1; Review 2; Review 3 ||| Rating
###
Name ||| Description ||| ...

Example:
Eiffel Tower ||| Iconic iron lady of Paris ||| 48.8584 ||| 2.2945 ||| 9:30 AM - 11:45 PM ||| https://www.toureiffel.paris ||| Amazing views; Long queues; Must see ||| 4.6
###
Louvre Museum ||| ...

Do not include any introductory or concluding text. Just the data block.
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';

    return await _parseCustomFormatToPlaces(text, destination);
  }

  Future<List<Place>> _parseCustomFormatToPlaces(
      String text, String destinationQuery) async {
    final places = <Place>[];
    final rawPlaces = text.split('###');

    for (final rawPlace in rawPlaces) {
      if (rawPlace.trim().isEmpty) continue;

      final fields = rawPlace.split('|||').map((f) => f.trim()).toList();

      if (fields.length >= 8) {
        final name = fields[0];
        final description = fields[1];
        final lat = double.tryParse(fields[2]);
        final lng = double.tryParse(fields[3]);
        final openingHours = fields[4];
        final website = fields[5] == 'N/A' ? null : fields[5];
        final reviews = fields[6]
            .split(';')
            .map((r) => r.trim())
            .where((r) => r.isNotEmpty)
            .toList();
        final rating = fields[7];

        if (name.isNotEmpty && lat != null && lng != null) {
          final place = Place(
            id: _uuid.v4(),
            name: name,
            description: description,
            latitude: lat,
            longitude: lng,
            searchQuery: destinationQuery,
            openingHours: openingHours,
            website: website,
            reviews: reviews.isNotEmpty ? reviews : null,
            rating: rating,
            // Use Wikimedia Commons for real photos
            imageUrl: null, // Initialized as null, updated asynchronously
          );

          places.add(place);
        }
      }
    }

    // Fetch images in parallel before returning
    await Future.wait(places.map((p) => _updatePlaceImage(p)));

    return places;
  }

  Future<void> _updatePlaceImage(Place place) async {
    // Strategies for fetching images:
    // 1. Exact Title Search: Use 'titles' param. Fast if exact match.
    // 2. Wikipedia Search (Name): Use 'generator=search' to find best matching page for name.
    // 3. Wikipedia Search (Name + Destination): Contextual search.
    // 4. Wikipedia Search (Name + Keywords): Try adding 'landmark' or 'tourism'.
    // 5. Wikipedia Search (Destination Only): Fallback to city image.

    final strategies = [
      (useSearch: false, query: place.name), // 1. Title
      (useSearch: true, query: place.name), // 2. Search
      (
        useSearch: true,
        query: '${place.name} ${place.searchQuery}'
      ), // 3. Name + Dest
      (useSearch: true, query: '${place.name} landmark'), // 4. Name + Keyword
      (useSearch: true, query: place.searchQuery), // 5. Dest Only
    ];

    for (var i = 0; i < strategies.length; i++) {
      final strategy = strategies[i];
      try {
        final query = strategy.query;
        final isSearch = strategy.useSearch;

        final Uri url;
        if (isSearch) {
          url = Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent(query)}&gsrlimit=1&prop=pageimages&pithumbsize=500&format=json');
        } else {
          url = Uri.parse(
              'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(query)}&prop=pageimages&pithumbsize=500&format=json');
        }

        print(
            'DEBUG: Attempt ${i + 1}/5 for ${place.name} using query: "$query"');

        // Wikipedia requires a User-Agent header
        final response = await http.get(url, headers: {
          'User-Agent': 'TripGenie/1.0 (adhik@example.com) based on Flutter',
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final pages = data['query']?['pages'];

          if (pages != null && pages is Map && pages.isNotEmpty) {
            final page = pages.values.first;
            // Check for valid page and image
            if (page != null &&
                page['pageid'] != null &&
                (page['pageid'] as int) > 0) {
              final thumbnail = page['thumbnail'];
              if (thumbnail != null) {
                final source = thumbnail['source'] as String?;
                if (source != null) {
                  place.imageUrl = source;
                  print(
                      'DEBUG: Success! Image found on attempt ${i + 1}: $source');
                  return; // Stop retrying on success
                }
              }
            }
          }
        }
      } catch (e) {
        print('DEBUG: Error on attempt ${i + 1} for ${place.name}: $e');
      }

      // Small delay between retries
      if (i < strategies.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    print(
        'DEBUG: Failed to find image for ${place.name} after ${strategies.length} attempts.');
  }

  Future<String> generateTripItinerary(
    String destination,
    List<Place> places, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final placeNames = places.map((p) => p.name).join(', ');
      final dateContext = startDate != null && endDate != null
          ? 'from $startDate to $endDate'
          : 'for the trip';

      final prompt = '''
I am planning a trip to $destination $dateContext.
I want to visit: $placeNames.

Create a detailed itinerary.
Group by proximity.

Output Rules:
- Use standard Markdown (## for headers, - for lists, ** for bold).
- Do NOT use HTML tags like <strong>, <br>, etc.
- Do NOT use Markdown tables.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Could not generate itinerary.';
    } catch (e) {
      print('Error generating itinerary: $e');
      throw Exception('Failed to generate itinerary');
    }
  }

  Future<String> generateTripTips(
    String destination,
    List<Place> places,
  ) async {
    try {
      final placeNames = places.map((p) => p.name).join(', ');

      final prompt = '''
I am visiting $destination. Places: $placeNames.
Provide a guide on:
1. Packing List
2. Special Rules/Etiquette
3. Dos and Don'ts
4. Travel Tips

Output Rules:
- Use standard Markdown (## for headers, - for lists, ** for bold).
- Do NOT use HTML tags.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Could not generate tips.';
    } catch (e) {
      print('Error generating tips: $e');
      throw Exception('Failed to generate trip tips');
    }
  }

  Future<String> generateWeatherForecast(
    String destination, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final datePrompt = startDate != null && endDate != null
          ? 'daily forecast between $startDate and $endDate'
          : 'typical 5-day forecast for this time of year';

      final prompt = '''
Provide a weather forecast for $destination based on this context: $datePrompt.

Return a JSON array of daily forecasts with the following structure:
[
  {
    "day": "The day of the week or date, e.g., 'Mon', 'Oct 25', or '2024-10-25'",
    "temperature": "Temperature formatted as 'High° / Low°' (e.g. 24°C / 18°C)",
    "condition": "Short weather condition (e.g. Sunny, Cloudy, Rainy, Snow)",
    "icon": "A keyword for the icon: 'sun', 'cloud', 'rain', 'snow', 'storm', 'wind'"
  }
]
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '[]';
    } catch (e) {
      print('Error getting weather: $e');
      return '[]';
    }
  }
}
