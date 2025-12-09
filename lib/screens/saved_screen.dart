import 'package:flutter/material.dart';
import '../models/place.dart';
import '../widgets/place_card.dart';

class SavedScreen extends StatelessWidget {
  final List<Place> bookmarks;
  final void Function(Place place) onToggleBookmark;
  final void Function(Place place) onAddToTrip;

  const SavedScreen({
    super.key,
    required this.bookmarks,
    required this.onToggleBookmark,
    required this.onAddToTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: Colors.teal.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Saved Places',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your collection of bookmarked locations from various trips.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark_border,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved places yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start exploring and bookmark places you love!',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bookmarks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final place = bookmarks[index];
                    return PlaceCard(
                      place: place,
                      isBookmarked: true,
                      onToggleBookmark: () => onToggleBookmark(place),
                      onAddToTrip: () => onAddToTrip(place),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
