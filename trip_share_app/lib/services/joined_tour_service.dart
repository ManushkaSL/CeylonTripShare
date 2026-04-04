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
    _startBookingDeletionMonitoring();
  }

  final List<JoinedTour> _joinedTours = [];
  final List<Booking> _bookings = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  Timer? _chatAvailabilityTimer;
  StreamSubscription? _bookingDeletionSubscription;
  final Map<String, int> _lastSeenBookings = {}; // Track booking IDs we've seen
  final Map<String, Map<String, dynamic>> _bookingCache =
      {}; // Cache: bookingId -> {tourId, totalPersons}

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

  /// Monitor all bookings for deletions and refund seats back to tours
  /// This ensures that when bookings are deleted (from admin or console),
  /// the tour's available_seats count is automatically updated
  void _startBookingDeletionMonitoring() {
    _bookingDeletionSubscription = _firestore
        .collection('bookings')
        .snapshots()
        .listen(
          (snapshot) {
            // Get current booking IDs from snapshot
            final currentBookingIds = snapshot.docs
                .map((doc) => doc.id)
                .toSet();

            // Cache booking details for all current bookings (in case they get deleted)
            for (final doc in snapshot.docs) {
              final data = doc.data();
              _bookingCache[doc.id] = {
                'tourId': data['tourId'] as String?,
                'totalPersons': data['totalPersons'] as int? ?? 0,
              };
            }

            // Find deleted bookings by comparing with last seen bookings
            for (final deletedId in _lastSeenBookings.keys) {
              if (!currentBookingIds.contains(deletedId)) {
                // This booking was deleted! Use cached data to refund seats
                _handleDeletedBooking(deletedId);
                _bookingCache.remove(deletedId); // Clean up cache
              }
            }

            // Update last seen bookings
            _lastSeenBookings.clear();
            for (final doc in snapshot.docs) {
              _lastSeenBookings[doc.id] = 1;
            }
          },
          onError: (e) {
            debugPrint('⚠️ Error monitoring booking deletions: $e');
          },
        );

    debugPrint('🔍 Booking deletion monitoring started (real-time)');
  }

  /// Handle a deleted booking by refunding seats to the tour
  Future<void> _handleDeletedBooking(String bookingId) async {
    try {
      final cachedData = _bookingCache[bookingId];
      if (cachedData == null) {
        debugPrint('⚠️ No cached data for deleted booking: $bookingId');
        return;
      }

      final tourId = cachedData['tourId'] as String?;
      final totalPersons = cachedData['totalPersons'] as int;

      if (tourId == null || totalPersons <= 0) {
        debugPrint(
          '⚠️ Invalid cached booking data: tourId=$tourId, totalPersons=$totalPersons',
        );
        return;
      }

      debugPrint(
        '🗑️ Booking deletion detected: $bookingId (tour: $tourId, refunding $totalPersons seats)',
      );

      // Return seats to the tour (increment available_seats)
      final tourRef = _firestore.collection('tours').doc(tourId);
      final realTour = await tourRef.get();
      final realTourData = realTour.data();

      if (realTourData == null) {
        debugPrint('⚠️ Tour not found: $tourId');
        return;
      }

      final firestoreAvailableSeats =
          (realTourData['available_seats'] ?? realTourData['remainingSeats'])
              as int?;
      final firestoreTotalSeats = realTourData['totalSeats'] as int?;

      final actualAvailable = firestoreAvailableSeats ?? 0;
      final actualTotal = firestoreTotalSeats ?? 0;

      // Calculate new available seats (add back the deleted booking's seats)
      final newAvailable = (actualAvailable + totalPersons).clamp(
        0,
        actualTotal,
      );

      debugPrint(
        '   Calculation: $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
      );

      // Update available_seats in Firestore
      await tourRef.update({
        'available_seats': newAvailable,
        'remainingSeats': newAvailable,
      });

      debugPrint(
        '✅ Refunded $totalPersons seats to tour $tourId: available_seats now = $newAvailable',
      );

      // Verify the update
      await Future.delayed(const Duration(milliseconds: 300));
      final updatedTour = await tourRef.get();
      final verifiedAvailable = updatedTour.data()?['available_seats'];
      debugPrint(
        '✅ VERIFIED from Firestore: available_seats=$verifiedAvailable',
      );
    } catch (e) {
      debugPrint('❌ Error handling deleted booking: $e');
    }
  }

  @override
  void dispose() {
    _chatAvailabilityTimer?.cancel();
    _bookingDeletionSubscription?.cancel();
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
              remainingSeats:
                  tourData['available_seats'] ??
                  tourData['remainingSeats'] ??
                  0,
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

        // Cache booking details for deletion detection
        _bookingCache[doc.id] = {
          'tourId': tourId,
          'totalPersons': data['totalPersons'] as int? ?? 0,
        };

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
      debugPrint(
        '📊 Before update - Tour ${tour.id}: remainingSeats=${tour.remainingSeats}, totalSeats=${tour.totalSeats}, totalPersons=$totalPersons',
      );

      // Update tour's available_seats (decrement by totalPersons)
      try {
        final tourRef = _firestore.collection('tours').doc(tour.id);
        debugPrint('🔄 Attempting tour update...');

        // IMPORTANT: Fetch the real tour data from Firestore to get accurate available_seats
        // Don't use tour.remainingSeats from the UI object - it might be parsed incorrectly
        final realTour = await tourRef.get();
        final realTourData = realTour.data();

        if (realTourData == null) {
          throw Exception('Tour not found in Firestore: ${tour.id}');
        }

        // Try to get available_seats first (from user's Firestore), then fall back to remainingSeats
        final firestoreAvailableSeats =
            (realTourData['available_seats'] ?? realTourData['remainingSeats'])
                as int?;
        final firestoreTotalSeats =
            (realTourData['totalSeats'] ?? realTourData['available_seats'])
                as int?;

        debugPrint(
          '   📥 Real from Firestore: available_seats=$firestoreAvailableSeats, totalSeats=$firestoreTotalSeats',
        );
        debugPrint(
          '   📱 From UI object: remainingSeats=${tour.remainingSeats}, totalSeats=${tour.totalSeats}',
        );

        // Use Firestore values or fall back to tour object
        final actualAvailable = firestoreAvailableSeats ?? tour.remainingSeats;
        final actualTotal = firestoreTotalSeats ?? tour.totalSeats;

        // Calculate new available seats
        final newAvailable = (actualAvailable - totalPersons).clamp(
          0,
          actualTotal,
        );
        debugPrint(
          '   Calculation: $actualAvailable - $totalPersons = $newAvailable (clamped 0-$actualTotal)',
        );

        // Update available_seats field in Firestore
        await tourRef.update({
          'available_seats': newAvailable,
          'remainingSeats':
              newAvailable, // Also update remainingSeats for consistency
        });

        debugPrint('✅ Updated available_seats to: $newAvailable');

        // Verify the update by reading the updated document
        await Future.delayed(
          const Duration(milliseconds: 300),
        ); // Wait for Firestore to sync
        final updatedTour = await tourRef.get();
        final verifiedAvailable = updatedTour.data()?['available_seats'];
        debugPrint(
          '✅ VERIFIED from Firestore: available_seats=$verifiedAvailable (type: ${verifiedAvailable.runtimeType})',
        );
        debugPrint('📝 Raw Firestore doc: ${updatedTour.data()}');
      } catch (updateError) {
        debugPrint(
          '❌ Error updating tour available_seats for ${tour.id}: $updateError',
        );
        throw Exception('Failed to update tour seats: $updateError');
      }

      // Add to in-memory storage
      _joinedTours.add(
        JoinedTour(tour: tour, joinedAt: DateTime.now(), persons: totalPersons),
      );

      // Add to bookings list
      _bookings.add(booking);

      // Cache booking details for deletion detection
      _bookingCache[bookingId] = {
        'tourId': tour.id,
        'totalPersons': totalPersons,
      };

      notifyListeners();
      debugPrint('✅ Booking completed successfully: $bookingId');
    } catch (e) {
      debugPrint('❌ Error saving booking: $e');
    }
  }

  /// Cancel a booking and return seats to the tour
  Future<void> cancelBooking(String bookingId) async {
    try {
      // Get booking details before deleting
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        debugPrint('⚠️ Booking not found: $bookingId');
        return;
      }

      final bookingData = bookingDoc.data();
      final tourId = bookingData?['tourId'] as String?;
      final totalPersons = bookingData?['totalPersons'] as int? ?? 0;

      if (tourId == null || totalPersons <= 0) {
        debugPrint(
          '⚠️ Invalid booking data for cancellation: tourId=$tourId, totalPersons=$totalPersons',
        );
        return;
      }

      debugPrint(
        '🔄 Cancelling booking: $bookingId from tour: $tourId, refunding $totalPersons seats',
      );

      // Delete the booking
      await _firestore.collection('bookings').doc(bookingId).delete();
      debugPrint('✅ Booking deleted: $bookingId');

      // Return seats to the tour (increment available_seats)
      try {
        final tourRef = _firestore.collection('tours').doc(tourId);
        final realTour = await tourRef.get();
        final realTourData = realTour.data();

        if (realTourData == null) {
          throw Exception('Tour not found in Firestore: $tourId');
        }

        final firestoreAvailableSeats =
            (realTourData['available_seats'] ?? realTourData['remainingSeats'])
                as int?;
        final firestoreTotalSeats = realTourData['totalSeats'] as int?;

        debugPrint(
          '   📥 Real from Firestore: available_seats=$firestoreAvailableSeats, totalSeats=$firestoreTotalSeats',
        );

        final actualAvailable = firestoreAvailableSeats ?? 0;
        final actualTotal = firestoreTotalSeats ?? 0;

        // Calculate new available seats (add back the cancelled seats)
        final newAvailable = (actualAvailable + totalPersons).clamp(
          0,
          actualTotal,
        );
        debugPrint(
          '   Calculation: $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
        );

        // Update available_seats in Firestore
        await tourRef.update({
          'available_seats': newAvailable,
          'remainingSeats': newAvailable,
        });

        debugPrint(
          '✅ Refunded seats to tour: available_seats updated to $newAvailable',
        );

        // Verify the update
        await Future.delayed(const Duration(milliseconds: 300));
        final updatedTour = await tourRef.get();
        final verifiedAvailable = updatedTour.data()?['available_seats'];
        debugPrint(
          '✅ VERIFIED from Firestore: available_seats=$verifiedAvailable',
        );
      } catch (updateError) {
        debugPrint('❌ Error updating tour available_seats: $updateError');
        throw Exception('Failed to return seats to tour: $updateError');
      }

      // Update in-memory lists
      _bookings.removeWhere((b) => b.id == bookingId);
      _joinedTours.removeWhere((jt) => jt.tour.id == tourId);

      notifyListeners();
      debugPrint('✅ Booking cancellation completed: $bookingId');
    } catch (e) {
      debugPrint('❌ Error cancelling booking: $e');
      rethrow;
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
