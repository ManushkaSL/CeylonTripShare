import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/services/tour_service.dart';

class DeepLinkNavigationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Tour?> _loadTour(String tourId) async {
    // Shared active-tour links contain the occurrence ID. This is especially
    // important for private tours because they are intentionally absent from
    // the public Active Tours list.
    final instanceDoc = await _firestore
        .collection('tour_instances')
        .doc(tourId)
        .get();
    if (instanceDoc.exists) {
      return TourService().parseTour(instanceDoc.data()!, instanceDoc.id);
    }

    // Idle/template links continue to work as before.
    final templateDoc = await _firestore.collection('tours').doc(tourId).get();
    if (templateDoc.exists) {
      return TourService().parseTour(templateDoc.data()!, templateDoc.id);
    }
    return null;
  }

  /// Navigate to tour detail screen from deep link
  static Future<void> navigateToTour(
    BuildContext context,
    String tourId,
  ) async {
    try {
      final tour = await _loadTour(tourId);

      if (tour == null) {
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
      final tour = await _loadTour(tourId);

      if (tour == null) {
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
