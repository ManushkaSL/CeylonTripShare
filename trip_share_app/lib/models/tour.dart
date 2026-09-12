class RouteStop {
  final String location;
  final String time;

  const RouteStop({required this.location, required this.time});
}

class Tour {
  static const String perPersonPricing = 'per_person';
  static const String fixedTourPricing = 'fixed_tour';
  static const String perSeatPricing = 'per_seat';

  final String id;
  final String name;
  final String imageUrl;
  final DateTime startDate;
  final int totalSeats;
  final int remainingSeats;
  final double price;
  final String pricingMode;
  final double fixedTourPrice;
  final String description;
  final List<String> photos;
  final String category;
  final String startLocation;
  final DateTime? lastJoiningTime;
  final String endTime;
  final String endLocation;
  final List<RouteStop> route;
  final String operatorName;
  final List<String> whatsIncluded;
  final List<String> tourFeatures;
  final String firstBookedUserId; // ID of the first user who booked this tour
  final List<String> bookedUserIds; // List of all booked user IDs
  final int bookedSeats; // Total seats already booked across all users
  final double rating; // Rating of the tour (0-5 stars)
  /// ID of the original idle tour if this is an active occurrence.
  final String sourceIdleTourId;
  final bool isPrivate; // Private active tours are discoverable by link only
  final String sourceType;
  final String approvalStatus;
  final String hostUserId;
  final String hostName;
  final String vehicleType;
  final bool hasAirConditioning;
  final bool luggageAvailable;

  const Tour({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.startDate,
    required this.totalSeats,
    required this.remainingSeats,
    required this.price,
    this.pricingMode = perPersonPricing,
    this.fixedTourPrice = 0,
    this.description = '',
    this.photos = const [],
    this.category = '',
    this.startLocation = '',
    this.lastJoiningTime,
    this.endTime = '',
    this.endLocation = '',
    this.route = const [],
    this.operatorName = '',
    this.whatsIncluded = const [],
    this.tourFeatures = const [],
    this.firstBookedUserId = '',
    this.bookedUserIds = const [],
    this.bookedSeats = 0,
    this.rating = 4.5,
    this.sourceIdleTourId = '',
    this.isPrivate = false,
    this.sourceType = 'admin_tour',
    this.approvalStatus = 'approved',
    this.hostUserId = '',
    this.hostName = '',
    this.vehicleType = '',
    this.hasAirConditioning = false,
    this.luggageAvailable = false,
  });

  /// Creates an empty tour instance (useful for placeholders)
  factory Tour.empty() => Tour(
    id: '',
    name: '',
    imageUrl: '',
    startDate: DateTime.now(),
    totalSeats: 0,
    remainingSeats: 0,
    price: 0.0,
    rating: 4.5,
  );

  bool get canBook => remainingSeats > 0;

  bool get isFixedTourPricing => pricingMode == fixedTourPricing;

  bool get isCommunityRide => sourceType == 'community_ride';

  double get fullTourPrice => isFixedTourPricing ? fixedTourPrice : price;

  double get currentPassengerPrice {
    if (!isFixedTourPricing) return price;
    final passengers = bookedSeats > 0 ? bookedSeats : 1;
    return fixedTourPrice / passengers;
  }

  bool get hasBookings =>
      bookedSeats > 0 ||
      bookedUserIds.isNotEmpty ||
      firstBookedUserId.isNotEmpty;

  Tour copyWith({
    String? id,
    String? name,
    String? imageUrl,
    DateTime? startDate,
    int? totalSeats,
    int? remainingSeats,
    double? price,
    String? pricingMode,
    double? fixedTourPrice,
    String? description,
    List<String>? photos,
    String? category,
    String? startLocation,
    DateTime? lastJoiningTime,
    String? endTime,
    String? endLocation,
    List<RouteStop>? route,
    String? operatorName,
    List<String>? whatsIncluded,
    List<String>? tourFeatures,
    String? firstBookedUserId,
    List<String>? bookedUserIds,
    int? bookedSeats,
    double? rating,
    String? sourceIdleTourId,
    bool? isPrivate,
    String? sourceType,
    String? approvalStatus,
    String? hostUserId,
    String? hostName,
    String? vehicleType,
    bool? hasAirConditioning,
    bool? luggageAvailable,
  }) {
    return Tour(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      startDate: startDate ?? this.startDate,
      totalSeats: totalSeats ?? this.totalSeats,
      remainingSeats: remainingSeats ?? this.remainingSeats,
      price: price ?? this.price,
      pricingMode: pricingMode ?? this.pricingMode,
      fixedTourPrice: fixedTourPrice ?? this.fixedTourPrice,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      category: category ?? this.category,
      startLocation: startLocation ?? this.startLocation,
      lastJoiningTime: lastJoiningTime ?? this.lastJoiningTime,
      endTime: endTime ?? this.endTime,
      endLocation: endLocation ?? this.endLocation,
      route: route ?? this.route,
      operatorName: operatorName ?? this.operatorName,
      whatsIncluded: whatsIncluded ?? this.whatsIncluded,
      tourFeatures: tourFeatures ?? this.tourFeatures,
      firstBookedUserId: firstBookedUserId ?? this.firstBookedUserId,
      bookedUserIds: bookedUserIds ?? this.bookedUserIds,
      bookedSeats: bookedSeats ?? this.bookedSeats,
      rating: rating ?? this.rating,
      sourceIdleTourId: sourceIdleTourId ?? this.sourceIdleTourId,
      isPrivate: isPrivate ?? this.isPrivate,
      sourceType: sourceType ?? this.sourceType,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      hostUserId: hostUserId ?? this.hostUserId,
      hostName: hostName ?? this.hostName,
      vehicleType: vehicleType ?? this.vehicleType,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      luggageAvailable: luggageAvailable ?? this.luggageAvailable,
    );
  }

  TourStatus get status {
    if (!canBook) return TourStatus.fullBooked;
    if (isCommunityRide) return TourStatus.active;
    if (hasBookings) {
      return TourStatus.active;
    }
    // Clones of idle tours should never revert to idle status
    if (sourceIdleTourId.isNotEmpty) return TourStatus.active;
    if (totalSeats > 0 && remainingSeats == totalSeats) return TourStatus.idle;
    return TourStatus.active;
  }
}

enum TourStatus { idle, active, fullBooked }
