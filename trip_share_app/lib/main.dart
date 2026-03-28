import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trip_share_app/firebase_options.dart';
import 'package:trip_share_app/screens/home_screen.dart';
import 'package:trip_share_app/services/notification_service.dart';
import 'package:trip_share_app/services/booking_deadline_service.dart';
import 'package:trip_share_app/services/chat_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize chat cache service
  await ChatCacheService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ceylon Shared Tours',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();

    // Initialize notification service with context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().setRootContext(context);

      // Start monitoring booking deadlines
      BookingDeadlineService().startMonitoring();

      debugPrint('✅ App services initialized');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
