import 'place.dart';
import 'expense.dart';

class Trip {
  final String id;
  final String name;
  final String destination;
  final String? startDate;
  final String? endDate;
  final List<Place> places;
  final List<Expense> expenses;

  Trip({
    required this.id,
    required this.name,
    required this.destination,
    this.startDate,
    this.endDate,
    required this.places,
    required this.expenses,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'destination': destination,
        'startDate': startDate,
        'endDate': endDate,
        'places': places.map((p) => p.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        name: json['name'] as String,
        destination: json['destination'] as String,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        places: (json['places'] as List<dynamic>?)
                ?.map((p) => Place.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        expenses: (json['expenses'] as List<dynamic>?)
                ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Trip copyWith({
    String? id,
    String? name,
    String? destination,
    String? startDate,
    String? endDate,
    List<Place>? places,
    List<Expense>? expenses,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      places: places ?? this.places,
      expenses: expenses ?? this.expenses,
    );
  }

  double get totalExpenses => expenses.fold(0, (sum, e) => sum + e.amount);
}
