import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/place.dart';
import '../models/trip.dart';
import '../providers.dart';
import '../services/gemini_service.dart';
import '../state/auth_providers.dart';
import '../state/data_providers.dart';
import '../state/preferences_providers.dart';
import '../models/travel_preferences.dart';
import 'planner_screen.dart';
import 'saved_screen.dart';
import 'trips_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String apiKey;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.apiKey,
    required this.onLogout,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late GeminiService _geminiService;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(widget.apiKey);
  }

  Future<void> _toggleBookmark(Place place) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) {
      _showSnackBar('Signing you in, please try again.');
      return;
    }

    final bookmarks = ref.read(bookmarksProvider(uid)).value ?? [];
    final firestore = ref.read(firestoreServiceProvider);
    final isBookmarked = bookmarks.any((p) => p.id == place.id);

    if (isBookmarked) {
      await firestore.deleteBookmark(uid, place.id);
      _showSnackBar('Removed from saved');
    } else {
      await firestore.upsertBookmark(uid, place);
      _showSnackBar('Saved ${place.name}');
    }
  }

  Future<void> _createTrip(Trip trip) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) {
      _showSnackBar('Signing you in, please try again.');
      return;
    }
    await ref.read(firestoreServiceProvider).upsertTrip(uid, trip);
    _showSnackBar('Created ${trip.name}');
  }

  Future<void> _updateTrip(Trip trip) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).upsertTrip(uid, trip);
  }

  Future<void> _deleteTrip(String tripId) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).deleteTrip(uid, tripId);
  }

  Future<void> _addPlaceToTrip(Place place, List<Trip> trips) async {
    final uid = ref.read(userIdProvider);
    if (uid == null) {
      _showSnackBar('Signing you in, please try again.');
      return;
    }

    if (trips.isEmpty) {
      final newTrip = Trip(
        id: _uuid.v4(),
        name: place.searchQuery.isNotEmpty ? place.searchQuery : 'My New Trip',
        destination:
            place.searchQuery.isNotEmpty ? place.searchQuery : 'Unknown',
        places: [place],
        expenses: [],
      );
      await _createTrip(newTrip);
      _showSnackBar(
        'Created new trip "${newTrip.name}" and added ${place.name}!',
      );
    } else if (trips.length == 1) {
      final trip = trips[0];
      if (trip.places.any((p) => p.id == place.id)) {
        _showSnackBar('${place.name} is already in ${trip.name}.');
        return;
      }
      final updatedTrip = trip.copyWith(
        places: [...trip.places, place],
      );
      await _updateTrip(updatedTrip);
      _showSnackBar('Added ${place.name} to ${trip.name}.');
    } else {
      _showTripSelectionDialog(place, trips);
    }
  }

  void _showTripSelectionDialog(Place place, List<Trip> trips) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which trip do you want to add ${place.name} to?',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...trips.map(
              (trip) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.work_outline, color: Colors.teal.shade600),
                ),
                title: Text(trip.name),
                subtitle: Text(trip.destination),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  Navigator.pop(context);
                  if (trip.places.any((p) => p.id == place.id)) {
                    _showSnackBar('${place.name} is already in ${trip.name}.');
                    return;
                  }
                  final updatedTrip = trip.copyWith(
                    places: [...trip.places, place],
                  );
                  await _updateTrip(updatedTrip);
                  _showSnackBar('Added ${place.name} to ${trip.name}.');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
              'API Key: ${widget.apiKey.substring(0, math.min(widget.apiKey.length, 8))}...',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Travel style',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildTravelStyleChips(),
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

  Widget _buildTravelStyleChips() {
    final prefs = ref.watch(travelPreferencesProvider).value;
    final current = prefs?.travelStyle;
    const options = ['budget', 'adventure', 'cultural', 'luxury'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (opt) => ChoiceChip(
              label: Text(opt.toUpperCase()),
              selected: current == opt,
              onSelected: (selected) async {
                final updater = ref.read(updatePreferencesProvider);
                await updater(
                    TravelPreferences(travelStyle: selected ? opt : null));
              },
              selectedColor: Colors.teal.shade100,
            ),
          )
          .toList(),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear & Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(userIdProvider);
    final bookmarksAsync = ref.watch(bookmarksProvider(uid));
    final tripsAsync = ref.watch(tripsProvider(uid));

    final bookmarks = bookmarksAsync.value ?? <Place>[];
    final trips = tripsAsync.value ?? <Trip>[];
    final bookmarkedIds = bookmarks.map((p) => p.id).toSet();
    final isSyncing = bookmarksAsync.isLoading || tripsAsync.isLoading;

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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              PlannerScreen(
                geminiService: _geminiService,
                bookmarkedIds: bookmarkedIds,
                onToggleBookmark: _toggleBookmark,
                onAddToTrip: (place) => _addPlaceToTrip(place, trips),
                apiKey: widget.apiKey,
              ),
              TripsScreen(
                trips: trips,
                bookmarks: bookmarks,
                onCreateTrip: _createTrip,
                onUpdateTrip: _updateTrip,
                onDeleteTrip: _deleteTrip,
              ),
              SavedScreen(
                bookmarks: bookmarks,
                onToggleBookmark: _toggleBookmark,
                onAddToTrip: (place) => _addPlaceToTrip(place, trips),
              ),
            ],
          ),
          if (isSyncing)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: Colors.teal.shade400,
              ),
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
                  const Icon(Icons.work_outline),
                  if (trips.isNotEmpty)
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
                          '${trips.length}',
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
                  const Icon(Icons.work),
                  if (trips.isNotEmpty)
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
                          '${trips.length}',
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
              label: 'Trips',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.bookmark_border),
                  if (bookmarks.isNotEmpty)
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
                          '${bookmarks.length}',
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
                  if (bookmarks.isNotEmpty)
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
                          '${bookmarks.length}',
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
          ],
        ),
      ),
    );
  }
}
