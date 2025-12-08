import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/place.dart';
import '../models/expense.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'planner_screen.dart';
import 'saved_screen.dart';
import 'expenses_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final String apiKey;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.apiKey,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late GeminiService _geminiService;
  late List<Place> _bookmarks;
  late List<Expense> _expenses;
  String? _currentDestination;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(widget.apiKey);
    _bookmarks = widget.storageService.getBookmarks();
    _expenses = widget.storageService.getExpenses();
  }

  Set<String> get _bookmarkedIds => _bookmarks.map((p) => p.id).toSet();

  void _toggleBookmark(Place place) {
    setState(() {
      final index = _bookmarks.indexWhere((p) => p.id == place.id);
      if (index >= 0) {
        _bookmarks.removeAt(index);
        widget.storageService.removeBookmark(place.id);
      } else {
        _bookmarks.add(place);
        widget.storageService.addBookmark(place);
      }
    });
  }

  void _addExpense(String description, double amount, ExpenseCategory category) {
    final expense = Expense(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      category: category,
      date: DateTime.now(),
    );
    setState(() {
      _expenses.insert(0, expense);
    });
    widget.storageService.addExpense(expense);
  }

  void _deleteExpense(String id) {
    setState(() {
      _expenses.removeWhere((e) => e.id == id);
    });
    widget.storageService.removeExpense(id);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Key: ${widget.apiKey.substring(0, 8)}...',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmLogout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear API Key'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear API Key?'),
        content: const Text(
          'This will remove your API key and return to the setup screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.flight_takeoff,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'TripGenie',
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSettingsDialog,
            icon: Icon(Icons.settings, color: Colors.grey.shade600),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PlannerScreen(
            geminiService: _geminiService,
            bookmarkedIds: _bookmarkedIds,
            onToggleBookmark: _toggleBookmark,
          ),
          SavedScreen(
            bookmarks: _bookmarks,
            onToggleBookmark: _toggleBookmark,
          ),
          ExpensesScreen(
            expenses: _expenses,
            onAddExpense: _addExpense,
            onDeleteExpense: _deleteExpense,
            currentDestination: _currentDestination,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.teal.shade700,
          unselectedItemColor: Colors.grey.shade500,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Planner',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.bookmark_border),
                  if (_bookmarks.isNotEmpty)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_bookmarks.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.bookmark),
                  if (_bookmarks.isNotEmpty)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_bookmarks.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Saved',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.credit_card_outlined),
              activeIcon: Icon(Icons.credit_card),
              label: 'Expenses',
            ),
          ],
        ),
      ),
    );
  }
}
