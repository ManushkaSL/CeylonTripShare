import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trip_share_app/models/tour.dart';

class TourService {
  TourService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Cache for immediate updates
  final Map<String, Tour> _tourCache = {};

  /// Update a tour in cache and trigger refresh
  void updateTourInCache(String tourId, int newRemainingSeats) {
    if (_tourCache.containsKey(tourId)) {
      final oldTour = _tourCache[tourId]!;
      // Create updated tour with new remaining seats
      final updatedTour = Tour(
        id: oldTour.id,
        name: oldTour.name,
        imageUrl: oldTour.imageUrl,
        startDate: oldTour.startDate,
        totalSeats: oldTour.totalSeats,
        remainingSeats: newRemainingSeats,
        price: oldTour.price,
        description: oldTour.description,
        photos: oldTour.photos,
        category: oldTour.category,
        startLocation: oldTour.startLocation,
        lastJoiningTime: oldTour.lastJoiningTime,
        endTime: oldTour.endTime,
        endLocation: oldTour.endLocation,
        route: oldTour.route,
        operatorName: oldTour.operatorName,
        whatsIncluded: oldTour.whatsIncluded,
        tourFeatures: oldTour.tourFeatures,
        firstBookedUserId: oldTour.firstBookedUserId,
        bookedUserIds: oldTour.bookedUserIds,
      );
      _tourCache[tourId] = updatedTour;
      debugPrint(
        '✅ Updated tour cache: $tourId remainingSeats=$newRemainingSeats',
      );
    }
  }

