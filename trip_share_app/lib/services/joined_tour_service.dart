import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/models/booking.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/tour_service.dart';

enum JourneyStatus { notStarted, inProgress }

class JoinedTour {
  final String bookingId;
  final Tour tour;
  final DateTime joinedAt;
  final int persons;
  JourneyStatus journeyStatus;

  JoinedTour({
    this.bookingId = '',
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
    _syncBookingDeletionMonitoring();
  }

  final List<JoinedTour> _joinedTours = [];
  final List<Booking> _bookings = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TourService _tourService = TourService();
  Timer? _chatAvailabilityTimer;
  StreamSubscription? _bookingDeletionSubscription;
  final Map<String, int> _lastSeenBookings = {}; // Track booking IDs we've seen
  final Map<String, Map<String, dynamic>> _bookingCache =
      {}; // Cache: bookingId -> {tourId, totalPersons}
  int _bookingLoadGeneration = 0;
  String _loadedUserId = '';
  String? lastError;

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

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
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
  void _syncBookingDeletionMonitoring() {
    if (_authService.userId.isEmpty) {
      _stopBookingDeletionMonitoring();
      return;
    }
    _startBookingDeletionMonitoring();
  }

  void _startBookingDeletionMonitoring() {
    if (_bookingDeletionSubscription != null) {
      return;
    }
    if (_authService.userId.isEmpty) {
      return;
    }

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
                'userId': data['userId'] as String?,
                'instanceId': data['instanceId'] as String?,
                'tourDate': data['tourDate'] as String?,
              };
            }

            // Find deleted bookings by comparing with last seen bookings
            var deletedCurrentUserBooking = false;
            for (final deletedId in _lastSeenBookings.keys) {
              if (!currentBookingIds.contains(deletedId)) {
                final cachedData = _bookingCache[deletedId];
                if (cachedData?['userId'] == _authService.userId) {
                  deletedCurrentUserBooking = true;
                  _bookings.removeWhere((booking) => booking.id == deletedId);
                  _joinedTours.removeWhere(
                    (joinedTour) => joinedTour.bookingId == deletedId,
                  );
                }
                // This booking was deleted! Use cached data to refund seats
                _handleDeletedBooking(deletedId);
                _bookingCache.remove(deletedId); // Clean up cache
              }
            }

            if (deletedCurrentUserBooking) {
              // Remove deleted-tour cards and chats immediately. Reload once
              // more from Firestore to keep passenger-linked bookings in sync.
              notifyListeners();
              loadBookings();
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

  void _stopBookingDeletionMonitoring() {
    _bookingDeletionSubscription?.cancel();
    _bookingDeletionSubscription = null;
    _lastSeenBookings.clear();
    _bookingCache.clear();
    debugPrint('🛑 Booking deletion monitoring stopped');
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
      final bookedUserId = cachedData['userId'] as String?;

      if (tourId == null || totalPersons <= 0) {
        debugPrint(
          '⚠️ Invalid cached booking data: tourId=$tourId, totalPersons=$totalPersons',
        );
        return;
      }

      debugPrint(
        '🗑️ Booking deletion detected: $bookingId (tour: $tourId, refunding $totalPersons seats)',
      );

      // If this booking belonged to an instance, refund seats to that instance
      final instanceId = cachedData['instanceId'] as String?;
      try {
        await _deleteMessagesForBookingOccurrence(
          instanceId: instanceId,
          tourId: tourId,
          tourDate: cachedData['tourDate'] as String?,
        );
      } catch (e) {
        debugPrint('Could not delete occurrence chat: $e');
      }
      if (instanceId != null && instanceId.isNotEmpty) {
        final instRef = _firestore.collection('tour_instances').doc(instanceId);
        final instDoc = await instRef.get();
        final instData = instDoc.data();
        if (instData == null) {
          debugPrint('⚠️ Instance not found: $instanceId');
          return;
        }

        final firestoreAvailableSeats = _toInt(
          instData['available_seats'] ?? instData['remainingSeats'],
        );
        final firestoreTotalSeats = _toInt(instData['totalSeats']);
        final firestoreBookedSeats = _toInt(instData['bookedSeats']);

        final actualAvailable = firestoreAvailableSeats;
        final actualTotal = firestoreTotalSeats > 0
            ? firestoreTotalSeats
            : actualAvailable + firestoreBookedSeats;

        final newAvailable = (actualAvailable + totalPersons)
            .clamp(0, actualTotal)
            .toInt();
        final newBookedSeats = (firestoreBookedSeats - totalPersons)
            .clamp(0, actualTotal)
            .toInt();

        debugPrint(
          '   Calculation (instance): $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
        );

        final instUpdate = <String, dynamic>{
          'totalSeats': actualTotal,
          'available_seats': newAvailable,
          'remainingSeats': newAvailable,
          'bookedSeats': newBookedSeats,
        };
        if (bookedUserId != null && bookedUserId.isNotEmpty) {
          instUpdate['bookedUserIds'] = FieldValue.arrayRemove([bookedUserId]);
        }
        await instRef.update(instUpdate);

        debugPrint(
          '✅ Refunded $totalPersons seats to instance $instanceId: available_seats now = $newAvailable',
        );

        await Future.delayed(const Duration(milliseconds: 300));
        final updatedInst = await instRef.get();
        final verifiedAvailable = updatedInst.data()?['available_seats'];
        debugPrint(
          '✅ VERIFIED from Firestore (instance): available_seats=$verifiedAvailable',
        );
        return;
      }

      // Return seats to the main tour as a fallback
      // Return seats to the tour (increment available_seats)
      final tourRef = _firestore.collection('tours').doc(tourId);
      final realTour = await tourRef.get();
      final realTourData = realTour.data();

      if (realTourData == null) {
        debugPrint('⚠️ Tour not found: $tourId');
        return;
      }

      final firestoreAvailableSeats = _toInt(
        realTourData['available_seats'] ?? realTourData['remainingSeats'],
      );
      final firestoreTotalSeats = _toInt(realTourData['totalSeats']);
      final firestoreBookedSeats = _toInt(realTourData['bookedSeats']);

      final actualAvailable = firestoreAvailableSeats;
      final actualTotal = firestoreTotalSeats > 0
          ? firestoreTotalSeats
          : actualAvailable + firestoreBookedSeats;

      // Calculate new available seats (add back the deleted booking's seats)
      final newAvailable = (actualAvailable + totalPersons)
          .clamp(0, actualTotal)
          .toInt();
      final newBookedSeats = (firestoreBookedSeats - totalPersons)
          .clamp(0, actualTotal)
          .toInt();

      debugPrint(
        '   Calculation: $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
      );

      // Update available_seats in Firestore
      final tourUpdate = <String, dynamic>{
        'totalSeats': actualTotal,
        'available_seats': newAvailable,
        'remainingSeats': newAvailable,
        'bookedSeats': newBookedSeats,
      };
      if (bookedUserId != null && bookedUserId.isNotEmpty) {
        tourUpdate['bookedUserIds'] = FieldValue.arrayRemove([bookedUserId]);
      }
      await tourRef.update(tourUpdate);

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
    _stopBookingDeletionMonitoring();
    super.dispose();
  }

  /// Parse booking close date and time fields into DateTime
  DateTime? _parseBookingCloseDateTime(Map<String, dynamic> tourData) {
    try {
      final rawDate = tourData['booking_close_date'];
      final rawTime = tourData['booking_close_time'];

      final parsedDate = _parseFlexibleDate(rawDate);
      if (parsedDate == null) {
        return null;
      }

      final (hour, minute) = _parseFlexibleTime(rawTime) ?? (0, 0);

      // Combine into DateTime
      final closeDateTime = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        hour,
        minute,
      );
      return closeDateTime;
    } catch (e) {
      debugPrint('⚠️ Error parsing booking close time: $e');
      return null;
    }
  }

