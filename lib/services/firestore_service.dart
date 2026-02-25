import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_paths.dart';
import '../models/expense.dart';
import '../models/place.dart';
import '../models/trip.dart';

/// Centralized Firestore access for all per-user data. Firestore provides
/// offline persistence by default, giving us sync when connectivity returns.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Bookmark operations ----------------------------------------------------
  CollectionReference<Map<String, dynamic>> _bookmarks(String uid) => _firestore
      .collection(FirebasePaths.users)
      .doc(uid)
      .collection(FirebasePaths.bookmarks);

  Stream<List<Place>> streamBookmarks(String uid) {
    return _bookmarks(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Place.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  Future<void> upsertBookmark(String uid, Place place) {
    final payload = place.toJson();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    return _bookmarks(uid).doc(place.id).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteBookmark(String uid, String placeId) {
    return _bookmarks(uid).doc(placeId).delete();
  }

  /// Trip operations --------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _trips(String uid) => _firestore
      .collection(FirebasePaths.users)
      .doc(uid)
      .collection(FirebasePaths.trips);

  Stream<List<Trip>> streamTrips(String uid) {
    return _trips(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Trip.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  Future<void> upsertTrip(String uid, Trip trip) {
    final payload = trip.toJson();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    return _trips(uid).doc(trip.id).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteTrip(String uid, String tripId) {
    return _trips(uid).doc(tripId).delete();
  }

  /// Expense operations (per-trip subcollection for better concurrency) -----
  CollectionReference<Map<String, dynamic>> _expenses(
    String uid,
    String tripId,
  ) {
    return _trips(uid).doc(tripId).collection(FirebasePaths.expenses);
  }

  Stream<List<Expense>> streamExpenses(String uid, String tripId) {
    return _expenses(uid, tripId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  Future<void> upsertExpense(String uid, String tripId, Expense expense) {
    final payload = expense.toJson();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    return _expenses(uid, tripId)
        .doc(expense.id)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> deleteExpense(String uid, String tripId, String expenseId) {
    return _expenses(uid, tripId).doc(expenseId).delete();
  }

  /// Search history ---------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _searchHistory(String uid) =>
      _firestore
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.searchHistory);

  Future<void> logSearch(String uid, String query) {
    return _searchHistory(uid).add({
      'query': query,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> streamRecentSearches(String uid, {int limit = 10}) {
    return _searchHistory(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['query'] as String? ?? '')
            .where((q) => q.isNotEmpty)
            .toList());
  }

  /// Preferences ------------------------------------------------------------
  DocumentReference<Map<String, dynamic>> _preferencesDoc(String uid) =>
      _firestore
          .collection(FirebasePaths.users)
          .doc(uid)
          .collection(FirebasePaths.preferences)
          .doc('travel_style');

  Future<void> setPreferences(String uid, Map<String, dynamic> prefs) {
    return _preferencesDoc(uid).set({
      ...prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> streamPreferences(String uid) {
    return _preferencesDoc(uid).snapshots().map((doc) => doc.data() ?? {});
  }
}
