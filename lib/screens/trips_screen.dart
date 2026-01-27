import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/trip.dart';
import '../models/place.dart';
import '../models/expense.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../widgets/expense_form.dart';

class TripsScreen extends StatefulWidget {
  final List<Trip> trips;
  final List<Place> bookmarks;
  final GeminiService geminiService;
  final StorageService storageService;
  final void Function(Trip trip) onCreateTrip;
  final void Function(Trip trip) onUpdateTrip;
  final void Function(String tripId) onDeleteTrip;
  final VoidCallback onAIFeatureUsed;

  const TripsScreen({
    super.key,
    required this.trips,
    required this.bookmarks,
    required this.geminiService,
    required this.storageService,
    required this.onCreateTrip,
    required this.onUpdateTrip,
    required this.onDeleteTrip,
    required this.onAIFeatureUsed,
  });

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  static const _uuid = Uuid();
  String? _activeTripId;
  bool _showCreateForm = false;
  final _nameController = TextEditingController();
  final _destController = TextEditingController();

  // AI Modal State
  String? _activeModal; // 'itinerary', 'tips', or null
  bool _isGenerating = false;
  bool _isWeatherLoading = false;

  Trip? get _activeTrip =>
      widget.trips.where((t) => t.id == _activeTripId).firstOrNull;

  @override
  void dispose() {
    _nameController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _createTrip() {
    if (_nameController.text.isEmpty || _destController.text.isEmpty) return;

    final newTrip = Trip(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      destination: _destController.text.trim(),
      places: [],
      expenses: [],
    );

    widget.onCreateTrip(newTrip);
    _nameController.clear();
    _destController.clear();
    setState(() {
      _showCreateForm = false;
      _activeTripId = newTrip.id;
    });
  }

  void _deletePlace(String placeId) {
    if (_activeTrip == null) return;
    final updatedTrip = _activeTrip!.copyWith(
      places: _activeTrip!.places.where((p) => p.id != placeId).toList(),
    );
    widget.onUpdateTrip(updatedTrip);
  }

  void _addExpense(
      String description, double amount, ExpenseCategory category) {
    if (_activeTrip == null) return;
    final expense = Expense(
      id: _uuid.v4(),
      description: description,
      amount: amount,
      category: category,
      date: DateTime.now(),
    );
    final updatedTrip = _activeTrip!.copyWith(
      expenses: [expense, ..._activeTrip!.expenses],
    );
    widget.onUpdateTrip(updatedTrip);
  }

  void _deleteExpense(String expenseId) {
    if (_activeTrip == null) return;
    final updatedTrip = _activeTrip!.copyWith(
      expenses: _activeTrip!.expenses.where((e) => e.id != expenseId).toList(),
    );
    widget.onUpdateTrip(updatedTrip);
  }

  // Date Management
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    if (_activeTrip == null) return;

    final initialDate = isStartDate
        ? (_activeTrip!.startDate != null
            ? DateTime.parse(_activeTrip!.startDate!)
            : DateTime.now())
        : (_activeTrip!.endDate != null
            ? DateTime.parse(_activeTrip!.endDate!)
            : DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      final dateString = picked.toIso8601String().split('T')[0];
      final updatedTrip = isStartDate
          ? _activeTrip!.copyWith(
              startDate: dateString,
              weather: null) // Clear weather to force refresh
          : _activeTrip!.copyWith(endDate: dateString, weather: null);
      widget.onUpdateTrip(updatedTrip);
    }
  }

