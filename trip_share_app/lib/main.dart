import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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

/// Global navigator key for reliable navigation from anywhere (including deep links)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize chat cache service
  await ChatCacheService().init();

  // Show errors on screen instead of a white/blank screen.
  // Build a simple error widget so uncaught Flutter errors are visible.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'An unexpected error occurred',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    // Preserve default behavior (prints to console) and also surface the
    // error via the error widget above.
    FlutterError.presentError(details);
  };

  // Run the app inside a guarded zone to catch async errors as well.
  runZonedGuarded(
    () {
      runApp(
        ChangeNotifierProvider(
          create: (_) => AuthService(),
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('🛑 Uncaught error (zone): $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ceylon Shared Tours',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: DesignColors.primary,
          secondary: DesignColors.accent,
          surface: DesignColors.surface,
          background: DesignColors.background,
          error: DesignColors.error,
          onPrimary: Colors.white,
          onSecondary: DesignColors.textPrimary,
          onSurface: DesignColors.textPrimary,
          onBackground: DesignColors.textPrimary,
          onError: Colors.white,
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
  // Keep AppLinks instance alive so stream subscription isn't garbage collected
  late final AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();

    // Initialize services after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        NotificationService().setRootContext(context);
        BookingDeadlineService().startMonitoring();

        // Initialize deep link listener FIRST (so we don't miss links)
        _initializeDeepLinkListener();

        // Then check for initial deep link (when app is cold-launched from a link)
        await _checkInitialDeepLink();

        debugPrint('✅ App services initialized');
      } catch (e) {
        debugPrint('⚠️ Error initializing services: $e');
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Check for initial deep link when app is launched
  Future<void> _checkInitialDeepLink() async {
    try {
      final initialLink = await _appLinks.getInitialAppLink();

      if (initialLink != null) {
        debugPrint('🔗 Initial deep link detected: $initialLink');
        _handleDeepLink(initialLink.toString());
      } else {
        debugPrint('✅ No initial deep link');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking initial deep link: $e');
    }
  }

  /// Listen for deep links while app is running
  void _initializeDeepLinkListener() {
    try {
      debugPrint('🔗 Setting up deep link listener');

      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          debugPrint('🔗 Deep link received while running: $uri');
          _handleDeepLink(uri.toString());
        },
        onError: (error) {
          debugPrint('⚠️ Deep link stream error: $error');
        },
      );

      debugPrint('✅ Deep link listener initialized');
    } catch (e) {
      debugPrint('⚠️ Error initializing deep link listener: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(String deepLink) {
    try {
      debugPrint('📱 Handling deep link: $deepLink');

      final uri = Uri.parse(deepLink);
      String? tourId;

      if (uri.scheme == 'tripshare') {
        // Custom scheme: tripshare://tour/ABC123
        // In this URI format, 'tour' is the HOST, and 'ABC123' is pathSegments[0]
        if (uri.host == 'tour' && uri.pathSegments.isNotEmpty) {
          tourId = uri.pathSegments[0];
          debugPrint('✅ Extracted tour ID from custom scheme path: $tourId');
        }
        // Also handle tripshare://tour?tourId=ABC123 (query param fallback)
        if (tourId == null || tourId.isEmpty) {
          tourId = uri.queryParameters['tourId'];
          if (tourId != null) {
            debugPrint('✅ Extracted tour ID from custom scheme query: $tourId');
          }
        }
      } else if (uri.scheme == 'https' || uri.scheme == 'http') {
        // HTTPS App Link: https://ceylon-trip-share-ytdf.vercel.app/tour/ABC123
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'tour' &&
            uri.pathSegments.length > 1) {
          tourId = uri.pathSegments[1];
          debugPrint('✅ Extracted tour ID from https path: $tourId');
        }
        // Fallback: https://...?tourId=ABC123
        if (tourId == null || tourId.isEmpty) {
          tourId = uri.queryParameters['tourId'];
          if (tourId != null) {
            debugPrint('✅ Extracted tour ID from https query: $tourId');
          }
        }
      } else {
        // Unknown scheme — try generic parsing
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0] == 'tour' &&
            uri.pathSegments.length > 1) {
          tourId = uri.pathSegments[1];
        }
        tourId ??= uri.queryParameters['tourId'];
        if (tourId != null) {
          debugPrint('✅ Extracted tour ID from generic parse: $tourId');
        }
      }

      if (tourId != null && tourId.isNotEmpty) {
        debugPrint('🚀 Tour ID found: $tourId — navigating...');
        _navigateToTour(tourId);
      } else {
        debugPrint('⚠️ No tour ID found in deep link: $deepLink');
      }
    } catch (e) {
      debugPrint('⚠️ Error handling deep link: $e');
    }
  }

  /// Navigate to tour using the global navigator key (works even during cold start)
  Future<void> _navigateToTour(String tourId) async {
    debugPrint('🚀 _navigateToTour called with: $tourId');

    // Wait for the navigator to be ready (short delay for cold starts)
    for (int i = 0; i < 10; i++) {
      if (navigatorKey.currentContext != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
      debugPrint('⏳ Waiting for navigator... attempt ${i + 1}');
    }

    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('⚠️ Navigator context still null after waiting');
      return;
    }

    try {
      debugPrint('🚀 Fetching tour $tourId from Firestore...');
      await DeepLinkNavigationService.navigateToTourWithRoute(
        navContext,
        tourId,
      );
      debugPrint('✅ Navigation to tour complete');
    } catch (e) {
      debugPrint('⚠️ Error navigating to tour: $e');
    }
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
