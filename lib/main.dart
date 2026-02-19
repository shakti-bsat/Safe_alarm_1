import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Start the app immediately without waiting for heavy initialization
  runApp(const SafeAlarmApp());
}

class SafeAlarmApp extends StatelessWidget {
  const SafeAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeAlarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _isLoading = true;
  bool _isSetupDone = false;

  @override
  void initState() {
    super.initState();
    // Initialize everything after the first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Start Firebase and notification initialization in parallel
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      NotificationService.initialize(),
    ]);

    // Check if setup is done
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool('setup_complete') ?? false;

    if (mounted) {
      setState(() {
        _isSetupDone = setupDone;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _isSetupDone ? const HomeScreen() : const SetupScreen();
  }
}
