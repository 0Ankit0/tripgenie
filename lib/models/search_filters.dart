class SearchFilters {
  final String? budget; // low, medium, high
  final int? durationDays;
  final String?
      season; // spring, summer, autumn, winter, monsoon, peak, off-peak
  final String? crowdLevel; // low, medium, high
  final String? travelStyle; // budget, luxury, adventure, cultural

  const SearchFilters({
    this.budget,
    this.durationDays,
    this.season,
    this.crowdLevel,
    this.travelStyle,
  });

  SearchFilters copyWith({
    String? budget,
    int? durationDays,
    String? season,
    String? crowdLevel,
    String? travelStyle,
  }) {
    return SearchFilters(
      budget: budget ?? this.budget,
      durationDays: durationDays ?? this.durationDays,
      season: season ?? this.season,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      travelStyle: travelStyle ?? this.travelStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'budget': budget,
        'durationDays': durationDays,
        'season': season,
        'crowdLevel': crowdLevel,
        'travelStyle': travelStyle,
      };

  factory SearchFilters.fromJson(Map<String, dynamic> json) => SearchFilters(
        budget: json['budget'] as String?,
        durationDays: json['durationDays'] as int?,
        season: json['season'] as String?,
        crowdLevel: json['crowdLevel'] as String?,
        travelStyle: json['travelStyle'] as String?,
      );
}
