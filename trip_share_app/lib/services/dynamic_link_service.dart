import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';

class DynamicLinkService {
  // Smart redirect endpoint that detects if app is installed
  static const String _baseUrl = 'https://ceylon-trip-share-ytdf.vercel.app';
  static const String _apiEndpoint = '$_baseUrl/api/tour-link';

  /// Generate a shareable link that detects app installation
  /// If app is installed → opens in app
  /// If app not installed → opens web version
  Future<String> generateTourShareLink(Tour tour) async {
    try {
      debugPrint('🔗 Generating smart share link for tour: ${tour.id}');

      // Create link to smart redirect API that handles app detection
      final shareUrl =
          '$_apiEndpoint'
          '?tourId=${tour.id}'
          '&name=${Uri.encodeComponent(tour.name)}'
          '&price=${tour.price.toInt()}'
          '&location=${Uri.encodeComponent(tour.startLocation)}';

      debugPrint('✅ Smart share link generated: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('⚠️ Error generating share link: $e');
      return _baseUrl;
    }
  }

  /// Initialize deep link listening for when app is opened via the landing page
  Future<void> initDynamicLinks(
    Function(String tourId) onTourLinkReceived,
  ) async {
    try {
      debugPrint('✅ Dynamic links listener initialized');
      // Deep link handling is done through Android intent filters and iOS universal links
      // The smart redirect page passes tourId to the app via tripshare:// custom scheme
    } catch (e) {
      debugPrint('⚠️ Error initializing dynamic links: $e');
    }
  }

  /// Listen for incoming deep links (when app is running)
  void listenToDynamicLinks(Function(String tourId) onTourLinkReceived) {
    try {
      debugPrint('📱 Listening for deep links...');
      // Deep link parsing happens in Android/iOS native code
      // and through the tripshare:// custom URL scheme
    } catch (e) {
      debugPrint('⚠️ Error listening to dynamic links: $e');
    }
  }

  /// Extract tour ID from deep link URL
  void _handleDeepLink(Uri link, Function(String tourId) onTourLinkReceived) {
    try {
      debugPrint('🔗 Parsing deep link: $link');

      // Extract tour ID from query parameters
      // Link format: tripshare://tour?tourId=ABC123&name=...&price=...
      final tourId = link.queryParameters['tourId'];

      if (tourId != null && tourId.isNotEmpty) {
        debugPrint('✅ Tour ID extracted: $tourId');
        onTourLinkReceived(tourId);
        return;
      }

      debugPrint('⚠️ No valid tour ID found in deep link');
    } catch (e) {
      debugPrint('⚠️ Error parsing deep link: $e');
    }
  }

  /// Generate tour share message with smart detection link
  Future<String> getTourShareMessage(Tour tour) async {
    try {
      final shareLink = await generateTourShareLink(tour);
      return 'Check out this amazing tour: ${tour.name}\n'
          '💰 PKR ${tour.price.toInt()} per person\n'
          '📍 ${tour.startLocation}\n'
          '📅 Available seats: ${tour.remainingSeats}/${tour.totalSeats}\n\n'
          '$shareLink';
    } catch (e) {
      debugPrint('⚠️ Error creating share message: $e');
      return 'Check out this tour: ${tour.name}\n$_baseUrl';
    }
  }
}
