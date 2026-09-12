import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/community_ride.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/tour_service.dart';

class CommunityRideService {
  CommunityRideService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<CommunityRide>> watchMyRides() {
    final userId = AuthService().userId;
    if (userId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('community_ride_submissions')
        .where('hostUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map((doc) => CommunityRide.fromFirestore(doc.id, doc.data()))
              .toList();
          rides.sort((a, b) => b.departureAt.compareTo(a.departureAt));
          return rides;
        });
  }

  Future<String> submitRide({
    required String hostPhone,
    required String whatsappNumber,
    required bool isHostDriver,
    required String driverName,
    required String driverPhone,
    required String driverLicenseNumber,
    required String origin,
    required String pickupLocation,
    required String destination,
    required String dropoffLocation,
    required List<String> routeStops,
    required DateTime departureAt,
    required DateTime estimatedArrivalAt,
    required int offeredSeats,
    required double pricePerPassenger,
    required String vehicleType,
    required bool hasAirConditioning,
    required bool luggageAvailable,
    required String notes,
  }) async {
    final auth = AuthService();
    if (!auth.isLoggedIn || auth.userId.isEmpty) {
      throw StateError('Sign in before offering a ride.');
    }
    if (!estimatedArrivalAt.isAfter(departureAt)) {
      throw StateError('Estimated arrival must be after departure.');
    }
    if (offeredSeats < 1 || offeredSeats > 20) {
      throw StateError('Available passenger seats must be between 1 and 20.');
    }
    if (pricePerPassenger < 0) {
      throw StateError('Price per passenger cannot be negative.');
    }

    final ref = _firestore.collection('community_ride_submissions').doc();
    await ref.set({
      'id': ref.id,
      'sourceType': 'community_ride',
      'hostUserId': auth.userId,
      'hostName': auth.userName,
      'hostEmail': auth.userEmail,
      'hostPhone': hostPhone.trim(),
      'whatsappNumber': whatsappNumber.trim(),
      'isHostDriver': isHostDriver,
      'driverName': isHostDriver ? auth.userName : driverName.trim(),
      'driverPhone': isHostDriver ? hostPhone.trim() : driverPhone.trim(),
      'driverLicenseNumber': driverLicenseNumber.trim(),
      'origin': origin.trim(),
      'pickupLocation': pickupLocation.trim(),
      'destination': destination.trim(),
      'dropoffLocation': dropoffLocation.trim(),
      'routeStops': routeStops,
      'departureAt': Timestamp.fromDate(departureAt),
      'estimatedArrivalAt': Timestamp.fromDate(estimatedArrivalAt),
      'offeredSeats': offeredSeats,
      'pricePerPassenger': pricePerPassenger,
      'currency': 'LKR',
      'vehicleType': vehicleType.trim(),
      'hasAirConditioning': hasAirConditioning,
      'luggageAvailable': luggageAvailable,
      'notes': notes.trim(),
      'approvalStatus': 'pending_review',
      'status': 'pending_review',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> cancelRide(String rideId) async {
    final userId = AuthService().userId;
    if (userId.isEmpty) throw StateError('Sign in to cancel your ride.');

    final submissionRef = _firestore
        .collection('community_ride_submissions')
        .doc(rideId);
    final instanceRef = _firestore.collection('tour_instances').doc(rideId);
    await _firestore.runTransaction((transaction) async {
      final submission = await transaction.get(submissionRef);
      final instance = await transaction.get(instanceRef);
      if (!submission.exists || submission.data()?['hostUserId'] != userId) {
        throw StateError('You can cancel only your own ride.');
      }
      final bookedSeats = instance.exists
          ? (instance.data()?['bookedSeats'] as num?)?.toInt() ?? 0
          : 0;
      if (bookedSeats > 0) {
        throw StateError(
          'This ride already has passengers. Contact an administrator to cancel it.',
        );
      }
      transaction.update(submissionRef, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (instance.exists) {
        transaction.update(instanceRef, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<Tour?> loadApprovedTour(String rideId) async {
    final snapshot = await _firestore
        .collection('tour_instances')
        .doc(rideId)
        .get();
    final data = snapshot.data();
    return data == null ? null : TourService().parseTour(data, snapshot.id);
  }
}
