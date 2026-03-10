class Tour {
  final String name;
  final String imageUrl;
  final DateTime startDate;
  final int totalSeats;
  final int remainingSeats;

  const Tour({
    required this.name,
    required this.imageUrl,
    required this.startDate,
    required this.totalSeats,
    required this.remainingSeats,
  });

  TourStatus get status {
    if (remainingSeats == 0) return TourStatus.fullBooked;
    if (remainingSeats == totalSeats) return TourStatus.idle;
    return TourStatus.active;
  }
}

enum TourStatus { idle, active, fullBooked }
