import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/services/tour_service.dart';

class DeepLinkNavigationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Navigate to tour detail screen from deep link
  static Future<void> navigateToTour(
    BuildContext context,
    String tourId,
  ) async {
    try {
      // Fetch tour from Firestore
      final tourDoc = await _firestore.collection('tours').doc(tourId).get();

      if (!tourDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tour not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final tourData = tourDoc.data() as Map<String, dynamic>;
      final tour = TourService().parseTour(tourData, tourDoc.id);

      // Navigate to tour detail screen
      if (context.mounted) {
        Navigator.of(context).pushNamed('/tour', arguments: tour);
      }
    } catch (e) {
      debugPrint('Error navigating to tour: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navigate to tour using PageRoute (if named routes don't work)
  static Future<void> navigateToTourWithRoute(
    BuildContext context,
    String tourId,
  ) async {
    try {
      // Fetch tour from Firestore
      final tourDoc = await _firestore.collection('tours').doc(tourId).get();

      if (!tourDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tour not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final tourData = tourDoc.data() as Map<String, dynamic>;
      final tour = TourService().parseTour(tourData, tourDoc.id);

      // Navigate using MaterialPageRoute
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)));
      }
    } catch (e) {
      debugPrint('Error navigating to tour: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
