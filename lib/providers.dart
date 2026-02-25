import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/firestore_service.dart';
import 'services/storage_service.dart';

/// Riverpod providers to make core services globally available.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FirestoreService(firestore: firestore);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'StorageService must be overridden at app start with the initialized instance.',
  );
});
