import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import '../models/trip.dart';
import '../providers.dart';
import 'auth_providers.dart';

/// Stream all bookmarks for the current user; empty stream when user unknown.
final bookmarksProvider =
    StreamProvider.family<List<Place>, String?>((ref, uid) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (uid == null) return const Stream<List<Place>>.empty();
  return firestore.streamBookmarks(uid);
});

/// Stream all trips for the current user; empty stream when user unknown.
final tripsProvider = StreamProvider.family<List<Trip>, String?>((ref, uid) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (uid == null) return const Stream<List<Trip>>.empty();
  return firestore.streamTrips(uid);
});

/// Helper provider to trigger auth side effect early; watch this in app shell.
final appBootstrapProvider = Provider<void>((ref) {
  // Initiate anonymous sign-in so downstream providers always have a uid.
  ref.watch(ensureSignedInProvider);
});
