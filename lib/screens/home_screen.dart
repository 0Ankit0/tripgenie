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

  const HomeScreen({
    super.key,
    required this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late GeminiService _geminiService;
  late List<Place> _bookmarks;
  late List<Trip> _trips;
  int _remainingSearches = 10;
  bool _hasUserApiKey = false;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _bookmarks = widget.storageService.getBookmarks();
    _trips = widget.storageService.getTrips();
  }

  void _initializeServices() async {
    _hasUserApiKey = widget.storageService.hasApiKey();
    final apiKey = widget.storageService.getEffectiveApiKey();
    _geminiService = GeminiService(apiKey);

    final remaining = await widget.storageService.getRemainingSearches();
    setState(() {
      _remainingSearches = remaining;
    });
  }

  void _refreshApiKeyStatus() async {
    _hasUserApiKey = widget.storageService.hasApiKey();
    final apiKey = widget.storageService.getEffectiveApiKey();
    _geminiService = GeminiService(apiKey);

    final remaining = await widget.storageService.getRemainingSearches();
    setState(() {
      _remainingSearches = remaining;
    });
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
    final apiKeyController = TextEditingController(
      text: widget.storageService.getApiKey() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gemini API Key',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your own API key for unlimited searches. Without it, you get 10 free searches per day.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  hintText: 'Enter your Gemini API key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.key),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Get your free API key from ai.google.dev',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.storageService.hasApiKey())
            TextButton(
              onPressed: () async {
                await widget.storageService.clearApiKey();
                apiKeyController.clear();
                _refreshApiKeyStatus();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'API key removed. Using default key with 10 daily searches.'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove Key'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = apiKeyController.text.trim();
              if (key.isNotEmpty) {
                await widget.storageService.setApiKey(key);
                _refreshApiKeyStatus();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'API key saved! You now have unlimited searches.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid API key'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
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
      body: Column(
        children: [
          // Banner for users without API key
          if (!_hasUserApiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Limited Mode: $_remainingSearches/${StorageService.maxDailySearches} searches remaining today',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Text(
                          'Add your API key in Settings for unlimited searches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showSettingsDialog,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Add Key',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                PlannerScreen(
                  geminiService: _geminiService,
                  storageService: widget.storageService,
                  bookmarkedIds: _bookmarkedIds,
                  onToggleBookmark: _toggleBookmark,
                  onAddToTrip: _addPlaceToTrip,
                  onSearchComplete: _refreshApiKeyStatus,
                ),
                TripsScreen(
                  trips: _trips,
                  bookmarks: _bookmarks,
                  geminiService: _geminiService,
                  storageService: widget.storageService,
                  onCreateTrip: _createTrip,
                  onUpdateTrip: _updateTrip,
                  onDeleteTrip: _deleteTrip,
                  onAIFeatureUsed: _refreshApiKeyStatus,
                ),
                SavedScreen(
                  bookmarks: _bookmarks,
                  onToggleBookmark: _toggleBookmark,
                  onAddToTrip: _addPlaceToTrip,
                ),
              ],
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