  DateTime? _parseFlexibleDate(dynamic rawDate) {
    if (rawDate == null) return null;

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    if (rawDate is! String) {
      return null;
    }

    final value = rawDate.trim();
    if (value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final parts = value.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final normalized = DateTime.tryParse(
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        );
        if (normalized != null) return normalized;
      }
    }

    return null;
  }

  bool _bookingBelongsToUser(Map<String, dynamic> bookingData, String userId) {
    if (bookingData['userId'] == userId) {
      return true;
    }

    final passengerIdsRaw = bookingData['passengerIds'];
    if (passengerIdsRaw is List) {
      for (final id in passengerIdsRaw) {
        if (id?.toString() == userId) {
          return true;
        }
      }
    }

    final passengersRaw = bookingData['passengers'];
    if (passengersRaw is List) {
      for (final passenger in passengersRaw) {
        if (passenger is Map<String, dynamic> &&
            passenger['userId']?.toString() == userId) {
          return true;
        }
      }
    }

    return false;
  }

  (int, int)? _parseFlexibleTime(dynamic rawTime) {
    if (rawTime == null) return null;

    if (rawTime is Timestamp) {
      final dt = rawTime.toDate();
      return (dt.hour, dt.minute);
    }

    if (rawTime is DateTime) {
      return (rawTime.hour, rawTime.minute);
    }

    if (rawTime is! String) {
      return null;
    }

    final value = rawTime.trim();
    if (value.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})(?::(\d{1,2}))?\s*([AaPp][Mm])?$',
    ).firstMatch(value);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    var minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toUpperCase();

    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
    }

    return (hour, minute);
  }

  /// Listen to auth state changes and reload bookings automatically
  void _initializeAuthListener() {
    _authService.addListener(() {
      final userId = _authService.userId;
      final userChanged = _loadedUserId != userId;
      if (userChanged) {
        _loadedUserId = userId;
        _bookingLoadGeneration++;
        _joinedTours.clear();
        _bookings.clear();
        _bookingCache.clear();
        notifyListeners();
      }
      if (userId.isNotEmpty) {
        debugPrint('✅ User authenticated: $userId');
        _syncBookingDeletionMonitoring();
        if (userChanged) {
          loadBookings();
        }
      } else {
        debugPrint('❌ User logged out');
        _stopBookingDeletionMonitoring();
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
        if (_joinedTours.isNotEmpty || _bookings.isNotEmpty) {
          _joinedTours.clear();
          _bookings.clear();
          notifyListeners();
        }
        return;
      }

      if (_loadedUserId != userId) {
        _loadedUserId = userId;
        _bookingLoadGeneration++;
        _joinedTours.clear();
        _bookings.clear();
        _bookingCache.clear();
        notifyListeners();
      }
      final loadGeneration = ++_bookingLoadGeneration;

      final directBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      final passengerBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('passengerIds', arrayContains: userId)
          .get();

      if (!_isCurrentBookingLoad(userId, loadGeneration)) return;

      final bookingDocsById =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in directBookingsSnapshot.docs) {
        bookingDocsById[doc.id] = doc;
      }
      for (final doc in passengerBookingsSnapshot.docs) {
        bookingDocsById[doc.id] = doc;
      }

      _bookings.clear();
      _joinedTours.clear();

      for (final doc in bookingDocsById.values) {
        if (!_isCurrentBookingLoad(userId, loadGeneration)) return;
        final data = doc.data();
        if (!_bookingBelongsToUser(data, userId)) {
          continue;
        }
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

        // Prefer instance data if booking references an instance; otherwise
        // fetch the canonical tour doc.
        try {
          final instanceId = data['instanceId'] as String?;
          if (instanceId != null && instanceId.isNotEmpty) {
            try {
              final instDoc = await _firestore
                  .collection('tour_instances')
                  .doc(instanceId)
                  .get();
              if (!_isCurrentBookingLoad(userId, loadGeneration)) return;
              if (instDoc.exists) {
                final inst = instDoc.data() ?? {};
                final lastJoiningTime = _parseBookingCloseDateTime(inst);
                tour = Tour(
                  id: instanceId,
                  name: inst['name'] ?? data['tourName'] ?? '',
                  imageUrl: inst['imageUrl'] ?? '',
                  startDate: DateTime.parse(
                    inst['startDate'] as String? ??
                        data['tourDate'] ??
                        DateTime.now().toIso8601String(),
                  ),
                  totalSeats: _toInt(inst['totalSeats']),
                  remainingSeats: _toInt(
                    inst['available_seats'] ?? inst['remainingSeats'],
                  ),
                  price: (inst['price'] as num?)?.toDouble() ?? 0.0,
                  description: inst['description'] ?? '',
                  photos: List<String>.from(inst['photos'] ?? []),
                  category: inst['category'] ?? '',
                  startLocation: inst['startLocation'] ?? '',
                  lastJoiningTime: lastJoiningTime,
                  endTime: inst['endTime'] ?? '',
                  endLocation: inst['endLocation'] ?? '',
                  operatorName: inst['operatorName'] ?? '',
                  whatsIncluded: List<String>.from(inst['whatsIncluded'] ?? []),
                  tourFeatures: List<String>.from(inst['tourFeatures'] ?? []),
                  firstBookedUserId: inst['firstBookedUserId'] ?? '',
                  bookedUserIds: List<String>.from(inst['bookedUserIds'] ?? []),
                  bookedSeats: _toInt(inst['bookedSeats']),
                );
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching tour instance $instanceId: $e');
            }
          } else {
            final tourDoc = await _firestore
                .collection('tours')
                .doc(tourId)
                .get();
            if (!_isCurrentBookingLoad(userId, loadGeneration)) return;
            if (tourDoc.exists) {
              final tourData = tourDoc.data() ?? {};
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
                whatsIncluded: List<String>.from(
                  tourData['whatsIncluded'] ?? [],
                ),
                tourFeatures: List<String>.from(tourData['tourFeatures'] ?? []),
                firstBookedUserId: tourData['firstBookedUserId'] ?? '',
                bookedUserIds: List<String>.from(
                  tourData['bookedUserIds'] ?? [],
                ),
                bookedSeats: _toInt(tourData['bookedSeats']),
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching full tour details for $tourId: $e');
        }

        final booking = Booking.fromMap(data, tour);
        _bookings.add(booking);

        // Cache booking details for deletion detection (include instance if present)
        _bookingCache[doc.id] = {
          'tourId': tourId,
          'totalPersons': data['totalPersons'] as int? ?? 0,
          'userId': data['userId'] as String?,
          'instanceId': (data['instanceId'] as String?) ?? '',
          'tourDate': data['tourDate'] as String?,
        };

        // Add to joined tours
        _joinedTours.add(
          JoinedTour(
            tour: tour,
            joinedAt: DateTime.parse(
              data['bookedAt'] as String? ?? DateTime.now().toIso8601String(),
            ),
            persons: _countUserPassengersInBooking(data, userId).isNotEmpty
                ? _countUserPassengersInBooking(data, userId).length
                : (data['totalPersons'] ?? 0),
          ),
        );
      }

      if (_isCurrentBookingLoad(userId, loadGeneration)) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading bookings: $e');
    }
  }

  bool _isCurrentBookingLoad(String userId, int loadGeneration) {
    return _authService.userId == userId &&
        _bookingLoadGeneration == loadGeneration;
  }

  /// Count how many passengers in this booking belong to the given user
  List<Map<String, dynamic>> _countUserPassengersInBooking(
    Map<String, dynamic> bookingData,
    String userId,
  ) {
    try {
      final passengers = bookingData['passengers'] as List<dynamic>? ?? [];
      final userPassengers = <Map<String, dynamic>>[];

      for (final p in passengers) {
        if (p is Map<String, dynamic> && p['userId'] == userId) {
          userPassengers.add(p);
        }
      }

      return userPassengers;
    } catch (e) {
      debugPrint('⚠️ Error counting user passengers: $e');
      return [];
    }
  }

  /// Creates one active instance from an idle template, or books seats on an
  /// existing active instance. The instance and booking are written atomically.
  Future<bool> joinTour({
    required Tour tour,
    DateTime? tourDate,
    required int adults,
    required int kids6to12,
    required int kidsUnder6,
    required String pickupLocation,
    required double totalPrice,
    String? cardHolderName,
    required String phoneNumber,
  }) async {
    final totalPersons = adults + kids6to12 + kidsUnder6;
    final userId = _authService.userId;
    lastError = null;

    try {
      if (userId.isEmpty) {
        throw StateError('Please sign in to complete the booking');
      }
      if (tour.id.isEmpty || tour.name.isEmpty) {
        throw StateError('Invalid tour information');
      }
      if (totalPersons <= 0) {
        throw StateError('Select at least one passenger');
      }

      String userName = 'User';
      String userEmail = '';
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        userName = (userData?['displayName'] ?? userData?['name'] ?? 'User')
            .toString();
        userEmail = (userData?['email'] ?? '').toString();
      } catch (_) {
        // Booking can continue with the authenticated user's id.
      }

      final passenger = PassengerInfo(
        userId: userId,
        name: userName,
        email: userEmail,
        phone: phoneNumber,
      );
      final isIdleTemplate = tour.sourceIdleTourId.isEmpty;
      final sourceIdleTourId = isIdleTemplate ? tour.id : tour.sourceIdleTourId;
      final scheduledDate = isIdleTemplate
          ? (tourDate ?? tour.startDate)
          : tour.startDate;
      final instanceRef = isIdleTemplate
          ? _firestore.collection('tour_instances').doc()
          : _firestore.collection('tour_instances').doc(tour.id);
      final bookingRef = _firestore.collection('bookings').doc();
      final bookedAt = DateTime.now();

      if (!isIdleTemplate) {
        final existingBookings = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: userId)
            .get();
        final alreadyBooked = existingBookings.docs.any((doc) {
          final data = doc.data();
          return data['instanceId']?.toString() == tour.id ||
              data['tourId']?.toString() == tour.id;
        });
        if (alreadyBooked) {
          throw StateError(
            'You already booked this tour. Open My Booking to edit the passenger count.',
          );
        }
      }

      late Tour bookedTour;
      late Booking booking;

      await _firestore.runTransaction((transaction) async {
        var totalSeats = tour.totalSeats;
        var remainingSeats = tour.remainingSeats;
        var bookedSeats = tour.bookedSeats;
        var bookedUserIds = List<String>.from(tour.bookedUserIds);
        var firstBookedUserId = tour.firstBookedUserId;

        if (isIdleTemplate) {
          final templateRef = _firestore.collection('tours').doc(tour.id);
          final templateSnapshot = await transaction.get(templateRef);
          if (!templateSnapshot.exists) {
            throw StateError('This idle tour no longer exists');
          }

          final templateData =
              templateSnapshot.data() ?? <String, dynamic>{};
          totalSeats = _toInt(
            templateData['totalSeats'],
            fallback: _toInt(
              templateData['available_seats'] ??
                  templateData['remainingSeats'],
              fallback: totalSeats,
            ),
          );

          // Every active occurrence starts from the administrator's full
          // template capacity. Previous bookings must never reduce the idle
          // template's displayed or reusable seat count.
          remainingSeats = totalSeats;
          bookedSeats = 0;
          bookedUserIds = <String>[];
          firstBookedUserId = '';
        } else {
          final instanceSnapshot = await transaction.get(instanceRef);
          if (!instanceSnapshot.exists) {
            throw StateError('This active tour no longer exists');
          }

          final data = instanceSnapshot.data() ?? <String, dynamic>{};
          totalSeats = _toInt(data['totalSeats'], fallback: totalSeats);
          remainingSeats = _toInt(
            data['available_seats'] ?? data['remainingSeats'],
            fallback: remainingSeats,
          );
          bookedSeats = _toInt(data['bookedSeats'], fallback: bookedSeats);
          bookedUserIds = List<String>.from(data['bookedUserIds'] ?? const []);
          firstBookedUserId = (data['firstBookedUserId'] ?? firstBookedUserId)
              .toString();
        }

        if (totalSeats <= 0) {
          throw StateError('Tour capacity is not configured');
        }
        if (remainingSeats < totalPersons) {
          throw StateError(
            'Only $remainingSeats seat${remainingSeats == 1 ? '' : 's'} available',
          );
        }

        final newRemainingSeats = remainingSeats - totalPersons;
        final newBookedSeats = bookedSeats + totalPersons;
        if (!bookedUserIds.contains(userId)) {
          bookedUserIds.add(userId);
        }
        if (firstBookedUserId.isEmpty) {
          firstBookedUserId = userId;
        }

        bookedTour = tour.copyWith(
          id: instanceRef.id,
          startDate: scheduledDate,
          totalSeats: totalSeats,
          remainingSeats: newRemainingSeats,
          bookedSeats: newBookedSeats,
          bookedUserIds: bookedUserIds,
          firstBookedUserId: firstBookedUserId,
          sourceIdleTourId: sourceIdleTourId,
        );

        if (isIdleTemplate) {
          transaction.set(instanceRef, {
            'tourId': instanceRef.id,
            'sourceIdleTourId': sourceIdleTourId,
            'name': tour.name,
            'imageUrl': tour.imageUrl,
            'startDate': scheduledDate.toIso8601String(),
            'totalSeats': totalSeats,
            'available_seats': newRemainingSeats,
            'remainingSeats': newRemainingSeats,
            'bookedSeats': newBookedSeats,
            'bookedUserIds': bookedUserIds,
            'firstBookedUserId': firstBookedUserId,
            'price': tour.price,
            'description': tour.description,
            'photos': tour.photos,
            'category': tour.category,
            'startLocation': tour.startLocation,
            'lastJoiningTime': tour.lastJoiningTime?.toIso8601String(),
            'endTime': tour.endTime,
            'endLocation': tour.endLocation,
            'route': tour.route
                .map((stop) => {'location': stop.location, 'time': stop.time})
                .toList(),
            'operatorName': tour.operatorName,
            'whatsIncluded': tour.whatsIncluded,
            'tourFeatures': tour.tourFeatures,
            'rating': tour.rating,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(instanceRef, {
            'available_seats': newRemainingSeats,
            'remainingSeats': newRemainingSeats,
            'bookedSeats': newBookedSeats,
            'bookedUserIds': bookedUserIds,
            'firstBookedUserId': firstBookedUserId,
          });
        }

        booking = Booking(
          id: bookingRef.id,
          userId: userId,
          tour: bookedTour,
          tourDate: scheduledDate,
          bookedAt: bookedAt,
          adults: adults,
          kids6to12: kids6to12,
          kidsUnder6: kidsUnder6,
          pickupLocation: pickupLocation,
          totalPrice: totalPrice,
          totalPersons: totalPersons,
          cardHolderName: cardHolderName,
          phoneNumber: phoneNumber,
          passengers: [passenger],
        );
        final bookingData = booking.toMap()
          ..addAll({
            'instanceId': instanceRef.id,
            'templateTourId': sourceIdleTourId,
          });
        transaction.set(bookingRef, bookingData);
      });

      _bookings.add(booking);
      _joinedTours.add(
        JoinedTour(tour: bookedTour, joinedAt: bookedAt, persons: totalPersons),
      );
      _bookingCache[bookingRef.id] = {
        'tourId': bookedTour.id,
        'totalPersons': totalPersons,
        'userId': userId,
        'instanceId': bookedTour.id,
        'tourDate': scheduledDate.toIso8601String(),
      };

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      lastError = e is StateError ? e.message.toString() : e.toString();
      debugPrint('Booking failed: $e');
      debugPrintStack(stackTrace: stackTrace, label: 'joinTour error');
      return false;
    }
  }

  /// Legacy booking implementation retained temporarily for migration
  /// reference. New bookings use [joinTour] above.
  // ignore: unused_element
  Future<bool> _legacyJoinTour({
    required Tour tour,
    DateTime? tourDate,
    required int adults,
    required int kids6to12,
    required int kidsUnder6,
    required String pickupLocation,
    required double totalPrice,
    String? cardHolderName,
    required String phoneNumber,
  }) async {
    final totalPersons = adults + kids6to12 + kidsUnder6;
    final userId = _authService.userId;

    try {
      if (userId.isEmpty) {
        lastError = 'No user logged in';
        debugPrint('❌ No user logged in - cannot save booking');
        return false;
      }

      // Validate critical tour data (id is required)
      if (tour.id.isEmpty) {
        lastError = 'Invalid tour id';
        debugPrint('❌ Invalid tour: tour.id is empty');
        return false;
      }

      if (tour.name.isEmpty) {
        lastError = 'Invalid tour name';
        debugPrint('❌ Invalid tour: tour.name is empty');
        return false;
      }

      if (totalPersons <= 0) {
        lastError = 'No passengers selected for booking';
        debugPrint('❌ No passengers selected for booking');
        return false;
      }

      // Ensure tour data is complete (get from Firestore if needed)
      Tour completeTour = tour;
      if (tour.name.isEmpty) {
        try {
          final tourDoc = await _firestore
              .collection('tours')
              .doc(tour.id)
              .get();
          if (tourDoc.exists) {
            final tourData = tourDoc.data() ?? {};
            completeTour = Tour(
              id: tour.id,
              name: tourData['name'] ?? tour.name,
              imageUrl: tourData['imageUrl'] ?? tour.imageUrl,
              startDate: tour.startDate,
              totalSeats: tourData['totalSeats'] ?? tour.totalSeats,
              remainingSeats:
                  tourData['available_seats'] ??
                  tourData['remainingSeats'] ??
                  tour.remainingSeats,
              price: (tourData['price'] as num?)?.toDouble() ?? tour.price,
              description: tourData['description'] ?? tour.description,
              photos: List<String>.from(tourData['photos'] ?? tour.photos),
              category: tourData['category'] ?? tour.category,
              startLocation: tourData['startLocation'] ?? tour.startLocation,
              endTime: tourData['endTime'] ?? tour.endTime,
              endLocation: tourData['endLocation'] ?? tour.endLocation,
              operatorName: tourData['operatorName'] ?? tour.operatorName,
              whatsIncluded: List<String>.from(
                tourData['whatsIncluded'] ?? tour.whatsIncluded,
              ),
              tourFeatures: List<String>.from(
                tourData['tourFeatures'] ?? tour.tourFeatures,
              ),
              firstBookedUserId: tourData['firstBookedUserId'] ?? '',
              bookedUserIds: List<String>.from(tourData['bookedUserIds'] ?? []),
              bookedSeats: _toInt(tourData['bookedSeats']),
            );
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch complete tour data: $e');
          completeTour = tour;
        }
      }

      // NO EXISTING BOOKING - CREATE NEW BOOKING
      debugPrint('📝 Creating new booking for tour ${tour.id}...');

      // If booking an idle canonical tour, clone it into a new active
      // tour document so the original idle tour remains unchanged.
      String targetTourId = completeTour.id;
      try {
        if (completeTour.status == TourStatus.idle) {
          final toursCol = _firestore.collection('tours');
          // Attempt to read canonical tour data to preserve all fields
          Map<String, dynamic>? sourceData;
          try {
            final srcDoc = await toursCol.doc(completeTour.id).get();
            sourceData = srcDoc.exists ? srcDoc.data() : null;
          } catch (_) {
            sourceData = null;
          }

          // Build clone data from either fetched source or from the in-memory Tour
          final int totalForClone = completeTour.totalSeats;
          final int bookedSeatsForClone = totalPersons;
          final int availableForClone = (totalForClone > 0)
              ? (totalForClone - bookedSeatsForClone).clamp(0, totalForClone)
              : 0;

          final cloneData = <String, dynamic>{
            'name': completeTour.name,
            'imageUrl': completeTour.imageUrl,
            'startDate': completeTour.startDate.toIso8601String(),
            'totalSeats': totalForClone,
            'available_seats': availableForClone,
            'remainingSeats': availableForClone,
            'price': completeTour.price,
            'description': completeTour.description,
            'photos': completeTour.photos,
            'category': completeTour.category,
            'startLocation': completeTour.startLocation,
            'endTime': completeTour.endTime,
            'endLocation': completeTour.endLocation,
            'operatorName': completeTour.operatorName,
            'whatsIncluded': completeTour.whatsIncluded,
            'tourFeatures': completeTour.tourFeatures,
            'firstBookedUserId': userId,
            'bookedUserIds': [userId],
            'bookedSeats': bookedSeatsForClone,
            'sourceIdleTourId': completeTour.id,
          };

          // Copy any extra source fields if available (preserve custom fields)
          if (sourceData != null) {
            for (final entry in sourceData.entries) {
              if (!cloneData.containsKey(entry.key))
                cloneData[entry.key] = entry.value;
            }
          }

          // Create the cloned tour doc
          final newDocRef = await _firestore.collection('tours').add(cloneData);
          targetTourId = newDocRef.id;
          debugPrint(
            '🔁 Cloned idle tour ${completeTour.id} -> new active tour $targetTourId',
          );

          // Replace completeTour with a version that points to the clone
          completeTour = completeTour.copyWith(
            id: targetTourId,
            firstBookedUserId: userId,
            bookedUserIds: [userId],
            bookedSeats: bookedSeatsForClone,
            remainingSeats: availableForClone,
          );

          // Immediately update TourService cache so UI shows the cloned active
          // tour without waiting for the Firestore stream to refresh.
          try {
            final baseTour = Tour(
              id: targetTourId,
              name: cloneData['name'] as String? ?? completeTour.name,
              imageUrl:
                  cloneData['imageUrl'] as String? ?? completeTour.imageUrl,
              startDate:
                  DateTime.tryParse(
                    (cloneData['startDate'] as String?) ?? '',
                  ) ??
                  completeTour.startDate,
              totalSeats: totalForClone,
              remainingSeats: availableForClone,
              price:
                  (cloneData['price'] as num?)?.toDouble() ??
                  completeTour.price,
              sourceIdleTourId: completeTour.id,
            );
            try {
              TourService().updateTourInCache(
                targetTourId,
                newRemainingSeats: availableForClone,
                newBookedSeats: bookedSeatsForClone,
                bookedUserIds: [userId],
                firstBookedUserId: userId,
                baseTour: baseTour,
              );
              debugPrint(
                '✅ TourService cache primed for cloned tour $targetTourId',
              );
            } catch (e) {
              debugPrint('⚠️ Could not update TourService cache for clone: $e');
            }
          } catch (e) {
            debugPrint('⚠️ Error preparing base tour for cache priming: $e');
          }
        }
      } catch (e) {
        // If we cannot clone the canonical `tours` doc (often due to
        // Firestore security rules for client SDKs), don't fail the whole
        // booking. Fall back to using the canonical tour id and create an
        // instance under `tour_instances` instead. This allows bookings to
        // succeed even when clients aren't permitted to write to `tours`.
        lastError =
            'Could not clone idle tour: $e - falling back to instance creation';
        debugPrint(
          '⚠️ Could not clone idle tour: $e. Falling back to instance creation.',
        );
        // Keep `completeTour` as-is and continue — `targetTourId` remains
        // the canonical tour id assigned earlier.
      }

      final bookingId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get current user data
      String userName = 'User';
      String userEmail = '';
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['displayName'] ?? userData?['name'] ?? 'User';
          userEmail = userData?['email'] ?? '';
        }
      } catch (e) {
        debugPrint(
          '⚠️ Warning: Could not fetch user data for $userId: $e. Using defaults.',
        );
      }

      // Create initial passenger info for the first booker
      final initialPassenger = PassengerInfo(
        userId: userId,
        name: userName,
        email: userEmail,
        phone: phoneNumber,
      );

      // Create booking object with passengers array
      final booking = Booking(
        id: bookingId,
        userId: userId,
        tour: completeTour,
        tourDate: tourDate ?? completeTour.startDate,
        bookedAt: DateTime.now(),
        adults: adults,
        kids6to12: kids6to12,
        kidsUnder6: kidsUnder6,
        pickupLocation: pickupLocation,
        totalPrice: totalPrice,
        totalPersons: totalPersons,
        cardHolderName: cardHolderName,
        phoneNumber: phoneNumber,
        passengers: [initialPassenger],
      );

      // Debug: Print booking data before saving
      final bookingMapData = booking.toMap();
      debugPrint(
        '📊 Booking data: id=$bookingId, userId=$userId, tourId=${completeTour.id}, totalPersons=$totalPersons, passengers=${bookingMapData['passengers']}',
      );

      // Save to Firestore with error handling
      try {
        await _firestore
            .collection('bookings')
            .doc(bookingId)
            .set(bookingMapData);
      } catch (e) {
        lastError = 'Error writing booking to Firestore: $e';
        debugPrint('❌ Error writing booking to Firestore: $e');
        rethrow;
      }

      debugPrint('✅ New booking saved: $bookingId');
      debugPrint(
        '📊 Before update - Tour ${completeTour.id}: remainingSeats=${completeTour.remainingSeats}, totalSeats=${completeTour.totalSeats}, totalPersons=$totalPersons',
      );

      // Create or update an active "instance" for this tour + date instead of
      // modifying the original `tours` document. This preserves the idle tour
      // while moving only the booked occurrence into the active instances.
      try {
        final instanceCollection = _firestore.collection('tour_instances');
        final instanceDateIso = booking.toMap()['tourDate'] as String;

        // Try to find an existing instance for this tour+date
        final existing = await instanceCollection
            .where('tourId', isEqualTo: completeTour.id)
            .where('startDate', isEqualTo: instanceDateIso)
            .limit(1)
            .get();

        String instanceId;
        int newAvailable = 0;

        if (existing.docs.isNotEmpty) {
          final doc = existing.docs.first;
          final data = doc.data();
          final firestoreAvailable = _toInt(data['available_seats']) > 0
              ? _toInt(data['available_seats'])
              : _toInt(data['remainingSeats']);
          final firestoreTotal = _toInt(data['totalSeats']) > 0
              ? _toInt(data['totalSeats'])
              : (completeTour.totalSeats > 0
                    ? completeTour.totalSeats
                    : firestoreAvailable + _toInt(data['bookedSeats']));

          newAvailable = (firestoreAvailable - totalPersons)
              .clamp(0, firestoreTotal)
              .toInt();

          final newBookedSeats = (_toInt(data['bookedSeats']) + totalPersons)
              .clamp(0, firestoreTotal)
              .toInt();

          instanceId = doc.id;

          await instanceCollection.doc(instanceId).update({
            'totalSeats': firestoreTotal,
            'available_seats': newAvailable,
            'remainingSeats': newAvailable,
            'bookedSeats': newBookedSeats,
            'bookedUserIds': FieldValue.arrayUnion([userId]),
            'sourceIdleTourId': completeTour.id,
          });
        } else {
          // Create new instance doc
          final instanceRef = instanceCollection.doc();
          instanceId = instanceRef.id;
          final totalForInstance = completeTour.totalSeats > 0
              ? completeTour.totalSeats
              : totalPersons;
          newAvailable = (totalForInstance - totalPersons)
              .clamp(0, totalForInstance)
              .toInt();

          final instanceData = <String, dynamic>{
            'tourId': completeTour.id,
            'name': completeTour.name,
            'imageUrl': completeTour.imageUrl,
            'startDate': instanceDateIso,
            'totalSeats': totalForInstance,
            'available_seats': newAvailable,
            'remainingSeats': newAvailable,
            'bookedSeats': totalPersons,
            'bookedUserIds': [userId],
            'firstBookedUserId': userId,
            'sourceIdleTourId': completeTour.id,
          };

          await instanceRef.set(instanceData);
        }

        debugPrint(
          '✅ Upserted tour instance $instanceId available=$newAvailable',
        );

        // Update booking doc to reference instance and instance availability
        try {
          await _firestore.collection('bookings').doc(bookingId).update({
            'instanceId': instanceId,
            'instanceAvailable': newAvailable,
            'instanceTotalSeats': completeTour.totalSeats,
          });
        } catch (e) {
          debugPrint('⚠️ Could not update booking with instance metadata: $e');
        }

        // Update cache for deletion/refund handling
        _bookingCache[bookingId] = {
          'tourId': completeTour.id,
          'totalPersons': totalPersons,
          'userId': userId,
          'instanceId': instanceId,
        };

        // Add to in-memory joined tours as an instance-aware Tour
        _joinedTours.add(
          JoinedTour(
            tour: Tour(
              id: completeTour.id,
              name: completeTour.name,
              imageUrl: completeTour.imageUrl,
              startDate: booking.tourDate,
              totalSeats: completeTour.totalSeats,
              remainingSeats: newAvailable,
              price: completeTour.price,
              description: completeTour.description,
              photos: completeTour.photos,
              category: completeTour.category,
              startLocation: completeTour.startLocation,
              lastJoiningTime: completeTour.lastJoiningTime,
              endTime: completeTour.endTime,
              endLocation: completeTour.endLocation,
              route: completeTour.route,
              operatorName: completeTour.operatorName,
              whatsIncluded: completeTour.whatsIncluded,
              tourFeatures: completeTour.tourFeatures,
              firstBookedUserId: userId,
              bookedUserIds: [userId],
              bookedSeats: totalPersons,
            ),
            joinedAt: DateTime.now(),
            persons: totalPersons,
          ),
        );
      } catch (e) {
        lastError = 'Error creating/updating tour instance: $e';
        debugPrint('❌ Error creating/updating tour instance: $e');
      }

      // Ensure booking is tracked in-memory
      _bookings.add(booking);

      // Ensure cache entry exists (if instance upsert failed earlier)
      _bookingCache[bookingId] =
          _bookingCache[bookingId] ??
          {
            'tourId': completeTour.id,
            'totalPersons': totalPersons,
            'userId': userId,
          };

      lastError = null;
      notifyListeners();
      debugPrint('✅ Booking completed successfully: $bookingId');
      return true;
    } catch (e, stackTrace) {
      lastError = e.toString();
      debugPrint('❌ Error saving booking: $e');
      debugPrint(
        '📋 Tour ID: ${tour.id}, User ID: $userId, Total Persons: $totalPersons',
      );
      debugPrintStack(stackTrace: stackTrace, label: 'joinTour error');
      return false;
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
      _bookingCache.remove(bookingId);
      _lastSeenBookings.remove(bookingId);
      debugPrint('✅ Booking deleted: $bookingId');

      // Delete chat messages only for this scheduled tour occurrence.
      try {
        final messagesSnapshot = await _firestore
            .collection('messages')
            .where(
              'tourId',
              isEqualTo:
                  (bookingData?['instanceId'] as String?) ?? tourId,
            )
            .get();

        final batch = _firestore.batch();
        final bookingTourDate = DateTime.tryParse(
          bookingData?['tourDate']?.toString() ?? '',
        );
        for (final doc in messagesSnapshot.docs) {
          final messageTourDate = DateTime.tryParse(
            doc.data()['tourDate']?.toString() ?? '',
          );
          if (bookingTourDate != null &&
              messageTourDate != null &&
              (bookingTourDate.year != messageTourDate.year ||
                  bookingTourDate.month != messageTourDate.month ||
                  bookingTourDate.day != messageTourDate.day)) {
            continue;
          }
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint(
          '✅ Deleted ${messagesSnapshot.docs.length} chat messages for tour: $tourId',
        );
      } catch (chatError) {
        debugPrint(
          '⚠️ Warning: Could not delete chat messages for $tourId: $chatError',
        );
        // Don't fail the booking cancellation if chat deletion fails
      }

      // Return seats to the instance if one exists, else to the canonical tour
      try {
        final instanceId = bookingData?['instanceId'] as String?;
        if (instanceId != null && instanceId.isNotEmpty) {
          final instRef = _firestore
              .collection('tour_instances')
              .doc(instanceId);
          final instDoc = await instRef.get();
          final instData = instDoc.data();

          if (instData == null) {
            throw Exception('Instance not found in Firestore: $instanceId');
          }

          final firestoreAvailableSeats = _toInt(
            instData['available_seats'] ?? instData['remainingSeats'],
          );
          final firestoreTotalSeats = _toInt(instData['totalSeats']);
          final firestoreBookedSeats = _toInt(instData['bookedSeats']);

          debugPrint(
            '   📥 Real from Firestore (instance): available_seats=$firestoreAvailableSeats, totalSeats=$firestoreTotalSeats',
          );

          final actualAvailable = firestoreAvailableSeats;
          final actualTotal = firestoreTotalSeats > 0
              ? firestoreTotalSeats
              : actualAvailable + firestoreBookedSeats;

          final newAvailable = (actualAvailable + totalPersons)
              .clamp(0, actualTotal)
              .toInt();
          final newBookedSeats = (firestoreBookedSeats - totalPersons)
              .clamp(0, actualTotal)
              .toInt();

          debugPrint(
            '   Calculation (instance): $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
          );

          await instRef.update({
            'totalSeats': actualTotal,
            'available_seats': newAvailable,
            'remainingSeats': newAvailable,
            'bookedSeats': newBookedSeats,
            'bookedUserIds': FieldValue.arrayRemove([bookingData?['userId']]),
          });

          debugPrint(
            '✅ Refunded seats to instance: available_seats updated to $newAvailable',
          );
        } else {
          final tourRef = _firestore.collection('tours').doc(tourId);
          final realTour = await tourRef.get();
          final realTourData = realTour.data();

          if (realTourData == null) {
            throw Exception('Tour not found in Firestore: $tourId');
          }

          final firestoreAvailableSeats = _toInt(
            realTourData['available_seats'] ?? realTourData['remainingSeats'],
          );
          final firestoreTotalSeats = _toInt(realTourData['totalSeats']);
          final firestoreBookedSeats = _toInt(realTourData['bookedSeats']);

          debugPrint(
            '   📥 Real from Firestore: available_seats=$firestoreAvailableSeats, totalSeats=$firestoreTotalSeats',
          );

          final actualAvailable = firestoreAvailableSeats;
          final actualTotal = firestoreTotalSeats > 0
              ? firestoreTotalSeats
              : actualAvailable + firestoreBookedSeats;

          final newAvailable = (actualAvailable + totalPersons)
              .clamp(0, actualTotal)
              .toInt();
          final newBookedSeats = (firestoreBookedSeats - totalPersons)
              .clamp(0, actualTotal)
              .toInt();
          debugPrint(
            '   Calculation: $actualAvailable + $totalPersons = $newAvailable (clamped 0-$actualTotal)',
          );

          await tourRef.update({
            'totalSeats': actualTotal,
            'available_seats': newAvailable,
            'remainingSeats': newAvailable,
            'bookedSeats': newBookedSeats,
            'bookedUserIds': FieldValue.arrayRemove([bookingData?['userId']]),
          });

          debugPrint(
            '✅ Refunded seats to tour: available_seats updated to $newAvailable',
          );

          await Future.delayed(const Duration(milliseconds: 300));
          final updatedTour = await tourRef.get();
          final verifiedAvailable = updatedTour.data()?['available_seats'];
          debugPrint(
            '✅ VERIFIED from Firestore: available_seats=$verifiedAvailable',
          );

          _tourService.updateTourInCache(
            tourId,
            newRemainingSeats: newAvailable,
          );
        }
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

  Future<void> _deleteMessagesForBookingOccurrence({
    required String? instanceId,
    required String tourId,
    required String? tourDate,
  }) async {
    final chatId = instanceId != null && instanceId.isNotEmpty
        ? instanceId
        : tourId;
    if (chatId.isEmpty) return;

    final bookingDate = DateTime.tryParse(tourDate ?? '');
    final messagesSnapshot = await _firestore
        .collection('messages')
        .where('tourId', isEqualTo: chatId)
        .get();
    final batch = _firestore.batch();
    var deletedCount = 0;

    for (final doc in messagesSnapshot.docs) {
      final messageDate = DateTime.tryParse(
        doc.data()['tourDate']?.toString() ?? '',
      );
      final sameDate =
          bookingDate == null ||
          messageDate == null ||
          (bookingDate.year == messageDate.year &&
              bookingDate.month == messageDate.month &&
              bookingDate.day == messageDate.day);
      if (!sameDate) continue;

      batch.delete(doc.reference);
      deletedCount++;
    }

    if (deletedCount > 0) {
      await batch.commit();
    }
    debugPrint(
      'Deleted $deletedCount messages for booking occurrence $chatId',
    );
  }

  /// Stream real-time bookings from Firestore
  Stream<List<JoinedTour>> streamBookings() {
    final userId = _authService.userId;
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('bookings')
        .snapshots()
        .asyncMap((snapshot) async {
          final joinedTours = <JoinedTour>[];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (!_bookingBelongsToUser(data, userId)) {
              continue;
            }

            final instanceId =
                (data['instanceId'] ?? data['tourId'] ?? '').toString();
            final tourDate = DateTime.tryParse(
                  data['tourDate']?.toString() ?? '',
                ) ??
                DateTime.now();
            var tour = Tour(
              id: instanceId,
              name: data['tourName'] ?? '',
              imageUrl: data['imageUrl'] ?? '',
              startDate: tourDate,
              totalSeats: (data['instanceTotalSeats'] as num?)?.toInt() ?? 0,
              remainingSeats: (data['instanceAvailable'] as num?)?.toInt() ?? 0,
              price: (data['price'] as num?)?.toDouble() ?? 0.0,
            );

            if (instanceId.isNotEmpty) {
              try {
                final instanceDoc = await _firestore
                    .collection('tour_instances')
                    .doc(instanceId)
                    .get();
                final instance = instanceDoc.data();
                if (instance != null) {
                  tour = Tour(
                    id: instanceId,
                    name: (instance['name'] ?? data['tourName'] ?? '')
                        .toString(),
                    imageUrl:
                        (instance['imageUrl'] ?? data['imageUrl'] ?? '')
                            .toString(),
                    startDate: DateTime.tryParse(
                          instance['startDate']?.toString() ?? '',
                        ) ??
                        tourDate,
                    totalSeats: _toInt(
                      instance['totalSeats'],
                      fallback: tour.totalSeats,
                    ),
                    remainingSeats: _toInt(
                      instance['available_seats'] ??
                          instance['remainingSeats'],
                      fallback: tour.remainingSeats,
                    ),
                    price: _toDouble(
                      instance['price'],
                      fallback: tour.price,
                    ),
                    description: (instance['description'] ?? '').toString(),
                    photos: List<String>.from(instance['photos'] ?? const []),
                    category: (instance['category'] ?? '').toString(),
                    startLocation:
                        (instance['startLocation'] ?? '').toString(),
                    lastJoiningTime: _parseBookingCloseDateTime(instance),
                    endTime: (instance['endTime'] ?? '').toString(),
                    endLocation: (instance['endLocation'] ?? '').toString(),
                    route: (instance['route'] as List<dynamic>? ?? const [])
                        .whereType<Map>()
                        .map(
                          (stop) => RouteStop(
                            location: (stop['location'] ?? '').toString(),
                            time: (stop['time'] ?? '').toString(),
                          ),
                        )
                        .toList(),
                    operatorName:
                        (instance['operatorName'] ?? '').toString(),
                    whatsIncluded: List<String>.from(
                      instance['whatsIncluded'] ?? const [],
                    ),
                    tourFeatures: List<String>.from(
                      instance['tourFeatures'] ?? const [],
                    ),
                    firstBookedUserId:
                        (instance['firstBookedUserId'] ?? '').toString(),
                    bookedUserIds: List<String>.from(
                      instance['bookedUserIds'] ?? const [],
                    ),
                    bookedSeats: _toInt(instance['bookedSeats']),
                    sourceIdleTourId:
                        (instance['sourceIdleTourId'] ?? '').toString(),
                  );
                }
              } catch (e) {
                debugPrint(
                  'Could not load instance $instanceId for booking ${doc.id}: $e',
                );
              }
            }

            joinedTours.add(
              JoinedTour(
                bookingId: doc.id,
                tour: tour,
                joinedAt: DateTime.parse(
                  data['bookedAt'] as String? ??
                      DateTime.now().toIso8601String(),
                ),
                persons: _toInt(data['totalPersons']),
              ),
            );
          }

          joinedTours.sort(
            (a, b) => a.tour.startDate.compareTo(b.tour.startDate),
          );
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

  bool _bookingMatchesTour(Booking booking, Tour tour) {
    if (booking.tour.id == tour.id) return true;
    if (tour.sourceIdleTourId.isNotEmpty &&
        booking.tour.sourceIdleTourId == tour.sourceIdleTourId &&
        booking.tour.startDate.isAtSameMomentAs(tour.startDate)) {
      return true;
    }
    return false;
  }

  /// Returns whether the currently authenticated user booked this exact tour
  /// occurrence. Tour names are intentionally not used because multiple active
  /// occurrences can share the same name.
  bool isJoinedTour(Tour tour) {
    final userId = _authService.userId;
    if (userId.isEmpty) return false;

    if (tour.bookedUserIds.contains(userId)) {
      return true;
    }

    return _bookings.any(
      (booking) =>
          booking.userId == userId && _bookingMatchesTour(booking, tour),
    );
  }

  Booking? bookingForTour(Tour tour) {
    final userId = _authService.userId;
    if (userId.isEmpty) return null;

    for (final booking in _bookings) {
      if (booking.userId == userId && _bookingMatchesTour(booking, tour)) {
        return booking;
      }
    }
    return null;
  }

  /// Loads the current user's booking for this exact active occurrence.
  Future<Booking?> loadBookingForTour(Tour tour) async {
    final cached = bookingForTour(tour);
    if (cached != null) return cached;

    final userId = _authService.userId;
    if (userId.isEmpty) return null;

    final snapshot = await _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final instanceId = (data['instanceId'] ?? '').toString();
      final tourId = (data['tourId'] ?? '').toString();
      final templateTourId = (data['templateTourId'] ?? '').toString();
      final matchesInstance = instanceId == tour.id || tourId == tour.id;
      final matchesTemplate =
          tour.sourceIdleTourId.isNotEmpty &&
          templateTourId == tour.sourceIdleTourId &&
          data['tourDate']?.toString() == tour.startDate.toIso8601String();

      if (matchesInstance || matchesTemplate) {
        final bookingData = Map<String, dynamic>.from(data);
        bookingData['id'] = doc.id;
        return Booking.fromMap(bookingData, tour);
      }
    }

    return null;
  }

  /// Updates only the passenger count and keeps the tour seat totals in sync.
  Future<void> updateBookingPassengerCount(
    Booking booking,
    int newTotalPersons,
  ) async {
    final userId = _authService.userId;
    if (userId.isEmpty || booking.userId != userId) {
      throw StateError('You can only edit your own booking');
    }
    if (newTotalPersons < 1) {
      throw StateError('A booking needs at least one passenger');
    }
    if (newTotalPersons == booking.totalPersons) return;

    final bookingRef = _firestore.collection('bookings').doc(booking.id);
    final instanceRef = _firestore
        .collection('tour_instances')
        .doc(booking.tour.id);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      if (!bookingSnapshot.exists) {
        throw StateError('This booking no longer exists');
      }

      final bookingData = bookingSnapshot.data() ?? <String, dynamic>{};
      if (bookingData['userId'] != userId) {
        throw StateError('You can only edit your own booking');
      }

      final oldTotal = _toInt(bookingData['totalPersons']);
      final difference = newTotalPersons - oldTotal;
      final storedInstanceId = (bookingData['instanceId'] ?? '').toString();
      final targetInstanceRef = storedInstanceId.isNotEmpty
          ? _firestore.collection('tour_instances').doc(storedInstanceId)
          : instanceRef;
      final instanceSnapshot = await transaction.get(targetInstanceRef);
      if (!instanceSnapshot.exists) {
        throw StateError('This active tour no longer exists');
      }

      final instanceData = instanceSnapshot.data() ?? <String, dynamic>{};
      final totalSeats = _toInt(instanceData['totalSeats']);
      final availableSeats = _toInt(
        instanceData['available_seats'] ?? instanceData['remainingSeats'],
      );
      if (difference > availableSeats) {
        throw StateError(
          'Only $availableSeats more seat${availableSeats == 1 ? '' : 's'} available',
        );
      }

      final newAvailableSeats = (availableSeats - difference)
          .clamp(0, totalSeats)
          .toInt();
      final newBookedSeats = (_toInt(instanceData['bookedSeats']) + difference)
          .clamp(0, totalSeats)
          .toInt();

      var adults = _toInt(bookingData['adults']);
      var kids6to12 = _toInt(bookingData['kids6to12']);
      var kidsUnder6 = _toInt(bookingData['kidsUnder6']);
      if (difference > 0) {
        adults += difference;
      } else {
        var toRemove = -difference;
        final adultsRemoved = toRemove.clamp(0, adults).toInt();
        adults -= adultsRemoved;
        toRemove -= adultsRemoved;
        final kidsRemoved = toRemove.clamp(0, kids6to12).toInt();
        kids6to12 -= kidsRemoved;
        toRemove -= kidsRemoved;
        kidsUnder6 = (kidsUnder6 - toRemove)
            .clamp(0, kidsUnder6)
            .toInt();
      }

      final price = (instanceData['price'] as num?)?.toDouble() ??
          booking.tour.price;
      final newTotalPrice = adults * price + kids6to12 * price * 0.5;

      transaction.update(targetInstanceRef, {
        'available_seats': newAvailableSeats,
        'remainingSeats': newAvailableSeats,
        'bookedSeats': newBookedSeats,
      });
      transaction.update(bookingRef, {
        'adults': adults,
        'kids6to12': kids6to12,
        'kidsUnder6': kidsUnder6,
        'totalPersons': newTotalPersons,
        'totalPrice': newTotalPrice,
        'instanceAvailable': newAvailableSeats,
        'instanceTotalSeats': totalSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await loadBookings();
  }

  List<JoinedTour> get toursWithChats {
    return _joinedTours.where((jt) => jt.isChatAvailable).toList();
  }

  /// Clear all cached bookings and tours when user logs out
  void clearCache() {
    _bookingLoadGeneration++;
    _loadedUserId = _authService.userId;
    _joinedTours.clear();
    _bookings.clear();
    _lastSeenBookings.clear();
    _bookingCache.clear();
    notifyListeners();
    debugPrint('🗑️ JoinedTourService cache cleared');
  }
}
