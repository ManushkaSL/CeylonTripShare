import 'package:flutter/material.dart';
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
    if (tour.lastJoiningTime == null) return false;
    return DateTime.now().isAfter(tour.lastJoiningTime!);
  }

  bool get isLiveLocationAvailable => journeyStatus == JourneyStatus.inProgress;
}

class JoinedTourService extends ChangeNotifier {
  static final JoinedTourService _instance = JoinedTourService._();
  factory JoinedTourService() => _instance;
  JoinedTourService._() {
    _initializeAuthListener();
  }

  final List<JoinedTour> _joinedTours = [];
  final List<Booking> _bookings = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<JoinedTour> get joinedTours => List.unmodifiable(_joinedTours);
  List<Booking> get bookings => List.unmodifiable(_bookings);

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

        // Reconstruct Tour from booking data
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
