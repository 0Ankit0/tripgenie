import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';

class ExpenseChart extends StatelessWidget {
  final List<Expense> expenses;

  const ExpenseChart({super.key, required this.expenses});

  static const List<Color> _colors = [
    Color(0xFF0088FE),
    Color(0xFF00C49F),
    Color(0xFFFFBB28),
    Color(0xFFFF8042),
    Color(0xFF8884D8),
  ];

  @override
  Widget build(BuildContext context) {
    final categoryTotals = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    if (categoryTotals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Add expenses to see the breakdown',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final legends = <Widget>[];
    var index = 0;

    categoryTotals.forEach((category, amount) {
      final color = _colors[index % _colors.length];
      sections.add(
        PieChartSectionData(
          value: amount,
          title: '\$${amount.toStringAsFixed(0)}',
          color: color,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legends.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.displayName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
      index++;
    });

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...legends,
      ],
    );
  }
}
