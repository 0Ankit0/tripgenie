class TravelPreferences {
  final String? travelStyle; // budget, luxury, adventure, cultural
  final String? preferredSeason;
  final String? budgetLevel; // low, medium, high

  const TravelPreferences({
    this.travelStyle,
    this.preferredSeason,
    this.budgetLevel,
  });

  Map<String, dynamic> toJson() => {
        'travelStyle': travelStyle,
        'preferredSeason': preferredSeason,
        'budgetLevel': budgetLevel,
      };

  factory TravelPreferences.fromJson(Map<String, dynamic> json) =>
      TravelPreferences(
        travelStyle: json['travelStyle'] as String?,
        preferredSeason: json['preferredSeason'] as String?,
        budgetLevel: json['budgetLevel'] as String?,
      );
}
