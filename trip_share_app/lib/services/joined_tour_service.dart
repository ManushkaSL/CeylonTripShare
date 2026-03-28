import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/models/booking.dart';
import 'package:trip_share_app/services/auth_service.dart';

enum JourneyStatus { notStarted, inProgress }

class JoinedTour {
  final Tour tour;
  final DateTime joinedAt;
  final int persons;
  JourneyStatus journeyStatus;

  JoinedTour({
    required this.tour,
    required this.joinedAt,
    required this.persons,
    this.journeyStatus = JourneyStatus.notStarted,
  });

  bool get isChatAvailable {
    if (tour.lastJoiningTime == null) {
      debugPrint(
        '❌ Chat unavailable for "${tour.name}": lastJoiningTime is NULL',
      );
      return false;
    }

    final isAfter = DateTime.now().isAfter(tour.lastJoiningTime!);
    debugPrint(
      '🔔 [${tour.name}] Chat check: now=${DateTime.now()}, close=${tour.lastJoiningTime}, available=$isAfter',
    );
    return isAfter;
  }

  bool get isLiveLocationAvailable => journeyStatus == JourneyStatus.inProgress;
}

class JoinedTourService extends ChangeNotifier {
  static final JoinedTourService _instance = JoinedTourService._();
  factory JoinedTourService() => _instance;
  JoinedTourService._() {
    _initializeAuthListener();
    _startChatAvailabilityMonitoring();
  }

  final List<JoinedTour> _joinedTours = [];
  final List<Booking> _bookings = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  Timer? _chatAvailabilityTimer;

  List<JoinedTour> get joinedTours => List.unmodifiable(_joinedTours);
  List<Booking> get bookings => List.unmodifiable(_bookings);

