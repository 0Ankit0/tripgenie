import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/travel_preferences.dart';
import '../providers.dart';
import 'auth_providers.dart';

/// Stream travel preferences for the current user.
final travelPreferencesProvider = StreamProvider<TravelPreferences?>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream<TravelPreferences?>.empty();
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.streamPreferences(uid).map((data) {
    if (data.isEmpty) return null;
    return TravelPreferences.fromJson(data);
  });
});

/// Update travel preferences.
final updatePreferencesProvider =
    Provider<Future<void> Function(TravelPreferences prefs)>((ref) {
  return (prefs) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) return;
    await ref
        .read(firestoreServiceProvider)
        .setPreferences(uid, prefs.toJson());
  };
});
