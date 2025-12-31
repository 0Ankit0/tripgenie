import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'planner_screen.dart';
import 'trips_screen.dart';
import 'saved_screen.dart';

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
  late List<Trip> _trips;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(widget.apiKey);
    _bookmarks = widget.storageService.getBookmarks();
    _trips = widget.storageService.getTrips();
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

  // Trip Management
  void _createTrip(Trip trip) {
    setState(() {
      _trips.insert(0, trip);
    });
    widget.storageService.addTrip(trip);
  }

  void _updateTrip(Trip trip) {
    setState(() {
      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index >= 0) {
        _trips[index] = trip;
      }
    });
    widget.storageService.updateTrip(trip);
  }

  void _deleteTrip(String tripId) {
    setState(() {
      _trips.removeWhere((t) => t.id == tripId);
    });
    widget.storageService.deleteTrip(tripId);
  }

  void _addPlaceToTrip(Place place) {
    if (_trips.isEmpty) {
      // Auto-create a new trip
      final newTrip = Trip(
        id: _uuid.v4(),
        name: place.searchQuery.isNotEmpty ? place.searchQuery : 'My New Trip',
        destination:
            place.searchQuery.isNotEmpty ? place.searchQuery : 'Unknown',
        places: [place],
        expenses: [],
      );
      _createTrip(newTrip);
      _showSnackBar(
          'Created new trip "${newTrip.name}" and added ${place.name}!');
    } else if (_trips.length == 1) {
      // Add to the only trip
      final trip = _trips[0];
      if (trip.places.any((p) => p.id == place.id)) {
        _showSnackBar('${place.name} is already in ${trip.name}.');
        return;
      }
      final updatedTrip = trip.copyWith(
        places: [...trip.places, place],
      );
      _updateTrip(updatedTrip);
      _showSnackBar('Added ${place.name} to ${trip.name}.');
    } else {
      // Show trip selection dialog
      _showTripSelectionDialog(place);
    }
  }

  void _showTripSelectionDialog(Place place) {
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
            ...(_trips.map((trip) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.work_outline, color: Colors.teal.shade600),
                  ),
                  title: Text(trip.name),
                  subtitle: Text(trip.destination),
                  trailing: const Icon(Icons.add),
                  onTap: () {
                    Navigator.pop(context);
                    if (trip.places.any((p) => p.id == place.id)) {
                      _showSnackBar(
                          '${place.name} is already in ${trip.name}.');
                      return;
                    }
                    final updatedTrip = trip.copyWith(
                      places: [...trip.places, place],
                    );
                    _updateTrip(updatedTrip);
                    _showSnackBar('Added ${place.name} to ${trip.name}.');
                  },
                ))),
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
            onAddToTrip: _addPlaceToTrip,
          ),
          TripsScreen(
            trips: _trips,
            bookmarks: _bookmarks,
            onCreateTrip: _createTrip,
            onUpdateTrip: _updateTrip,
            onDeleteTrip: _deleteTrip,
          ),
          SavedScreen(
            bookmarks: _bookmarks,
            onToggleBookmark: _toggleBookmark,
            onAddToTrip: _addPlaceToTrip,
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
                  if (_trips.isNotEmpty)
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
                          '${_trips.length}',
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
                  if (_trips.isNotEmpty)
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
                          '${_trips.length}',
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
          ],
        ),
      ),
    );
  }
}
