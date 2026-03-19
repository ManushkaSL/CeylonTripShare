import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';

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
  JoinedTourService._();

  final List<JoinedTour> _joinedTours = [];

  List<JoinedTour> get joinedTours => List.unmodifiable(_joinedTours);

  void joinTour(Tour tour, int persons) {
    // Avoid duplicate joins
    if (_joinedTours.any((jt) => jt.tour.name == tour.name)) return;
    _joinedTours.add(
      JoinedTour(tour: tour, joinedAt: DateTime.now(), persons: persons),
    );
    notifyListeners();
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