  // AI Features
  Future<void> _generateItinerary() async {
    if (_activeTrip == null || _activeTrip!.places.isEmpty) return;

    if (_activeTrip!.itinerary != null) {
      setState(() => _activeModal = 'itinerary');
      return;
    }

    // Check if user can make a search
    final canSearch = await widget.storageService.canMakeSearch();
    if (!canSearch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Daily limit reached! Add your API key in Settings for unlimited AI features.',
            ),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeModal = 'itinerary';
    });

    try {
      final result = await widget.geminiService.generateTripItinerary(
        _activeTrip!.destination,
        _activeTrip!.places,
        startDate: _activeTrip!.startDate,
        endDate: _activeTrip!.endDate,
      );

      // Increment search count
      await widget.storageService.incrementSearchCount();
      widget.onAIFeatureUsed();

      final updatedTrip = _activeTrip!.copyWith(itinerary: result);
      widget.onUpdateTrip(updatedTrip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate itinerary')),
        );
        setState(() => _activeModal = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateTips() async {
    if (_activeTrip == null || _activeTrip!.places.isEmpty) return;

    if (_activeTrip!.tripTips != null) {
      setState(() => _activeModal = 'tips');
      return;
    }

    // Check if user can make a search
    final canSearch = await widget.storageService.canMakeSearch();
    if (!canSearch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Daily limit reached! Add your API key in Settings for unlimited AI features.',
            ),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeModal = 'tips';
    });

    try {
      final result = await widget.geminiService.generateTripTips(
        _activeTrip!.destination,
        _activeTrip!.places,
      );

      // Increment search count
      await widget.storageService.incrementSearchCount();
      widget.onAIFeatureUsed();

      final updatedTrip = _activeTrip!.copyWith(tripTips: result);
      widget.onUpdateTrip(updatedTrip);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate tips')),
        );
        setState(() => _activeModal = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _fetchWeather() async {
    if (_activeTrip == null) return;

    // Check if user can make a search
    final canSearch = await widget.storageService.canMakeSearch();
    if (!canSearch) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Daily limit reached! Add your API key in Settings for unlimited AI features.',
            ),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isWeatherLoading = true);

    try {
      final weatherJson = await widget.geminiService.generateWeatherForecast(
        _activeTrip!.destination,
        startDate: _activeTrip!.startDate,
        endDate: _activeTrip!.endDate,
      );

      // Increment search count
      await widget.storageService.incrementSearchCount();
      widget.onAIFeatureUsed();

      final updatedTrip = _activeTrip!.copyWith(weather: weatherJson);
      widget.onUpdateTrip(updatedTrip);
    } catch (e) {
      print('Error fetching weather: $e');
    } finally {
      if (mounted) {
        setState(() => _isWeatherLoading = false);
      }
    }
  }

  List<dynamic>? _parseWeatherData(String? weatherJson) {
    if (weatherJson == null) return null;
    try {
      final parsed = json.decode(weatherJson);
      if (parsed is List) return parsed;
      return null;
    } catch (e) {
      return null;
    }
  }

  IconData _getWeatherIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'sun':
        return Icons.wb_sunny;
      case 'cloud':
        return Icons.cloud;
      case 'rain':
        return Icons.umbrella;
      case 'snow':
        return Icons.ac_unit;
      case 'storm':
        return Icons.thunderstorm;
      case 'wind':
        return Icons.air;
      default:
        return Icons.wb_cloudy;
    }
  }

  Widget _renderFormattedText(String? text) {
    if (text == null) return const SizedBox.shrink();

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            line.replaceFirst('## ', ''),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.replaceFirst('### ', ''),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      } else if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  line.replaceFirst(RegExp(r'^[\s-*]+'), ''),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _showSelectSavedPlaceDialog(Trip trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add from Saved'),
        content: widget.bookmarks.isEmpty
            ? const Text('No saved places found.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.bookmarks.length,
                  itemBuilder: (context, index) {
                    final place = widget.bookmarks[index];
                    final isAlreadyAdded =
                        trip.places.any((p) => p.id == place.id);

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          place.imageUrl ?? place.placeholderImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(place.name),
                      subtitle: Text(
                        isAlreadyAdded ? 'Already added' : place.searchQuery,
                        style: TextStyle(
                            color: isAlreadyAdded ? Colors.orange : null),
                      ),
                      trailing: Icon(
                        isAlreadyAdded
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: isAlreadyAdded ? Colors.green : Colors.teal,
                      ),
                      onTap: isAlreadyAdded
                          ? null
                          : () {
                              Navigator.pop(context);
                              final updatedTrip = trip.copyWith(
                                places: [...trip.places, place],
                              );
                              widget.onUpdateTrip(updatedTrip);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${place.name} to trip'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                    );
                  },
                ),
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

  @override
  Widget build(BuildContext context) {
    if (_activeTrip != null) {
      return _buildDetailView();
    }
    return _buildListView();
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.work_outline, color: Colors.teal.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'My Trips',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan your adventures and track expenses',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showCreateForm = true),
                icon: const Icon(Icons.add),
                label: const Text('New Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Create Form
          if (_showCreateForm) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start a New Adventure',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Trip Name',
                            hintText: 'e.g. Summer Vacation 2024',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _destController,
                          decoration: InputDecoration(
                            labelText: 'Destination',
                            hintText: 'e.g. Paris, France',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showCreateForm = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Trips Grid
          if (widget.trips.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_open,
                        size: 48,
                        color: Colors.teal.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No trips yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first trip to start planning.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _showCreateForm = true),
                      child: const Text('Create a Trip'),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: constraints.maxWidth > 800
                        ? 1.4
                        : constraints.maxWidth > 500
                            ? 1.2
                            : 0.85,
                  ),
                  itemCount: widget.trips.length,
                  itemBuilder: (context, index) {
                    final trip = widget.trips[index];
                    return _buildTripCard(trip);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    return GestureDetector(
      onTap: () => setState(() => _activeTripId = trip.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.work_outline,
                    color: Colors.teal.shade600,
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onDeleteTrip(trip.id),
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const Spacer(),
            Text(
              trip.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${trip.places.length} Places',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Text(
                  '\$${trip.totalExpenses.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final trip = _activeTrip!;

    // Calculate duration
    final startDateObj =
        trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;
    final endDateObj =
        trip.endDate != null ? DateTime.tryParse(trip.endDate!) : null;
    final durationDays = startDateObj != null && endDateObj != null
        ? endDateObj.difference(startDateObj).inDays + 1
        : 0;

    // Auto-fetch weather if not present
    if (trip.weather == null && !_isWeatherLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWeather());
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextButton.icon(
                  onPressed: () => setState(() => _activeTripId = null),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Trips'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                ),
              ),

              // Enhanced Header with Dates and Weather
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Budget Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      trip.destination,
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'BUDGET',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${trip.totalExpenses.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Date Pickers and Weather
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildDateSection(trip, startDateObj,
                                    endDateObj, durationDays),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: _buildWeatherSection(trip),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildDateSection(
                                  trip, startDateObj, endDateObj, durationDays),
                              const SizedBox(height: 16),
                              _buildWeatherSection(trip),
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // AI Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAIButton(
                          label: trip.itinerary != null
                              ? 'View Itinerary'
                              : 'Prepare Itinerary',
                          icon: Icons.auto_awesome,
                          color: trip.itinerary != null
                              ? Colors.purple
                              : Colors.teal,
                          onPressed:
                              trip.places.isEmpty ? null : _generateItinerary,
                        ),
                        _buildAIButton(
                          label: trip.tripTips != null
                              ? 'View Tips'
                              : 'Gears & Tips',
                          icon: Icons.backpack,
                          color: trip.tripTips != null
                              ? Colors.amber
                              : Colors.grey.shade700,
                          onPressed: trip.places.isEmpty ? null : _generateTips,
                        ),
                        if (trip.places.isNotEmpty)
                          _buildAIButton(
                            label: 'View Route',
                            icon: Icons.map,
                            color: Colors.blue,
                            onPressed: () => _openRouteInMaps(trip),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;

                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Places
                          Expanded(
                            flex: 3,
                            child: _buildPlacesSection(trip),
                          ),
                          const SizedBox(width: 24),
                          // Right Column: Expenses
                          Expanded(
                            flex: 2,
                            child: _buildExpensesSection(trip),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPlacesSection(trip),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          _buildExpensesSection(trip),
                        ],
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),

        // Modal Overlay for AI Content
        if (_activeModal != null)
          GestureDetector(
            onTap: () => setState(() => _activeModal = null),
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping on modal
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    constraints:
                        const BoxConstraints(maxWidth: 700, maxHeight: 600),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Modal Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade600,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _activeModal == 'itinerary'
                                    ? Icons.auto_awesome
                                    : Icons.backpack,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _activeModal == 'itinerary'
                                      ? 'Suggested Itinerary'
                                      : 'Gears & Travel Tips',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _activeModal = null),
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // Modal Content
                        Expanded(
                          child: _isGenerating
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.teal.shade600,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Consulting the Travel Genie...',
                                        style: TextStyle(
                                          color: Colors.teal.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: _renderFormattedText(
                                    _activeModal == 'itinerary'
                                        ? _activeTrip?.itinerary
                                        : _activeTrip?.tripTips,
                                  ),
                                ),
                        ),

                        // Modal Footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    setState(() => _activeModal = null),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.grey.shade800,
                                  elevation: 0,
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlacesSection(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Itinerary & Places',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (widget.bookmarks.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showSelectSavedPlaceDialog(trip),
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Add Saved'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (trip.places.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'No places added yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                if (widget.bookmarks.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _showSelectSavedPlaceDialog(trip),
                    icon: const Icon(Icons.bookmark),
                    label: const Text('Add from Saved Places'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal.shade700,
                      elevation: 0,
                    ),
                  )
                else
                  Text(
                    'Go to the Planner tab to explore and add locations!',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trip.places.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final place = trip.places[index];
              return _buildPlaceItem(place);
            },
          ),
      ],
    );
  }

  Widget _buildExpensesSection(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: Colors.teal.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showAddExpenseDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (trip.expenses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'No expenses yet',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trip.expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final expense = trip.expenses[index];
              return _buildExpenseItem(expense);
            },
          ),
      ],
    );
  }

  Widget _buildPlaceItem(Place place) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              place.imageUrl ?? place.placeholderImageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  place.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (place.rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★ ${place.rating}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deletePlace(place.id),
            icon: const Icon(Icons.delete_outline),
            iconSize: 20,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getCategoryColor(expense.category).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(expense.category),
              size: 18,
              color: _getCategoryColor(expense.category),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  expense.category.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _deleteExpense(expense.id),
            icon: const Icon(Icons.close),
            iconSize: 16,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Colors.orange;
      case ExpenseCategory.transport:
        return Colors.blue;
      case ExpenseCategory.accommodation:
        return Colors.purple;
      case ExpenseCategory.activity:
        return Colors.green;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.accommodation:
        return Icons.hotel;
      case ExpenseCategory.activity:
        return Icons.local_activity;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  void _showAddExpenseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ExpenseForm(
          onAddExpense: (description, amount, category) {
            _addExpense(description, amount, category);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // New AI-related helper widgets
  Widget _buildDateSection(Trip trip, DateTime? startDateObj,
      DateTime? endDateObj, int durationDays) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                'TRAVEL DATES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'START DATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          trip.startDate ?? 'Select date',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: trip.startDate != null
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Icon(Icons.arrow_forward,
                    size: 16, color: Colors.teal.shade300),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'END DATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          trip.endDate ?? 'Select date',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: trip.endDate != null
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (durationDays > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$durationDays Day Trip',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherSection(Trip trip) {
    final weatherData = _parseWeatherData(trip.weather);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.thermostat, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'FORECAST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              if (trip.weather != null)
                TextButton(
                  onPressed: _fetchWeather,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isWeatherLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (weatherData != null && weatherData.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: weatherData.length,
                itemBuilder: (context, index) {
                  final day = weatherData[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          day['day'] ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Icon(
                          _getWeatherIcon(day['icon']),
                          size: 24,
                          color: Colors.blue.shade600,
                        ),
                        Text(
                          day['temperature'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          day['condition'] ?? '',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.wb_cloudy,
                        size: 32, color: Colors.blue.shade200),
                    const SizedBox(height: 8),
                    Text(
                      'Set dates for forecast',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAIButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey.shade300,
        foregroundColor:
            onPressed != null ? Colors.white : Colors.grey.shade500,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _openRouteInMaps(Trip trip) {
    if (trip.places.isEmpty) return;

    // Build Google Maps URL
    String url;
    if (trip.places.length == 1) {
      final place = trip.places[0];
      url = place.sourceUri ??
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(place.name)}';
    } else {
      final origin = Uri.encodeComponent(trip.places.first.name);
      final destination = Uri.encodeComponent(trip.places.last.name);
      final waypoints = trip.places.length > 2
          ? trip.places
              .sublist(1, trip.places.length - 1)
              .map((p) => Uri.encodeComponent(p.name))
              .join('|')
          : '';
      url =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}&travelmode=driving';
    }

    // Open URL
    // Note: You'll need to add url_launcher dependency and import it
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
