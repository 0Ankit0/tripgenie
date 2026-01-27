import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';
import '../models/expense.dart';
import '../models/trip.dart';

class StorageService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _bookmarksKey = 'bookmarks';
  static const String _expensesKey = 'expenses';
  static const String _tripsKey = 'trips';
  static const String _searchCountKey = 'search_count';
  static const String _lastResetDateKey = 'last_reset_date';

  // Default API key for users without their own key
  static const String defaultApiKey =
      'AIzaSyDpF8K9vX2nJ4mL3pQ7rS1tU5vW6xY8zA0'; // Replace with your actual default API key
  static const int maxDailySearches = 10;

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // API Key - Enhanced with proper trimming and validation
  String? getApiKey() {
    final key = _prefs.getString(_apiKeyKey);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  Future<bool> setApiKey(String key) {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) return Future.value(false);
    return _prefs.setString(_apiKeyKey, trimmedKey);
  }

  Future<bool> clearApiKey() => _prefs.remove(_apiKeyKey);

  bool hasApiKey() {
    final key = _prefs.getString(_apiKeyKey);
    return key != null && key.trim().isNotEmpty;
  }

  // Bookmarks
  List<Place> getBookmarks() {
    final jsonStr = _prefs.getString(_bookmarksKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => Place.fromJson(j as Map<String, dynamic>))
        .toList();
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
    return jsonList
        .map((j) => Expense.fromJson(j as Map<String, dynamic>))
        .toList();
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

  // Trips
  List<Trip> getTrips() {
    final jsonStr = _prefs.getString(_tripsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => Trip.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<bool> saveTrips(List<Trip> trips) {
    final jsonStr = jsonEncode(trips.map((t) => t.toJson()).toList());
    return _prefs.setString(_tripsKey, jsonStr);
  }

  Future<bool> addTrip(Trip trip) async {
    final trips = getTrips();
    trips.insert(0, trip);
    return saveTrips(trips);
  }

  Future<bool> updateTrip(Trip trip) async {
    final trips = getTrips();
    final index = trips.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      trips[index] = trip;
      return saveTrips(trips);
    }
    return false;
  }

  Future<bool> deleteTrip(String tripId) async {
    final trips = getTrips();
    trips.removeWhere((t) => t.id == tripId);
    return saveTrips(trips);
  }

  // Search Count Management
  Future<void> _checkAndResetDailyCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastReset = _prefs.getString(_lastResetDateKey);

    if (lastReset != today) {
      await _prefs.setString(_lastResetDateKey, today);
      await _prefs.setInt(_searchCountKey, 0);
    }
  }

  Future<int> getRemainingSearches() async {
    await _checkAndResetDailyCount();

    // If user has their own API key, return unlimited (-1)
    if (hasApiKey()) {
      return -1;
    }

    final count = _prefs.getInt(_searchCountKey) ?? 0;
    return maxDailySearches - count;
  }

  Future<bool> canMakeSearch() async {
    final remaining = await getRemainingSearches();
    return remaining == -1 || remaining > 0;
  }

  Future<void> incrementSearchCount() async {
    // Don't increment if user has their own API key
    if (hasApiKey()) return;

    await _checkAndResetDailyCount();
    final count = _prefs.getInt(_searchCountKey) ?? 0;
    await _prefs.setInt(_searchCountKey, count + 1);
  }

  String getEffectiveApiKey() {
    final userKey = getApiKey();
    return userKey ?? defaultApiKey;
  }
}
