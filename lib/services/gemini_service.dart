import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/place.dart';

class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;
  static const _uuid = Uuid();

  GeminiService(this.apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  Future<List<Place>> searchPlaces(String destination) async {
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

    return _parseCustomFormatToPlaces(text, destination);
  }

  List<Place> _parseCustomFormatToPlaces(String text, String destinationQuery) {
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
          places.add(Place(
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
            imageUrl:
                'https://placehold.co/600x400/e2e8f0/475569?text=${Uri.encodeComponent(name)}',
          ));
        }
      }
    }

    return places;
  }
}