  /// Monitor chat availability every minute
  /// This ensures the UI updates when booking deadline is reached
  void _startChatAvailabilityMonitoring() {
    _chatAvailabilityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Trigger UI rebuild to check updated isChatAvailable status
      notifyListeners();
    });
    debugPrint('⏱️ Chat availability monitoring started');
  }

  @override
  void dispose() {
    _chatAvailabilityTimer?.cancel();
    super.dispose();
  }

  /// Parse booking close date and time fields into DateTime
  DateTime? _parseBookingCloseDateTime(Map<String, dynamic> tourData) {
    try {
      final dateStr = tourData['booking_close_date'] as String?;
      final timeStr = tourData['booking_close_time'] as String?;
      final periodStr = tourData['booking_close_period'] as String?;

      debugPrint('=== 📅 BOOKING CLOSE TIME DEBUG ===');
      debugPrint('Raw Firestore data: date=$dateStr, time=$timeStr, period=$periodStr');

      if (dateStr == null || timeStr == null || periodStr == null) {
        debugPrint('❌ Missing fields: date=$dateStr, time=$timeStr, period=$periodStr');
        return null;
      }

      // Parse date: "2026-03-20"
      final date = DateTime.parse(dateStr);
      debugPrint('Parsed date: $date');

      // Parse time: "2" or "02" and period: "AM" or "PM"
      int hour = int.parse(timeStr.replaceAll(RegExp(r'\D'), ''));
      debugPrint('Extracted hour (before conversion): $hour');

      // Convert 12-hour format to 24-hour
      if (periodStr.toUpperCase() == 'PM' && hour != 12) {
        hour += 12;
      } else if (periodStr.toUpperCase() == 'AM' && hour == 12) {
        hour = 0;
      }

      debugPrint('Hour after conversion: $hour, period: $periodStr');

      // Combine into DateTime
      final closeDateTime = DateTime(date.year, date.month, date.day, hour, 0);
      final now = DateTime.now();
      final isAfter = now.isAfter(closeDateTime);

      debugPrint('Booking close DateTime: $closeDateTime');
      debugPrint('Current time: $now');
      debugPrint('Now isAfter close time: $isAfter');
      debugPrint('=== END DEBUG ===');

      return closeDateTime;
    } catch (e) {
      debugPrint('⚠️ Error parsing booking close time: $e');
      return null;
    }
  }

  /// Listen to auth state changes and reload bookings automatically
  void _initializeAuthListener() {
    _authService.addListener(() {
      final userId = _authService.userId;
      if (userId.isNotEmpty) {
        debugPrint('✅ User authenticated: $userId');
        loadBookings();
      } else {
        debugPrint('❌ User logged out');
        _joinedTours.clear();
        _bookings.clear();
        notifyListeners();
      }
    });
  }

  /// Load all bookings from Firestore for the current user
  Future<void> loadBookings() async {
    try {
      final userId = _authService.userId;
      if (userId.isEmpty) {
        debugPrint('❌ No user logged in');
        return;
      }

      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      _bookings.clear();
      _joinedTours.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tourId = data['tourId'] ?? '';

        // Fetch complete tour data from tours collection
        Tour tour = Tour(
          id: tourId,
          name: data['tourName'] ?? '',
          imageUrl: '',
          startDate: DateTime.parse(
            data['tourDate'] as String? ?? DateTime.now().toIso8601String(),
          ),
          totalSeats: 0,
          remainingSeats: 0,
          price: 0.0,
        );

        // Try to fetch full tour details with booking close time
        try {
          final tourDoc = await _firestore
              .collection('tours')
              .doc(tourId)
              .get();
          if (tourDoc.exists) {
            final tourData = tourDoc.data() ?? {};
            final tourName = tourData['name'] ?? data['tourName'] ?? tourId;
            
            debugPrint('🔍 Tour "$tourName" full data from Firestore:');
            debugPrint('  booking_close_date: ${tourData['booking_close_date']}');
            debugPrint('  booking_close_time: ${tourData['booking_close_time']}');
            debugPrint('  booking_close_period: ${tourData['booking_close_period']}');

            // Parse booking close time from three fields
            final lastJoiningTime = _parseBookingCloseDateTime(tourData);
            
            debugPrint('✅ Final lastJoiningTime for "$tourName": $lastJoiningTime');

            tour = Tour(
              id: tourId,
              name: tourData['name'] ?? data['tourName'] ?? '',
              imageUrl: tourData['imageUrl'] ?? tourData['image'] ?? '',
              startDate: DateTime.parse(
                tourData['startDate'] as String? ??
                    data['tourDate'] ??
                    DateTime.now().toIso8601String(),
              ),
              totalSeats: tourData['totalSeats'] ?? 0,
              remainingSeats: tourData['remainingSeats'] ?? 0,
              price: (tourData['price'] as num?)?.toDouble() ?? 0.0,
              description: tourData['description'] ?? '',
              photos: List<String>.from(tourData['photos'] ?? []),
              category: tourData['category'] ?? '',
              startLocation: tourData['startLocation'] ?? '',
              lastJoiningTime: lastJoiningTime,
              endTime: tourData['endTime'] ?? '',
              endLocation: tourData['endLocation'] ?? '',
              operatorName: tourData['operatorName'] ?? '',
              whatsIncluded: List<String>.from(tourData['whatsIncluded'] ?? []),
              tourFeatures: List<String>.from(tourData['tourFeatures'] ?? []),
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching full tour details for $tourId: $e');
        }

        final booking = Booking.fromMap(data, tour);
        _bookings.add(booking);

        // Add to joined tours
        _joinedTours.add(
          JoinedTour(
            tour: tour,
            joinedAt: DateTime.parse(
              data['bookedAt'] as String? ?? DateTime.now().toIso8601String(),
            ),
            persons: data['totalPersons'] ?? 0,
          ),
        );
      }

      notifyListeners();
      debugPrint(
        '✅ Loaded ${_bookings.length} bookings and ${_joinedTours.length} joined tours',
      );
    } catch (e) {
      debugPrint('❌ Error loading bookings: $e');
    }
  }

  /// Save booking to Firestore and in-memory storage
  Future<void> joinTour({
    required Tour tour,
    required int adults,
    required int kids6to12,
    required int kidsUnder6,
    required String pickupLocation,
    required double totalPrice,
    String? cardHolderName,
  }) async {
    try {
      final userId = _authService.userId;
      if (userId.isEmpty) {
        debugPrint('❌ No user logged in - cannot save booking');
        return;
      }

      // Avoid duplicate joins
      if (_joinedTours.any((jt) => jt.tour.name == tour.name)) {
        debugPrint('⚠️ Already joined this tour');
        return;
      }

      final totalPersons = adults + kids6to12 + kidsUnder6;
      final bookingId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create booking object
      final booking = Booking(
        id: bookingId,
        userId: userId,
        tour: tour,
        bookedAt: DateTime.now(),
        adults: adults,
        kids6to12: kids6to12,
        kidsUnder6: kidsUnder6,
        pickupLocation: pickupLocation,
        totalPrice: totalPrice,
        totalPersons: totalPersons,
        cardHolderName: cardHolderName,
      );

      // Save to Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .set(booking.toMap());

      // Add to in-memory storage
      _joinedTours.add(
        JoinedTour(tour: tour, joinedAt: DateTime.now(), persons: totalPersons),
      );

      // Add to bookings list
      _bookings.add(booking);

      notifyListeners();
      debugPrint('✅ Booking saved successfully: $bookingId');
    } catch (e) {
      debugPrint('❌ Error saving booking: $e');
    }
  }

  /// Stream real-time bookings from Firestore
  Stream<List<JoinedTour>> streamBookings() {
    final userId = _authService.userId;
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final joinedTours = <JoinedTour>[];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            final tour = Tour(
              id: data['tourId'] ?? '',
              name: data['tourName'] ?? '',
              imageUrl: '',
              startDate: DateTime.parse(
                data['tourDate'] as String? ?? DateTime.now().toIso8601String(),
              ),
              totalSeats: 0,
              remainingSeats: 0,
              price: 0.0,
            );

            joinedTours.add(
              JoinedTour(
                tour: tour,
                joinedAt: DateTime.parse(
                  data['bookedAt'] as String? ??
                      DateTime.now().toIso8601String(),
                ),
                persons: data['totalPersons'] ?? 0,
              ),
            );
          }

          debugPrint('🔄 Real-time update: ${joinedTours.length} bookings');
          return joinedTours;
        })
        .handleError((e) {
          debugPrint('❌ Error streaming bookings: $e');
          return [];
        });
  }

  void startJourney(String tourName) {
    final jt = _joinedTours.cast<JoinedTour?>().firstWhere(
      (jt) => jt!.tour.name == tourName,
      orElse: () => null,
    );
    if (jt != null) {
      jt.journeyStatus = JourneyStatus.inProgress;
      notifyListeners();
    }
  }

  bool isJoined(String tourName) {
    return _joinedTours.any((jt) => jt.tour.name == tourName);
  }

  List<JoinedTour> get toursWithChats {
    return _joinedTours.where((jt) => jt.isChatAvailable).toList();
  }
}