  /// Parse booking close date and time fields into DateTime
  DateTime? _parseBookingCloseDateTime(Map<String, dynamic> map) {
    try {
      final dateStr = map['booking_close_date'] as String?;
      final timeStr = map['booking_close_time'] as String?;

      if (dateStr == null || timeStr == null) {
        return null;
      }

      // Parse date: "2026-03-28"
      final date = DateTime.parse(dateStr);

      // Parse time: "10:29 PM" or "10 PM" or "2 PM"
      // Extract hour and minute
      final timeParts = timeStr.trim().split(RegExp(r'[\s:]'));

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = 0;

      // Check if there's minute info
      if (timeParts.length > 1) {
        // Check if second part is minute (numeric) or period (AM/PM)
        final secondPart = timeParts[1];
        if (int.tryParse(secondPart) != null) {
          minute = int.parse(secondPart);
          // Period would be in third part if present
        }
      }

      // Convert 12-hour format to 24-hour
      // Check if time contains "PM" in the original string
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');

      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }

      // Combine into DateTime
      final closeDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      return closeDateTime;
    } catch (e) {
      debugPrint('⚠️ Error parsing booking close time: $e');
      return null;
    }
  }

  Stream<List<Tour>> streamTours() {
    debugPrint('📡 Starting tour stream... Firestore instance: $_firestore');

    try {
      final stream = _firestore.collection('tours').snapshots();
      debugPrint('📡 Collection reference created successfully');

      return stream
          .map((snapshot) {
            try {
              debugPrint(
                '📥 Received snapshot with ${snapshot.docs.length} tour documents',
              );
              debugPrint(
                '📥 Snapshot metadata - source: ${snapshot.metadata.hasPendingWrites ? "pending" : "server"}',
              );

              if (snapshot.docs.isEmpty) {
                debugPrint('⚠️ Tours collection is empty!');
                return const <Tour>[];
              }

              final tours = snapshot.docs
                  .map((doc) {
                    try {
                      return _tourFromMap(doc.data(), doc.id);
                    } catch (e) {
                      debugPrint('⚠️ Error parsing tour ${doc.id}: $e');
                      return null;
                    }
                  })
                  .whereType<Tour>()
                  .toList(growable: false);

              // Populate cache for immediate updates after bookings
              for (final tour in tours) {
                _tourCache[tour.id] = tour;
              }

              debugPrint(
                '✅ Successfully loaded ${tours.length} tours out of ${snapshot.docs.length} documents',
              );

              final sortedTours = [...tours]
                ..sort((a, b) => a.startDate.compareTo(b.startDate));
              return sortedTours;
            } catch (e, st) {
              debugPrint('❌ Error mapping tour data: $e');
              debugPrint('📍 Stack trace: $st');
              throw e;
            }
          })
          .handleError((error, stackTrace) {
            debugPrint('❌ ==== STREAM ERROR ====');
            debugPrint('❌ Error: $error');
            debugPrint('❌ Error type: ${error.runtimeType}');
            if (error is FirebaseException) {
              debugPrint('🔥 Firebase error code: ${error.code}');
              debugPrint('🔥 Firebase error message: ${error.message}');
            }
            debugPrint('❌ Stack trace: $stackTrace');
            debugPrint('❌ ==== END STREAM ERROR ====');
            throw error;
          });
    } catch (e, st) {
      debugPrint('❌ Fatal error creating stream: $e');
      debugPrint('📍 Stack trace: $st');
      throw e;
    }
  }

  Tour _tourFromMap(Map<String, dynamic> map, String docId) {
    final photos = _toStringList(_pick(map, ['photos', 'images', 'gallery']));
    final imageUrl = _stringFrom(
      _pick(map, ['imageUrl', 'image', 'image_url', 'thumbnail']),
    );

    final seatInfo = _pick(map, ['seatInfo', 'seat_info', 'capacityInfo']);
    final details = _pick(map, ['details', 'metadata', 'tourDetails']);

    var totalSeats = _intFrom(
      _pick(map, [
        'totalSeats',
        'total_seats',
        'totalSeat',
        'total_seat',
        'seats',
        'capacity',
        'maxSeats',
        'max_seats',
      ]),
    );

    // Track if totalSeats was explicitly set in Firestore
    final hadExplicitTotalSeats = totalSeats > 0;

    dynamic remainingSeatsField = _pick(map, [
      'available_seats', // Prioritize Firestore field name first
      'availableSeats',
      'remainingSeats',
      'remaining_seats',
      'remainingSeat',
      'remaining_seat',
      'availableSeat',
      'available_seat',
      'seatsAvailable',
      'seats_available',
      'available',
      'remaining',
    ]);

    debugPrint(
      '   ❌ DEBUG: ${map['name']}: remainingSeatsField=$remainingSeatsField | available_seats from map: ${map['available_seats']}',
    );

    dynamic bookedSeatsField = _pick(map, [
      'bookedSeats',
      'booked_seats',
      'booked',
      'reservedSeats',
      'reserved_seats',
      'reserved',
      'joinedCount',
      'joined_count',
      'participantsCount',
      'participants_count',
    ]);

    debugPrint(
      '   ❌ DEBUG: ${map['name']}: bookedSeatsField=$bookedSeatsField',
    );
    debugPrint(
      '   ❌ DEBUG: ${map['name']}: FULL MAP remainingSeats check: ${map.containsKey('remainingSeats')} = ${map['remainingSeats']}',
    );
    debugPrint(
      '   ❌ DEBUG: ${map['name']}: All keys in map: ${map.keys.toList()}',
    );

    if (seatInfo is Map) {
      if (totalSeats <= 0) {
        totalSeats = _intFrom(
          _pick(seatInfo, [
            'total',
            'totalSeats',
            'capacity',
            'max',
            'maxSeats',
          ]),
        );
      }

      remainingSeatsField ??= _pick(seatInfo, [
        'available',
        'remaining',
        'availableSeats',
        'remainingSeats',
        'left',
      ]);

      bookedSeatsField ??= _pick(seatInfo, [
        'booked',
        'bookedSeats',
        'reserved',
        'reservedSeats',
        'joined',
      ]);
    }

    // Check details/metadata for seat information if not found yet
    if (details is Map) {
      if (totalSeats <= 0) {
        totalSeats = _intFrom(
          _pick(details, [
            'totalSeats',
            'total_seats',
            'total',
            'capacity',
            'maxSeats',
            'max_seats',
          ]),
        );
      }

      remainingSeatsField ??= _pick(details, [
        'availableSeats',
        'available_seats',
        'availableSeatCount',
        'available_seat_count',
        'remaining',
        'remainingSeats',
        'remaining_seats',
        'available',
      ]);

      bookedSeatsField ??= _pick(details, [
        'bookedSeats',
        'booked_seats',
        'bookedCount',
        'booked_count',
      ]);
    }

    final bookedSeats = bookedSeatsField != null
        ? _intFrom(bookedSeatsField)
        : 0;

    final parsedRemainingSeats = remainingSeatsField != null
        ? _intFrom(remainingSeatsField)
        : (totalSeats > 0 ? totalSeats - bookedSeats : totalSeats);

    debugPrint(
      '   📊 Parsed: remainingSeatsField=$remainingSeatsField, parsedRemainingSeats=$parsedRemainingSeats',
    );

    var resolvedRemainingSeats = parsedRemainingSeats < 0
        ? 0
        : parsedRemainingSeats;

    debugPrint(
      '   📊 After <0 check: resolvedRemainingSeats=$resolvedRemainingSeats, totalSeats=$totalSeats',
    );

    if (totalSeats > 0 && resolvedRemainingSeats > totalSeats) {
      debugPrint(
        '   ⚠️ remainingSeats ($resolvedRemainingSeats) > totalSeats ($totalSeats) - capping to totalSeats',
      );
      resolvedRemainingSeats = totalSeats;
    }

    // IMPORTANT FIX: If totalSeats was not explicitly set in Firestore but available_seats exists,
    // use available_seats as the INITIAL total capacity (it should never change after this)
    if (!hadExplicitTotalSeats && resolvedRemainingSeats > 0) {
      debugPrint(
        '   🔧 INIT: totalSeats not in Firestore but available_seats=$resolvedRemainingSeats - setting totalSeats=$resolvedRemainingSeats',
      );
      totalSeats = resolvedRemainingSeats;

      // Write totalSeats back to Firestore so it persists and this only happens once
      _writeInitialTotalSeatsToFirestore(docId, totalSeats);
    }

    if (totalSeats <= 0) {
      debugPrint('   ⚠️ totalSeats still 0 - setting to 1');
      totalSeats = 1;
    }

    // FIX: If remainingSeats was missing or 0, but totalSeats is set and no one has actually booked, default to totalSeats
    if ((remainingSeatsField == null || resolvedRemainingSeats == 0) &&
        bookedSeats == 0 &&
        totalSeats > 0) {
      debugPrint(
        '   🔧 FIX: remainingSeats was missing/0 but totalSeats=$totalSeats and no bookings - defaulting remainingSeats to totalSeats',
      );
      resolvedRemainingSeats = totalSeats;
    }

    debugPrint(
      '   ✅ Final: totalSeats=$totalSeats, remainingSeats=$resolvedRemainingSeats',
    );

    final name = _stringFrom(_pick(map, ['name', 'title', 'tourName']));

    // Parse booking close time from three fields or fallback to legacy field
    DateTime? lastJoiningTime = _parseBookingCloseDateTime(map);
    lastJoiningTime ??= _dateTimeFrom(
      _pick(map, ['lastJoiningTime', 'last_joining_time', 'lastJoinTime']),
    );

    debugPrint(
      '🎫 Tour $name: totalSeats=$totalSeats, remainingSeats=$resolvedRemainingSeats',
    );

    return Tour(
      id: docId,
      name: name,
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
      lastJoiningTime: lastJoiningTime,
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
      firstBookedUserId: _stringFrom(
        _pick(map, ['firstBookedUserId', 'first_booked_user_id']),
      ),
      bookedUserIds: _toStringList(
        _pick(map, ['bookedUserIds', 'booked_user_ids', 'bookedUsers']),
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

  /// Write initial totalSeats to Firestore if it was missing
  /// This ensures the capacity is set only once from available_seats
  void _writeInitialTotalSeatsToFirestore(String tourId, int totalSeats) {
    FirebaseFirestore.instance
        .collection('tours')
        .doc(tourId)
        .update({'totalSeats': totalSeats})
        .then((_) {
          debugPrint(
            '✅ Wrote initial totalSeats=$totalSeats to Firestore for tour $tourId',
          );
        })
        .catchError((e) {
          debugPrint(
            '⚠️ Could not write totalSeats to Firestore (non-critical): $e',
          );
        });
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
    if (value is String) {
      final direct = int.tryParse(value.trim());
      if (direct != null) return direct;

      final firstNumber = RegExp(r'-?\d+').firstMatch(value);
      if (firstNumber != null) {
        return int.tryParse(firstNumber.group(0) ?? '') ?? 0;
      }
    }
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
