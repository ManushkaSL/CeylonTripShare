import 'package:trip_share_app/models/tour.dart';

class PassengerInfo {
  final String userId;
  final String name;
  final String email;
  final String phone;

  PassengerInfo({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'name': name, 'email': email, 'phone': phone};
  }

  factory PassengerInfo.fromMap(Map<String, dynamic> map) {
    return PassengerInfo(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

class Booking {
  final String id;
  final String userId;
  final Tour tour;
  final DateTime bookedAt;
  final int adults;
  final int kids6to12;
  final int kidsUnder6;
  final String pickupLocation;
  final double totalPrice;
  final int totalPersons;
  final String? cardHolderName;
  final String phoneNumber;
  final List<PassengerInfo> passengers;

  Booking({
    required this.id,
    required this.userId,
    required this.tour,
    required this.bookedAt,
    required this.adults,
    required this.kids6to12,
    required this.kidsUnder6,
    required this.pickupLocation,
    required this.totalPrice,
    required this.totalPersons,
    this.cardHolderName,
    required this.phoneNumber,
    this.passengers = const [],
  });

  /// Convert to Firestore document data
  Map<String, dynamic> toMap() {
    final passengerIds = passengers
        .map((p) => p.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    return {
      'id': id,
      'userId': userId,
      'tourId': tour.id,
      'tourName': tour.name,
      'tourDate': tour.startDate.toIso8601String(),
      'bookedAt': bookedAt.toIso8601String(),
      'adults': adults,
      'kids6to12': kids6to12,
      'kidsUnder6': kidsUnder6,
      'pickupLocation': pickupLocation,
      'totalPrice': totalPrice,
      'totalPersons': totalPersons,
      'cardHolderName': cardHolderName,
      'phoneNumber': phoneNumber,
      'passengers': passengers.map((p) => p.toMap()).toList(),
      'passengerIds': passengerIds,
    };
  }

  /// Create from Firestore document data
  factory Booking.fromMap(Map<String, dynamic> map, Tour tour) {
    final passengersList = (map['passengers'] as List<dynamic>? ?? [])
        .map((p) => PassengerInfo.fromMap(p as Map<String, dynamic>))
        .toList();

    return Booking(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      tour: tour,
      bookedAt: DateTime.parse(map['bookedAt'] as String),
      adults: map['adults'] ?? 0,
      kids6to12: map['kids6to12'] ?? 0,
      kidsUnder6: map['kidsUnder6'] ?? 0,
      pickupLocation: map['pickupLocation'] ?? '',
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      totalPersons: map['totalPersons'] ?? 0,
      cardHolderName: map['cardHolderName'],
      phoneNumber: map['phoneNumber'] ?? '',
      passengers: passengersList,
    );
  }
}
