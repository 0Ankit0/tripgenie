// ignore_for_file: avoid_print

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/place.dart';
import '../models/search_filters.dart';

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

  Future<List<Place>> searchPlaces(
    String destination, {
    SearchFilters? filters,
  }) async {
    // DEBUG: Print the API key to help the user verify it
    print('DEBUG: Using Gemini API Key: $apiKey');

    final filtersText = _buildFiltersText(filters);

    final prompt = '''
  I am planning a trip to $destination.
  $filtersText
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

  String _buildFiltersText(SearchFilters? filters) {
    if (filters == null) return '';
    final parts = <String>[];
    if (filters.travelStyle != null) {
      parts.add('Travel style: ${filters.travelStyle}.');
    }
    if (filters.budget != null) {
      parts.add('Budget level: ${filters.budget}.');
    }
    if (filters.durationDays != null) {
      parts.add('Trip duration: ${filters.durationDays} days.');
    }
    if (filters.season != null) {
      parts.add('Season: ${filters.season}.');
    }
    if (filters.crowdLevel != null) {
      parts.add('Prefer crowd level: ${filters.crowdLevel}.');
    }
    if (parts.isEmpty) return '';
    return 'Traveler profile: ${parts.join(' ')}';
  }
}
