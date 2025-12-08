enum ExpenseCategory {
  food('Food'),
  transport('Transport'),
  accommodation('Accommodation'),
  activity('Activity'),
  other('Other');

  final String displayName;
  const ExpenseCategory(this.displayName);
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'category': category.name,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => ExpenseCategory.other,
        ),
        date: DateTime.parse(json['date'] as String),
      );
}
