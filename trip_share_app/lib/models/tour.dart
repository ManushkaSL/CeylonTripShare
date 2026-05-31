class RouteStop {
  final String location;
  final String time;

  const RouteStop({required this.location, required this.time});
}

class Tour {
  final String id;
  final String name;
  final String imageUrl;
  final DateTime startDate;
  final int totalSeats;
  final int remainingSeats;
  final double price;
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

  const Tour({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.startDate,
    required this.totalSeats,
    required this.remainingSeats,
    required this.price,
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
  );

  bool get canBook => remainingSeats > 0;

  Tour copyWith({
    String? id,
    String? name,
    String? imageUrl,
    DateTime? startDate,
    int? totalSeats,
    int? remainingSeats,
    double? price,
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
  }) {
    return Tour(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      startDate: startDate ?? this.startDate,
      totalSeats: totalSeats ?? this.totalSeats,
      remainingSeats: remainingSeats ?? this.remainingSeats,
      price: price ?? this.price,
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
    );
  }

  TourStatus get status {
    if (!canBook) return TourStatus.fullBooked;
    if (bookedSeats > 0 ||
        bookedUserIds.isNotEmpty ||
        firstBookedUserId.isNotEmpty) {
      return TourStatus.active;
    }
    if (totalSeats > 0 && remainingSeats == totalSeats) return TourStatus.idle;
    return TourStatus.active;
  }
}

enum TourStatus { idle, active, fullBooked }
