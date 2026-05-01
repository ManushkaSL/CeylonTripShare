import 'package:flutter/material.dart';
import 'package:trip_share_app/theme/design_system.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:trip_share_app/firebase_options.dart';
import 'package:trip_share_app/screens/home_screen.dart';
import 'package:trip_share_app/screens/driver_dashboard_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/notification_service.dart';
import 'package:trip_share_app/services/booking_deadline_service.dart';
import 'package:trip_share_app/services/chat_cache_service.dart';
import 'package:trip_share_app/services/dynamic_link_service.dart';
import 'package:trip_share_app/services/deep_link_navigation_service.dart';

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
        colorScheme: const ColorScheme.dark(
          primary: DesignColors.primary,
          secondary: DesignColors.accent,
          surface: DesignColors.surface,
          background: DesignColors.background,
          error: DesignColors.error,
          onPrimary: DesignColors.textPrimary,
          onSecondary: DesignColors.textPrimary,
          onSurface: DesignColors.textPrimary,
          onBackground: DesignColors.textPrimary,
          onError: DesignColors.textPrimary,
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        NotificationService().setRootContext(context);
        BookingDeadlineService().startMonitoring();

        // Initialize dynamic links
        await _initializeDynamicLinks();

        debugPrint('✅ App services initialized');
      } catch (e) {
        debugPrint('⚠️ Error initializing services: $e');
      }
    });
  }

  /// Initialize Firebase Dynamic Links for deep link handling
  Future<void> _initializeDynamicLinks() async {
    final dynamicLinkService = DynamicLinkService();

    // Initialize dynamic links and set callback
    await dynamicLinkService.initDynamicLinks((tourId) {
      if (mounted) {
        _navigateToTourFromDeepLink(tourId);
      }
    });
  }

  /// Navigate to tour when deep link is received
  Future<void> _navigateToTourFromDeepLink(String tourId) async {
    if (!mounted) return;

    // Add a small delay to ensure context is ready
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Use the deep link navigation service
    await DeepLinkNavigationService.navigateToTourWithRoute(context, tourId);
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
            backgroundColor: DesignColors.background,
            body: const Center(
              child: CircularProgressIndicator(color: DesignColors.primary),
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
