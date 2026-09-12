import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityRide {
  final String id;
  final String hostUserId;
  final String hostName;
  final String hostEmail;
  final String hostPhone;
  final String whatsappNumber;
  final bool isHostDriver;
  final String driverName;
  final String driverPhone;
  final String driverLicenseNumber;
  final String origin;
  final String pickupLocation;
  final String destination;
  final String dropoffLocation;
  final List<String> routeStops;
  final DateTime departureAt;
  final DateTime estimatedArrivalAt;
  final int offeredSeats;
  final double pricePerPassenger;
  final String currency;
  final String vehicleType;
  final bool hasAirConditioning;
  final bool luggageAvailable;
  final String notes;
  final String approvalStatus;
  final String status;
  final String reviewNote;

  const CommunityRide({
    required this.id,
    required this.hostUserId,
    required this.hostName,
    required this.hostEmail,
    required this.hostPhone,
    required this.whatsappNumber,
    required this.isHostDriver,
    required this.driverName,
    required this.driverPhone,
    required this.driverLicenseNumber,
    required this.origin,
    required this.pickupLocation,
    required this.destination,
    required this.dropoffLocation,
    required this.routeStops,
    required this.departureAt,
    required this.estimatedArrivalAt,
    required this.offeredSeats,
    required this.pricePerPassenger,
    this.currency = 'LKR',
    required this.vehicleType,
    required this.hasAirConditioning,
    required this.luggageAvailable,
    required this.notes,
    this.approvalStatus = 'pending_review',
    this.status = 'pending_review',
    this.reviewNote = '',
  });

  factory CommunityRide.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime date(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return CommunityRide(
      id: id,
      hostUserId: (data['hostUserId'] ?? '').toString(),
      hostName: (data['hostName'] ?? '').toString(),
      hostEmail: (data['hostEmail'] ?? '').toString(),
      hostPhone: (data['hostPhone'] ?? '').toString(),
      whatsappNumber: (data['whatsappNumber'] ?? '').toString(),
      isHostDriver: data['isHostDriver'] != false,
      driverName: (data['driverName'] ?? '').toString(),
      driverPhone: (data['driverPhone'] ?? '').toString(),
      driverLicenseNumber: (data['driverLicenseNumber'] ?? '').toString(),
      origin: (data['origin'] ?? '').toString(),
      pickupLocation: (data['pickupLocation'] ?? '').toString(),
      destination: (data['destination'] ?? '').toString(),
      dropoffLocation: (data['dropoffLocation'] ?? '').toString(),
      routeStops: List<String>.from(data['routeStops'] ?? const []),
      departureAt: date(data['departureAt']),
      estimatedArrivalAt: date(data['estimatedArrivalAt']),
      offeredSeats: (data['offeredSeats'] as num?)?.toInt() ?? 0,
      pricePerPassenger: (data['pricePerPassenger'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] ?? 'LKR').toString(),
      vehicleType: (data['vehicleType'] ?? '').toString(),
      hasAirConditioning: data['hasAirConditioning'] == true,
      luggageAvailable: data['luggageAvailable'] == true,
      notes: (data['notes'] ?? '').toString(),
      approvalStatus: (data['approvalStatus'] ?? 'pending_review').toString(),
      status: (data['status'] ?? 'pending_review').toString(),
      reviewNote: (data['reviewNote'] ?? '').toString(),
    );
  }

  bool get canCancel => status != 'cancelled' && status != 'completed';
  bool get isApproved => approvalStatus == 'approved';
}
