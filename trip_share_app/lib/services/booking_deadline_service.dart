import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/services/notification_service.dart';

class BookingDeadlineService {
  static final BookingDeadlineService _instance =
      BookingDeadlineService._internal();

  factory BookingDeadlineService() {
    return _instance;
  }

  BookingDeadlineService._internal({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService = NotificationService();
  final Set<String> _notifiedTours = {};

  /// Parse booking close date and time fields into DateTime
  DateTime? _parseBookingCloseDateTime(Map<String, dynamic> tourData) {
    try {
      final dateStr = tourData['booking_close_date'] as String?;
      final timeStr = tourData['booking_close_time'] as String?;
      final periodStr = tourData['booking_close_period'] as String?;

      if (dateStr == null || timeStr == null || periodStr == null) {
        return null;
      }

      // Parse date: "2026-03-20"
      final date = DateTime.parse(dateStr);

      // Parse time: "2" or "02" and period: "AM" or "PM"
      int hour = int.parse(timeStr.replaceAll(RegExp(r'\D'), ''));

      // Convert 12-hour format to 24-hour
      if (periodStr.toUpperCase() == 'PM' && hour != 12) {
        hour += 12;
      } else if (periodStr.toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }

      // Combine into DateTime
      final closeDateTime = DateTime(date.year, date.month, date.day, hour, 0);
      return closeDateTime;
    } catch (e) {
      debugPrint('⚠️ Error parsing booking close time: $e');
      return null;
    }
  }

  /// Start monitoring booking deadlines
  /// This should be called once in the app initialization
  void startMonitoring() {
    debugPrint('🔔 Starting booking deadline monitoring...');
    _checkDeadlines();

    // Check every 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      _checkDeadlines();
    });
  }

  /// Check all tours for passed deadlines
  Future<void> _checkDeadlines() async {
    try {
      final now = DateTime.now();

      debugPrint('⏰ Checking booking deadlines at $now');

      final toursSnapshot = await _firestore.collection('tours').get();

      for (final tourDoc in toursSnapshot.docs) {
        final tourData = tourDoc.data();
        final tourId = tourDoc.id;
        final tourName = tourData['name'] as String? ?? 'Tour';

        // Parse booking close time from three fields
        final bookingCloseTime = _parseBookingCloseDateTime(tourData);

        // Check if deadline has passed and we haven't notified yet
        if (bookingCloseTime != null &&
            now.isAfter(bookingCloseTime) &&
            !_notifiedTours.contains(tourId)) {
          await _notifyDeadlinePassed(tourId, tourName);
          _notifiedTours.add(tourId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking deadlines: $e');
    }

    // Schedule next check
    Future.delayed(const Duration(minutes: 5), () {
      _checkDeadlines();
    });
  }

  /// Notify about a deadline that has passed
  Future<void> _notifyDeadlinePassed(String tourId, String tourName) async {
    try {
      debugPrint('✅ Deadline passed for tour: $tourName');

      // Chat notification removed - using silent deadline passing
      // You can add push notification here later if needed
    } catch (e) {
      debugPrint('❌ Error notifying deadline pass: $e');
    }
  }

  /// Get the status of a specific tour deadline
  Future<bool> isDeadlinePassed(String tourId) async {
    try {
      final tourDoc = await _firestore.collection('tours').doc(tourId).get();

      if (!tourDoc.exists) return false;

      final tourData = tourDoc.data() ?? {};
      final bookingCloseTime = _parseBookingCloseDateTime(tourData);

      if (bookingCloseTime == null) return false;

      return DateTime.now().isAfter(bookingCloseTime);
    } catch (e) {
      debugPrint('❌ Error checking if deadline passed: $e');
      return false;
    }
  }

  /// Get remaining time until deadline for a tour
  Future<Duration?> getTimeUntilDeadline(String tourId) async {
    try {
      final tourDoc = await _firestore.collection('tours').doc(tourId).get();

      if (!tourDoc.exists) return null;

      final tourData = tourDoc.data() ?? {};
      final bookingCloseTime = _parseBookingCloseDateTime(tourData);

      if (bookingCloseTime == null) return null;

      final now = DateTime.now();
      if (now.isAfter(bookingCloseTime)) {
        return Duration.zero;
      }

      return bookingCloseTime.difference(now);
    } catch (e) {
      debugPrint('❌ Error getting time until deadline: $e');
      return null;
    }
  }

  /// Manual notification trigger for testing
  void testNotification(String tourName) {
    _notificationService.showBanner(
      '✅ Test: Chat unlocked for $tourName!',
      backgroundColor: Colors.green,
    );
  }
}
