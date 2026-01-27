import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      home: HomeScreen(storageService: widget.storageService),
    );
  }
}
