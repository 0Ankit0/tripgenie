class TransportRoute {
  final String mode; // bus, flight, train
  final String from;
  final String to;
  final String? departurePoint;
  final String? arrivalPoint;
  final Duration? duration;
  final String? priceRange;
  final String? provider;
  final List<String>? layovers;
  final String? notes;

  TransportRoute({
    required this.mode,
    required this.from,
    required this.to,
    this.departurePoint,
    this.arrivalPoint,
    this.duration,
    this.priceRange,
    this.provider,
    this.layovers,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'from': from,
        'to': to,
        'departurePoint': departurePoint,
        'arrivalPoint': arrivalPoint,
        'duration': duration?.inMinutes,
        'priceRange': priceRange,
        'provider': provider,
        'layovers': layovers,
        'notes': notes,
      };

  factory TransportRoute.fromJson(Map<String, dynamic> json) => TransportRoute(
        mode: json['mode'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
        departurePoint: json['departurePoint'] as String?,
        arrivalPoint: json['arrivalPoint'] as String?,
        duration: json['duration'] != null
            ? Duration(minutes: json['duration'] as int)
            : null,
        priceRange: json['priceRange'] as String?,
        provider: json['provider'] as String?,
        layovers: (json['layovers'] as List<dynamic>?)?.cast<String>(),
        notes: json['notes'] as String?,
      );
}
