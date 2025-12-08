import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/expense.dart';

class StorageService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _bookmarksKey = 'bookmarks';
  static const String _expensesKey = 'expenses';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // API Key
  String? getApiKey() => _prefs.getString(_apiKeyKey);

  Future<bool> setApiKey(String key) => _prefs.setString(_apiKeyKey, key);

  Future<bool> clearApiKey() => _prefs.remove(_apiKeyKey);

  bool hasApiKey() => _prefs.containsKey(_apiKeyKey) && 
                       (_prefs.getString(_apiKeyKey)?.isNotEmpty ?? false);

  // Bookmarks
  List<Place> getBookmarks() {
    final jsonStr = _prefs.getString(_bookmarksKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Place.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<bool> saveBookmarks(List<Place> bookmarks) {
    final jsonStr = jsonEncode(bookmarks.map((p) => p.toJson()).toList());
    return _prefs.setString(_bookmarksKey, jsonStr);
  }

  Future<bool> addBookmark(Place place) async {
    final bookmarks = getBookmarks();
    if (!bookmarks.any((p) => p.id == place.id)) {
      bookmarks.add(place);
      return saveBookmarks(bookmarks);
    }
    return true;
  }

  Future<bool> removeBookmark(String placeId) async {
    final bookmarks = getBookmarks();
    bookmarks.removeWhere((p) => p.id == placeId);
    return saveBookmarks(bookmarks);
  }

  bool isBookmarked(String placeId) {
    return getBookmarks().any((p) => p.id == placeId);
  }

  // Expenses
  List<Expense> getExpenses() {
    final jsonStr = _prefs.getString(_expensesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((j) => Expense.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<bool> saveExpenses(List<Expense> expenses) {
    final jsonStr = jsonEncode(expenses.map((e) => e.toJson()).toList());
    return _prefs.setString(_expensesKey, jsonStr);
  }

  Future<bool> addExpense(Expense expense) async {
    final expenses = getExpenses();
    expenses.insert(0, expense);
    return saveExpenses(expenses);
  }

  Future<bool> removeExpense(String expenseId) async {
    final expenses = getExpenses();
    expenses.removeWhere((e) => e.id == expenseId);
    return saveExpenses(expenses);
  }
}
