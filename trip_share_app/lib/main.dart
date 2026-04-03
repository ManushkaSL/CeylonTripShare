import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:trip_share_app/firebase_options.dart';
import 'package:trip_share_app/screens/home_screen.dart';
import 'package:trip_share_app/screens/driver_dashboard_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/notification_service.dart';
import 'package:trip_share_app/services/booking_deadline_service.dart';
import 'package:trip_share_app/services/chat_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize chat cache service
  await ChatCacheService().init();

  runApp(
    ChangeNotifierProvider(create: (_) => AuthService(), child: const MyApp()),
  );
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

    // Initialize services after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        NotificationService().setRootContext(context);
        BookingDeadlineService().startMonitoring();
        debugPrint('✅ App services initialized');
      } catch (e) {
        debugPrint('⚠️ Error initializing services: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 AppInitializer building');

    return Consumer<AuthService>(
      builder: (context, authService, _) {
        debugPrint(
          '🔄 Consumer update - isLoggedIn: ${authService.isLoggedIn}, '
          'isDriver: ${authService.isDriver}, isCheckingDriver: ${authService.isCheckingDriver}',
        );

        // Show loading screen while checking driver status
        if (authService.isLoggedIn && authService.isCheckingDriver) {
          debugPrint('⏳ Checking driver status...');
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            ),
          );
        }

        // Show DriverDashboard ONLY for logged-in drivers
        if (authService.isLoggedIn && authService.isDriver) {
          debugPrint('👨‍✈️ Routing to DriverDashboardScreen');
          return const DriverDashboardScreen();
        }

        // Show HomeScreen for EVERYONE else:
        // - Logged-in passengers
        // - Non-logged-in users (can browse and view tours)
        debugPrint(
          '🏠 Routing to HomeScreen (isLoggedIn: ${authService.isLoggedIn})',
        );
        return const HomeScreen();
      },
    );
  }
}
