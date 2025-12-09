import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';

class PlaceCard extends StatefulWidget {
  final Place place;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback? onAddToTrip;

  const PlaceCard({
    super.key,
    required this.place,
    required this.isBookmarked,
    required this.onToggleBookmark,
    this.onAddToTrip,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  bool _showReviews = false;

  Future<void> _openMap() async {
    final url = Uri.parse(widget.place.mapUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebsite() async {
    if (widget.place.website == null) return;
    final url = Uri.parse(widget.place.website!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Section
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(
                  place.imageUrl ?? place.placeholderImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            place.name,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Name and rating overlay
              Positioned(
                left: 16,
                right: 56,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (place.rating != null && place.rating != 'N/A')
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber.shade300,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.rating!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade300,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Bookmark button
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    if (widget.onAddToTrip != null)
                      Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: widget.onAddToTrip,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.add_location_alt,
                              size: 22,
                              color: Colors.teal.shade600,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: widget.onToggleBookmark,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            widget.isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 22,
                            color: widget.isBookmarked
                                ? Colors.amber.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  place.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      if (place.openingHours != null)
                        _InfoRow(
                          icon: Icons.access_time,
                          label: 'Open',
                          value: place.openingHours!,
                        ),
                      if (place.website != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _openWebsite,
                          child: Row(
                            children: [
                              Icon(
                                Icons.language,
                                size: 16,
                                color: Colors.teal.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Visit Website',
                                  style: TextStyle(
                                    color: Colors.teal.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: Colors.teal.shade600,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Reviews accordion
                if (place.reviews != null && place.reviews!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => _showReviews = !_showReviews),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'REVIEWS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showReviews
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showReviews)
                    ...place.reviews!.map((review) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Text(
                            '"$review"',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )),
                ],

                const SizedBox(height: 16),

                // Directions button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.teal.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
