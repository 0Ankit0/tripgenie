import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers.dart';
import 'screens/api_key_setup_screen.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'state/auth_providers.dart';
import 'state/data_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final storageService = await StorageService.init();

  // Wrap the app in ProviderScope to enable Riverpod state management as we
  // expand to multi-surface data (Firestore, caches, personalization).
  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: TripGenieApp(storageService: storageService),
    ),
  );
}

class TripGenieApp extends ConsumerStatefulWidget {
  final StorageService storageService;

  const TripGenieApp({super.key, required this.storageService});

  @override
  ConsumerState<TripGenieApp> createState() => _TripGenieAppState();
}

class _TripGenieAppState extends ConsumerState<TripGenieApp> {
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
    // Sign out current Firebase user to reset per-user Firestore scope.
    await ref.read(firebaseAuthProvider).signOut();
    setState(() {
      _hasApiKey = false;
      _apiKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Trigger anonymous auth if needed so Firestore can scope user data.
    final authWarmup = ref.watch(ensureSignedInProvider);
    ref.watch(appBootstrapProvider);

    if (authWarmup.isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
              apiKey: _apiKey!,
              onLogout: _onLogout,
            )
          : ApiKeySetupScreen(onApiKeySaved: _onApiKeySaved),
    );
  }
}
