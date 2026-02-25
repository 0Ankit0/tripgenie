// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Free currency exchange rate service using exchangerate-api.com free tier.
/// https://www.exchangerate-api.com/
/// Free tier: 1,500 requests/month
class CurrencyService {
  static const _baseUrl = 'https://api.exchangerate-api.com/v4/latest';

  /// Cache for exchange rates to minimize API calls
  final Map<String, CachedRates> _cache = {};
  static const _cacheValidityHours = 24;

  Future<Map<String, double>?> getExchangeRates(String baseCurrency) async {
    // Check cache first
    if (_cache.containsKey(baseCurrency)) {
      final cached = _cache[baseCurrency]!;
      if (DateTime.now().difference(cached.timestamp).inHours <
          _cacheValidityHours) {
        return cached.rates;
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/$baseCurrency');
      final response = await http.get(url);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final rates = (data['rates'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));

      // Cache the result
      _cache[baseCurrency] = CachedRates(
        rates: rates,
        timestamp: DateTime.now(),
      );

      return rates;
    } catch (e) {
      print('Error fetching exchange rates: $e');
      return null;
    }
  }

  Future<double?> convertCurrency(
    double amount,
    String from,
    String to,
  ) async {
    if (from == to) return amount;

    final rates = await getExchangeRates(from);
    if (rates == null || !rates.containsKey(to)) return null;

    return amount * rates[to]!;
  }

  /// Common currencies for quick access
  static const commonCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CNY',
    'INR',
    'AUD',
    'CAD',
    'CHF',
    'NPR',
  ];
}

class CachedRates {
  final Map<String, double> rates;
  final DateTime timestamp;

  CachedRates({required this.rates, required this.timestamp});
}
