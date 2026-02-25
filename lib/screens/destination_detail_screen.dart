import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/destination_details.dart';
import '../services/destination_intelligence_service.dart';
import '../services/weather_service.dart';

/// Screen showing comprehensive destination intelligence.
class DestinationDetailScreen extends ConsumerStatefulWidget {
  final String destination;
  final String apiKey;

  const DestinationDetailScreen({
    super.key,
    required this.destination,
    required this.apiKey,
  });

  @override
  ConsumerState<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState
    extends ConsumerState<DestinationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DestinationDetails? _details;
  bool _isLoading = true;
  String? _error;

  late DestinationIntelligenceService _intelligenceService;
  late WeatherService _weatherService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _intelligenceService = DestinationIntelligenceService(widget.apiKey);
    _weatherService = WeatherService();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load destination details from Gemini
      final details =
          await _intelligenceService.getDestinationDetails(widget.destination);

      if (details == null) {
        setState(() {
          _error = 'Could not load destination information';
          _isLoading = false;
        });
        return;
      }

      // Load weather if coordinates available
      if (details.latitude != null && details.longitude != null) {
        final weather = await _weatherService.getCurrentWeather(
          details.latitude!,
          details.longitude!,
        );
        final forecast = await _weatherService.getWeatherForecast(
          details.latitude!,
          details.longitude!,
        );

        // Create updated details with weather
        _details = DestinationDetails(
          name: details.name,
          country: details.country,
          latitude: details.latitude,
          longitude: details.longitude,
          overview: details.overview,
          history: details.history,
          culturalSignificance: details.culturalSignificance,
          bestTimeToVisit: details.bestTimeToVisit,
          monthlyWeather: details.monthlyWeather,
          language: details.language,
          currency: details.currency,
          languages: details.languages,
          safetyTips: details.safetyTips,
          emergencyNumbers: details.emergencyNumbers,
          visaRequirements: details.visaRequirements,
          localCustoms: details.localCustoms,
          budgetEstimates: details.budgetEstimates,
          topAttractions: details.topAttractions,
          hiddenGems: details.hiddenGems,
          foodRecommendations: details.foodRecommendations,
          currentWeather: weather,
          forecast: forecast,
          ecoTourismInfo: details.ecoTourismInfo,
        );
      } else {
        _details = details;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.destination,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: _details != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.teal.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.teal.shade700,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Weather'),
                  Tab(text: 'Practical'),
                  Tab(text: 'Budget'),
                  Tab(text: 'Transport'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildWeatherTab(),
                    _buildPracticalTab(),
                    _buildBudgetTab(),
                    _buildTransportTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'About ${_details!.name}',
            Icons.info_outline,
            [
              if (_details!.overview != null) Text(_details!.overview!),
            ],
          ),
          const SizedBox(height: 24),
          if (_details!.history != null)
            _buildSection(
              'History',
              Icons.history_edu,
              [Text(_details!.history!)],
            ),
          if (_details!.history != null) const SizedBox(height: 24),
          if (_details!.culturalSignificance != null)
            _buildSection(
              'Cultural Significance',
              Icons.museum_outlined,
              [Text(_details!.culturalSignificance!)],
            ),
          if (_details!.culturalSignificance != null)
            const SizedBox(height: 24),
          if (_details!.topAttractions != null &&
              _details!.topAttractions!.isNotEmpty)
            _buildSection(
              'Top Attractions',
              Icons.stars,
              _details!.topAttractions!
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.place,
                                size: 20, color: Colors.teal.shade600),
                            const SizedBox(width: 8),
                            Expanded(child: Text(a)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (_details!.topAttractions != null) const SizedBox(height: 24),
          if (_details!.hiddenGems != null && _details!.hiddenGems!.isNotEmpty)
            _buildSection(
              'Hidden Gems',
              Icons.explore,
              _details!.hiddenGems!
                  .map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.diamond_outlined,
                                size: 20, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(child: Text(g)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (_details!.hiddenGems != null) const SizedBox(height: 24),
          if (_details!.foodRecommendations != null &&
              _details!.foodRecommendations!.isNotEmpty)
            _buildSection(
              'Local Cuisine',
              Icons.restaurant,
              _details!.foodRecommendations!
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.restaurant_menu,
                                size: 20, color: Colors.orange.shade600),
                            const SizedBox(width: 8),
                            Expanded(child: Text(f)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_details!.currentWeather != null) ...[
            _buildSection(
              'Current Weather',
              Icons.wb_sunny,
              [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_details!.currentWeather!.temperature.round()}°C',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _details!.currentWeather!.condition,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Feels like: ${_details!.currentWeather!.feelsLike.round()}°C',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Humidity: ${_details!.currentWeather!.humidity}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            'Wind: ${_details!.currentWeather!.windSpeed.round()} km/h',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (_details!.forecast != null && _details!.forecast!.isNotEmpty) ...[
            _buildSection(
              '7-Day Forecast',
              Icons.calendar_today,
              [
                ...(_details!.forecast!.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEE, MMM d').format(f.date),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(f.condition),
                          const SizedBox(width: 16),
                          Text(
                            '${f.minTemp.round()}° / ${f.maxTemp.round()}°',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ))),
              ],
            ),
            const SizedBox(height: 24),
          ],
          if (_details!.bestTimeToVisit != null)
            _buildSection(
              'Best Time to Visit',
              Icons.event_available,
              [Text(_details!.bestTimeToVisit!)],
            ),
        ],
      ),
    );
  }

  Widget _buildPracticalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_details!.language != null || _details!.languages != null)
            _buildSection(
              'Languages',
              Icons.language,
              [
                Text(
                  _details!.languages?.join(', ') ??
                      _details!.language ??
                      'N/A',
                ),
              ],
            ),
          if (_details!.language != null) const SizedBox(height: 24),
          if (_details!.currency != null)
            _buildSection(
              'Currency',
              Icons.attach_money,
              [Text(_details!.currency!)],
            ),
          if (_details!.currency != null) const SizedBox(height: 24),
          if (_details!.visaRequirements != null)
            _buildSection(
              'Visa Requirements',
              Icons.card_travel,
              [Text(_details!.visaRequirements!)],
            ),
          if (_details!.visaRequirements != null) const SizedBox(height: 24),
          if (_details!.safetyTips != null && _details!.safetyTips!.isNotEmpty)
            _buildSection(
              'Safety Tips',
              Icons.security,
              _details!.safetyTips!
                  .map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle,
                                size: 20, color: Colors.green.shade600),
                            const SizedBox(width: 8),
                            Expanded(child: Text(tip)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (_details!.safetyTips != null) const SizedBox(height: 24),
          if (_details!.emergencyNumbers != null)
            _buildSection(
              'Emergency Contacts',
              Icons.phone_in_talk,
              [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _details!.emergencyNumbers!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          if (_details!.emergencyNumbers != null) const SizedBox(height: 24),
          if (_details!.localCustoms != null)
            _buildSection(
              'Local Customs & Etiquette',
              Icons.people,
              [Text(_details!.localCustoms!)],
            ),
          if (_details!.ecoTourismInfo != null) ...[
            const SizedBox(height: 24),
            _buildSection(
              'Sustainability & Eco-Tourism',
              Icons.eco,
              [Text(_details!.ecoTourismInfo!)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_details!.budgetEstimates != null &&
              _details!.budgetEstimates!.isNotEmpty)
            _buildSection(
              'Daily Budget Estimates',
              Icons.account_balance_wallet,
              [
                ..._details!.budgetEstimates!.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '\$${e.value.toStringAsFixed(0)} / day',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Budget estimates include accommodation, food, local transport, and activities.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coming Soon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Transport route information will be available here.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.teal.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}
