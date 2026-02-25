class Place {
  final String id;
  final String name;
  final String description;
  final double? latitude;
  final double? longitude;
  final String searchQuery;
  final String? sourceUri;
  String? imageUrl;
  final String? openingHours;
  final String? website;
  final List<String>? reviews;
  final String? rating;

  Place({
    required this.id,
    required this.name,
    required this.description,
    this.latitude,
    this.longitude,
    required this.searchQuery,
    this.sourceUri,
    this.imageUrl,
    this.openingHours,
    this.website,
    this.reviews,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'searchQuery': searchQuery,
        'sourceUri': sourceUri,
        'imageUrl': imageUrl,
        'openingHours': openingHours,
        'website': website,
        'reviews': reviews,
        'rating': rating,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        searchQuery: json['searchQuery'] as String,
        sourceUri: json['sourceUri'] as String?,
        imageUrl: json['imageUrl'] as String?,
        openingHours: json['openingHours'] as String?,
        website: json['website'] as String?,
        reviews: (json['reviews'] as List<dynamic>?)?.cast<String>(),
        rating: json['rating'] as String?,
      );

  String get mapUrl =>
      sourceUri ??
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  String get placeholderImageUrl =>
      'https://placehold.co/600x400/e2e8f0/475569?text=${Uri.encodeComponent(name)}';
}
