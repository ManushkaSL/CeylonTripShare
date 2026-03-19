import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';

class TourService {
  TourService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Tour>> streamTours() {
    return _firestore.collection('tours').snapshots().map((snapshot) {
      final tours = snapshot.docs
          .map((doc) => _tourFromMap(doc.data()))
          .toList(growable: false);

      final sortedTours = [...tours]
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      return sortedTours;
    });
  }

  Tour _tourFromMap(Map<String, dynamic> map) {
    final photos = _toStringList(_pick(map, ['photos', 'images', 'gallery']));
    final imageUrl = _stringFrom(
      _pick(map, ['imageUrl', 'image', 'image_url', 'thumbnail']),
    );

    final totalSeats = _intFrom(
      _pick(map, ['totalSeats', 'total_seats', 'seats']),
    );
    final remainingSeats = _intFrom(
      _pick(map, [
        'remainingSeats',
        'remaining_seats',
        'availableSeats',
        'available_seats',
      ]),
    );

    final resolvedRemainingSeats = remainingSeats > 0
        ? remainingSeats
        : totalSeats;

    return Tour(
      name: _stringFrom(_pick(map, ['name', 'title', 'tourName'])),
      imageUrl: imageUrl.isNotEmpty
          ? imageUrl
          : (photos.isNotEmpty ? photos.first : ''),
      startDate:
          _dateTimeFrom(_pick(map, ['startDate', 'start_date', 'date'])) ??
          DateTime.now(),
      totalSeats: totalSeats,
      remainingSeats: resolvedRemainingSeats,
      price: _doubleFrom(_pick(map, ['price', 'cost', 'amount'])),
      description: _stringFrom(_pick(map, ['description', 'details'])),
      photos: photos,
      category: _stringFrom(_pick(map, ['category', 'type'])),
      startLocation: _stringFrom(
        _pick(map, ['startLocation', 'start_location', 'pickupLocation']),
      ),
      lastJoiningTime: _dateTimeFrom(
        _pick(map, ['lastJoiningTime', 'last_joining_time', 'lastJoinTime']),
      ),
      endTime: _stringFrom(_pick(map, ['endTime', 'end_time'])),
      endLocation: _stringFrom(
        _pick(map, ['endLocation', 'end_location', 'dropLocation']),
      ),
      route: _routeFrom(_pick(map, ['route', 'itinerary', 'stops'])),
      operatorName: _stringFrom(
        _pick(map, ['operatorName', 'operator', 'organizerName']),
      ),
      whatsIncluded: _toStringList(
        _pick(map, ['whatsIncluded', 'whatIncluded', 'inclusions']),
      ),
      tourFeatures: _toStringList(
        _pick(map, ['tourFeatures', 'features', 'highlights']),
      ),
    );
  }

  List<RouteStop> _routeFrom(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) => RouteStop(
            location: _stringFrom(_pick(item, ['location', 'place', 'name'])),
            time: _stringFrom(_pick(item, ['time', 'at'])),
          ),
        )
        .where((stop) => stop.location.isNotEmpty || stop.time.isNotEmpty)
        .toList(growable: false);
  }

  dynamic _pick(Map map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return map[key];
      }
    }
    return null;
  }

  List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  String _stringFrom(dynamic value) => (value ?? '').toString().trim();

  int _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _doubleFrom(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _dateTimeFrom(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
