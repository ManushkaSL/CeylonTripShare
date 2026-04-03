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
    // Chat is always available once the tour is booked
    return true;
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

  /// Get the count of actual passengers (bookings) for a specific tour across ALL users
  /// Queries Firestore to get the true passenger count
  Future<int> getPassengerCountForTour(String tourId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('tourId', isEqualTo: tourId)
          .get();

      int totalPassengers = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final totalPersons = data['totalPersons'] as int? ?? 0;
        totalPassengers += totalPersons;
      }

      debugPrint('✅ Total passengers for tour $tourId: $totalPassengers');
      return totalPassengers;
    } catch (e) {
      debugPrint('⚠️ Error getting passenger count for tour $tourId: $e');
      return 0;
    }
  }

  /// Monitor chat availability every 10 seconds
  /// This ensures the UI updates quickly when booking deadline is reached
  void _startChatAvailabilityMonitoring() {
    _chatAvailabilityTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Trigger UI rebuild to check updated isChatAvailable status
      notifyListeners();
    });
    debugPrint('⏱️ Chat availability monitoring started (10 sec interval)');
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

      if (dateStr == null || timeStr == null) {
        return null;
      }

      // Parse date: "2026-03-28"
      final date = DateTime.parse(dateStr);

      // Parse time: "10:29 PM" or "10 PM" or "2 PM"
      // Extract hour and minute
      final timeParts = timeStr.trim().split(RegExp(r'[\s:]'));

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = 0;

      // Check if there's minute info
      if (timeParts.length > 1) {
        // Check if second part is minute (numeric) or period (AM/PM)
        final secondPart = timeParts[1];
        if (int.tryParse(secondPart) != null) {
          minute = int.parse(secondPart);
          // Period would be in third part if present
        }
      }

      // Convert 12-hour format to 24-hour
      // Check if time contains "PM" in the original string
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');

      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      // Combine into DateTime
      final closeDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
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

            // Parse booking close time from three fields
            final lastJoiningTime = _parseBookingCloseDateTime(tourData);

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

      debugPrint('✅ Booking saved: $bookingId');
      debugPrint('📊 Before update - Tour ${tour.id}: remainingSeats=${tour.remainingSeats}, totalSeats=${tour.totalSeats}, totalPersons=$totalPersons');

      // Update tour's remainingSeats (decrement by totalPersons)
      try {
        final tourRef = _firestore.collection('tours').doc(tour.id);
        debugPrint('🔄 Attempting tour update...');
        
        // Calculate new remaining seats
        final newRemaining = (tour.remainingSeats - totalPersons).clamp(0, tour.totalSeats);
        debugPrint('   Calculation: ${tour.remainingSeats} - $totalPersons = $newRemaining (clamped 0-${tour.totalSeats})');
        
        // Set the exact value to avoid issues with FieldValue.increment
        await tourRef.update({
          'remainingSeats': newRemaining,
        });
        
        debugPrint('✅ Set remainingSeats to: $newRemaining');
        
        // Verify the update by reading the updated document
        await Future.delayed(const Duration(milliseconds: 300)); // Wait for Firestore to sync
        final updatedTour = await tourRef.get();
        final verifiedRemaining = updatedTour.data()?['remainingSeats'];
        debugPrint('✅ VERIFIED from Firestore: remainingSeats=$verifiedRemaining (type: ${verifiedRemaining.runtimeType})');
        debugPrint('📝 Raw Firestore doc: ${updatedTour.data()}');
        
      } catch (updateError) {
        debugPrint(
          '❌ Error updating tour remainingSeats for ${tour.id}: $updateError',
        );
        throw Exception(
          'Failed to update tour seats: $updateError',
        );
      }

      // Add to in-memory storage
      _joinedTours.add(
        JoinedTour(tour: tour, joinedAt: DateTime.now(), persons: totalPersons),
      );

      // Add to bookings list
      _bookings.add(booking);

      notifyListeners();
      debugPrint('✅ Booking completed successfully: $bookingId');
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
