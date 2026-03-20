class RouteStop {
  final String location;
  final String time;

  const RouteStop({required this.location, required this.time});
}

class Tour {
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

  const Tour({
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
  });

  bool get canBook => remainingSeats > 0;

  TourStatus get status {
    if (!canBook) return TourStatus.fullBooked;
    if (totalSeats > 0 && remainingSeats == totalSeats) return TourStatus.idle;
    return TourStatus.active;
  }
}

enum TourStatus { idle, active, fullBooked }
