import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';

class DynamicLinkService {
  // Landing page URL - handles device detection and app opening
  static const String _landingPageUrl =
      'https://ceylon-trip-share-ytdf.vercel.app';

  /// Generate a shareable link for a tour
  /// Simply directs to landing page with tour ID in URL
  Future<String> generateTourShareLink(Tour tour) async {
    try {
      debugPrint('🔗 Generating share link for tour: ${tour.id}');

      // Create link with tour details as query parameters
      final shareUrl =
          '$_landingPageUrl?tourId=${tour.id}'
          '&name=${Uri.encodeComponent(tour.name)}'
          '&price=${tour.price.toInt()}'
          '&location=${Uri.encodeComponent(tour.startLocation)}';

      debugPrint('✅ Share link generated: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('⚠️ Error generating share link: $e');
      return _landingPageUrl;
    }
  }

  /// Initialize deep link listening for when app is opened via the landing page
  Future<void> initDynamicLinks(
    Function(String tourId) onTourLinkReceived,
  ) async {
    try {
      debugPrint('✅ Dynamic links listener initialized');
      // Deep link handling is done through Android intent filters and iOS universal links
      // The landing page will pass tourId to the app via tripshare:// custom scheme
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

  /// Generate tour share message with link
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
      return 'Check out this tour: ${tour.name}\n$_landingPageUrl';
    }
  }
}
