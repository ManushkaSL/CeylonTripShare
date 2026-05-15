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

        // Check for initial deep link FIRST (when app is launched from a link)
        await _checkInitialDeepLink();

        // Initialize deep link listener for new links
        _initializeDeepLinkListener();

        debugPrint('✅ App services initialized');
      } catch (e) {
        debugPrint('⚠️ Error initializing services: $e');
      }
    });
  }

  /// Check for initial deep link when app is launched
  Future<void> _checkInitialDeepLink() async {
    try {
      final appLinks = AppLinks();
      final initialAppLink = await appLinks.getInitialAppLink();

      if (initialAppLink != null) {
        debugPrint('🔗 Initial deep link detected: $initialAppLink');
        await Future.delayed(const Duration(milliseconds: 100));
        _handleDeepLink(initialAppLink.toString());
      } else {
        debugPrint('✅ No initial deep link');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking initial deep link: $e');
    }
  }

  /// Listen for deep links via custom URL scheme (tripshare://)
  void _initializeDeepLinkListener() {
    try {
      debugPrint('🔗 Setting up deep link listener');

      final appLinks = AppLinks();

      // Listen for new links while app is running
      appLinks.uriLinkStream.listen(
        (uri) {
          debugPrint('🔗 Deep link received: $uri');
          _handleDeepLink(uri.toString());
        },
        onError: (error) {
          debugPrint('⚠️ Deep link error: $error');
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
          debugPrint('✅ Extracted tour ID from custom scheme: $tourId');
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
        // Fallback: https://...?tourId=ABC123 or /api/tour-link?tourId=ABC123
        if (tourId == null || tourId.isEmpty) {
          tourId = uri.queryParameters['tourId'];
          if (tourId != null) {
            debugPrint('✅ Extracted tour ID from https query: $tourId');
          }
        }
      } else {
        // Unknown scheme — try generic parsing
        if (uri.pathSegments.isNotEmpty) {
          if (uri.pathSegments[0] == 'tour' && uri.pathSegments.length > 1) {
            tourId = uri.pathSegments[1];
          }
        }
        if (tourId == null || tourId.isEmpty) {
          tourId = uri.queryParameters['tourId'];
        }
        if (tourId != null) {
          debugPrint('✅ Extracted tour ID from generic parse: $tourId');
        }
      }

      if (tourId != null && tourId.isNotEmpty) {
        debugPrint('✅ Valid tour ID found: $tourId');
        if (mounted) {
          _navigateToTourFromDeepLink(tourId);
        }
      } else {
        debugPrint('⚠️ No tour ID found in deep link: $deepLink');
      }
    } catch (e) {
      debugPrint('⚠️ Error handling deep link: $e');
    }
  }

  /// Navigate to tour when deep link is received
  Future<void> _navigateToTourFromDeepLink(String tourId) async {
    if (!mounted) {
      debugPrint('⚠️ Widget not mounted, cannot navigate');
      return;
    }

    // Wait for widget to be fully built
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) {
      debugPrint('⚠️ Widget unmounted during navigation delay');
      return;
    }

    debugPrint('🚀 Navigating to tour: $tourId');

    try {
      // Use the deep link navigation service
      await DeepLinkNavigationService.navigateToTourWithRoute(context, tourId);
    } catch (e) {
      debugPrint('⚠️ Error navigating to tour: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open tour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
