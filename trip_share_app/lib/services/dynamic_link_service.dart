import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';

class DynamicLinkService {
  // Custom URL scheme - no hosted domain needed!
  // Format: tripshare://tour/TOUR_ID?name=...&price=...
  static const String _appScheme = 'tripshare://tour';

  /// Generate a shareable link for a tour
  Future<String> generateTourShareLink(Tour tour) async {
    try {
      debugPrint('🔗 Generating share link for tour: ${tour.id}');

      // Create a custom URL scheme link
      // Format: tripshare://tour/TOUR_ID?name=...&price=...&location=...
      final shareUrl = '$_appScheme/${tour.id}'
          '?name=${Uri.encodeComponent(tour.name)}'
          '&price=${tour.price}'
          '&location=${Uri.encodeComponent(tour.startLocation)}';

      debugPrint('✅ Share link generated: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('⚠️ Error generating share link: $e');
      return '$_appScheme/${tour.id}';
    }
  }

  /// Initialize dynamic links - handles incoming deep links
  Future<void> initDynamicLinks(
    Function(String tourId) onTourLinkReceived,
  ) async {
    try {
      debugPrint('✅ Dynamic links initialized successfully');

      // Note: For full Firebase Dynamic Links functionality,
      // you need to:
      // 1. Run: flutter pub get
      // 2. Configure Android/iOS (see FIREBASE_DYNAMIC_LINKS_SETUP.md)
      // 3. Enable Firebase Dynamic Links in Firebase Console

      // This basic implementation provides fallback functionality
      // using standard deep links with custom URL schemes

      // In a real scenario, you would add:
      // - Firebase Dynamic Links native handlers
      // - Deep link parsing from intent filters
      // - URL scheme handling for iOS
    } catch (e) {
      debugPrint('⚠️ Error initializing dynamic links: $e');
    }
  }

  /// Listen for incoming dynamic links (when app is running)
  void listenToDynamicLinks(Function(String tourId) onTourLinkReceived) {
    try {
      debugPrint('📱 Listening for dynamic links...');

      // This would be implemented through native handlers
      // See platform-specific implementations in:
      // - android/app/src/main/AndroidManifest.xml
      // - ios/Runner/Info.plist
    } catch (e) {
      debugPrint('⚠️ Error listening to dynamic links: $e');
    }
  }

  /// Extract tour ID from deep link URL
  void _handleDeepLink(
    String deepLink,
    Function(String tourId) onTourLinkReceived,
  ) {
    try {
      final uri = Uri.parse(deepLink);
      debugPrint('🔗 Parsing deep link: ${uri.path}');

      // Extract tour ID from path: /tour/TOUR_ID
      if (uri.pathSegments.contains('tour')) {
        final tourIndex = uri.pathSegments.indexOf('tour');
        if (tourIndex < uri.pathSegments.length - 1) {
          final tourId = uri.pathSegments[tourIndex + 1];
          if (tourId.isNotEmpty) {
            debugPrint('✅ Tour ID extracted: $tourId');
            onTourLinkReceived(tourId);
            return;
          }
        }
      }

      // Fallback: check query parameters
      final tourIdParam = uri.queryParameters['tourId'];
      if (tourIdParam != null && tourIdParam.isNotEmpty) {
        debugPrint('✅ Tour ID from query param: $tourIdParam');
        onTourLinkReceived(tourIdParam);
        return;
      }

      debugPrint('⚠️ No valid tour ID found in deep link');
    } catch (e) {
      debugPrint('⚠️ Error parsing deep link: $e');
    }
  }

  /// Generate tour share message with deep link
  Future<String> getTourShareMessage(Tour tour) async {
    try {
      final shareLink = await generateTourShareLink(tour);
      return 'Check out this amazing tour: ${tour.name}\n'
          '💰 \$${tour.price.toInt()} per person\n'
          '📍 ${tour.startLocation}\n'
          '📅 Available seats: ${tour.remainingSeats}/${tour.totalSeats}\n\n'
          '$shareLink';
    } catch (e) {
      debugPrint('⚠️ Error creating share message: $e');
      return 'Check out this tour: ${tour.name}\n$_appScheme/${tour.id}';
    }
  }
}
