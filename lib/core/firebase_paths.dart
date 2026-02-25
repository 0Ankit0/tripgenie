class FirebasePaths {
  FirebasePaths._();

  static const users = 'users';
  static const bookmarks = 'bookmarks';
  static const trips = 'trips';
  static const expenses = 'expenses';
  static const searchHistory = 'search_history';
  static const preferences = 'preferences';

  static String userDoc(String uid) => '$users/$uid';
  static String userSubcollection(String uid, String collection) =>
      '${userDoc(uid)}/$collection';
}
