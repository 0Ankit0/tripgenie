import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/api_key_setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  runApp(TripGenieApp(storageService: storageService));
}

class TripGenieApp extends StatefulWidget {
  final StorageService storageService;

  const TripGenieApp({super.key, required this.storageService});

  @override
  State<TripGenieApp> createState() => _TripGenieAppState();
}

class _TripGenieAppState extends State<TripGenieApp> {
  late bool _hasApiKey;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  void _checkApiKey() {
    _hasApiKey = widget.storageService.hasApiKey();
    if (_hasApiKey) {
      _apiKey = widget.storageService.getApiKey();
    }
  }

  void _onApiKeySaved(String apiKey) async {
    await widget.storageService.setApiKey(apiKey);
    setState(() {
      _hasApiKey = true;
      _apiKey = apiKey;
    });
  }

  void _onLogout() async {
    await widget.storageService.clearApiKey();
    setState(() {
      _hasApiKey = false;
      _apiKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripGenie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
        fontFamily: 'Roboto',
      ),
      home: _hasApiKey && _apiKey != null
          ? HomeScreen(
              storageService: widget.storageService,
              apiKey: _apiKey!,
              onLogout: _onLogout,
            )
          : ApiKeySetupScreen(onApiKeySaved: _onApiKeySaved),
    );
  }
}
