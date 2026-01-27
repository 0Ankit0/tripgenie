import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../widgets/place_card.dart';

class PlannerScreen extends StatefulWidget {
  final GeminiService geminiService;
  final StorageService storageService;
  final Set<String> bookmarkedIds;
  final void Function(Place place) onToggleBookmark;
  final void Function(Place place) onAddToTrip;
  final VoidCallback onSearchComplete;

  const PlannerScreen({
    super.key,
    required this.geminiService,
    required this.storageService,
    required this.bookmarkedIds,
    required this.onToggleBookmark,
    required this.onAddToTrip,
    required this.onSearchComplete,
  });

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _searchController = TextEditingController();
  List<Place>? _places;
  String? _currentDestination;
  bool _isLoading = false;
  String? _error;

  static const _popularDestinations = [
    "Pokhara, Nepal",
    "Kathmandu, Nepal",
    "Paris, France",
    "London, UK",
    "Tokyo, Japan",
    "New York, USA",
    "Rome, Italy",
    "Bali, Indonesia",
    "Dubai, UAE",
    "Singapore",
    "Bangkok, Thailand",
    "Barcelona, Spain",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final destination = _searchController.text.trim();
    if (destination.isEmpty) return;

    // Check if user can make a search
    final canSearch = await widget.storageService.canMakeSearch();
    if (!canSearch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Daily search limit reached! Add your API key in Settings for unlimited searches.',
            ),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                // The settings button in app bar will handle this
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final places = await widget.geminiService.searchPlaces(destination);

      // Increment search count after successful search
      await widget.storageService.incrementSearchCount();
      widget.onSearchComplete();

      setState(() {
        _places = places;
        _currentDestination = destination;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to fetch places. Please check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero search section
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal.shade500,
                  const Color(0xFF059669), // Emerald 600
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -32,
                  left: -32,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -48,
                  right: -48,
                  child: Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    children: [
                      const Text(
                        'Where to next?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter a destination and let our AI plan your perfect itinerary.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(
                              Icons.search,
                              color: _isLoading
                                  ? Colors.teal.shade300
                                  : Colors.grey.shade400,
                            ),
                            Expanded(
                              child: Autocomplete<String>(
                                optionsBuilder: (textValue) {
                                  if (textValue.text.isEmpty) {
                                    return const Iterable.empty();
                                  }
                                  return _popularDestinations.where(
                                    (d) => d.toLowerCase().contains(
                                          textValue.text.toLowerCase(),
                                        ),
                                  );
                                },
                                onSelected: (value) {
                                  _searchController.text = value;
                                  _search();
                                },
                                fieldViewBuilder: (context, controller,
                                    focusNode, onSubmitted) {
                                  // Sync controllers
                                  controller.text = _searchController.text;
                                  controller.addListener(() {
                                    _searchController.text = controller.text;
                                  });

                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g., Pokhara, Nepal',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                    enabled: !_isLoading,
                                    onSubmitted: (_) => _search(),
                                  );
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(6),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _search,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Explore',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _error = null),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

          // Results
          if (_places != null && _places!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, color: Colors.teal.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attractions in $_currentDestination',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_places!.length} places',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900
                          ? 3
                          : constraints.maxWidth > 600
                              ? 2
                              : 1;

                      if (crossAxisCount == 1) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _places!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final place = _places![index];
                            return PlaceCard(
                              place: place,
                              isBookmarked:
                                  widget.bookmarkedIds.contains(place.id),
                              onToggleBookmark: () =>
                                  widget.onToggleBookmark(place),
                              onAddToTrip: () => widget.onAddToTrip(place),
                            );
                          },
                        );
                      } else {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: _places!.length,
                          itemBuilder: (context, index) {
                            final place = _places![index];
                            return PlaceCard(
                              place: place,
                              isBookmarked:
                                  widget.bookmarkedIds.contains(place.id),
                              onToggleBookmark: () =>
                                  widget.onToggleBookmark(place),
                              onAddToTrip: () => widget.onAddToTrip(place),
                            );
                          },
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

          // Empty state
          if (_places == null && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for a destination to get started',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
