import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/models/tour.dart';

class TourService {
  TourService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Cache for immediate updates
  final Map<String, Tour> _tourCache = {};

  /// Live set of tour IDs that have at least one booking document.
  Stream<Set<String>> streamTourIdsWithBookings() {
    return _firestore.collection('bookings').snapshots().map((snapshot) {
      final ids = <String>{};
      for (final doc in snapshot.docs) {
        final tourId = (doc.data()['tourId'] ?? '').toString();
        if (tourId.isNotEmpty) ids.add(tourId);
      }
      return ids;
    });
  }

  Tour _mergeWithCache(Tour parsed) {
    final cached = _tourCache[parsed.id];
    if (cached == null) return parsed;

    final cacheIsNewer =
        cached.bookedSeats > parsed.bookedSeats ||
        cached.bookedUserIds.length > parsed.bookedUserIds.length ||
        cached.remainingSeats < parsed.remainingSeats;

    return cacheIsNewer ? cached : parsed;
  }

  /// Update a tour in cache for immediate UI refresh after booking changes.
  void updateTourInCache(
    String tourId, {
    required int newRemainingSeats,
    int? newBookedSeats,
    List<String>? bookedUserIds,
    String? firstBookedUserId,
    Tour? baseTour,
  }) {
    final oldTour = _tourCache[tourId] ?? baseTour;
    if (oldTour == null) return;
    final bookedSeats = newBookedSeats ?? oldTour.bookedSeats;
    final userIds = bookedUserIds ?? oldTour.bookedUserIds;
    final firstBooker = firstBookedUserId ?? oldTour.firstBookedUserId;

    final totalSeats = oldTour.totalSeats > 0
        ? oldTour.totalSeats
        : (newBookedSeats != null
              ? newRemainingSeats + newBookedSeats
              : newRemainingSeats);

    _tourCache[tourId] = Tour(
      id: oldTour.id,
      name: oldTour.name,
      imageUrl: oldTour.imageUrl,
      startDate: oldTour.startDate,
      totalSeats: totalSeats,
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
      firstBookedUserId: firstBooker,
      bookedUserIds: userIds,
      bookedSeats: bookedSeats,
      sourceIdleTourId: oldTour.sourceIdleTourId,
    );
    debugPrint(
      '✅ Updated tour cache: $tourId remaining=$newRemainingSeats booked=$bookedSeats',
    );
  }

  void clearCache() {
    _tourCache.clear();
    debugPrint('🗑️ TourService cache cleared');
  }

  /// Reconcile tour seat/booking fields from the bookings collection so every
  /// account sees the same idle/active status after login or account switch.
  Future<void> syncTourStatusesFromBookings() async {
    try {
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      final bookedSeatsByTour = <String, int>{};
      final userIdsByTour = <String, Set<String>>{};

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final tourId = (data['tourId'] ?? '').toString();
        if (tourId.isEmpty) continue;

        final totalPersons = _intFrom(data['totalPersons']);
        bookedSeatsByTour[tourId] =
            (bookedSeatsByTour[tourId] ?? 0) + totalPersons;

        final userId = (data['userId'] ?? '').toString();
        if (userId.isNotEmpty) {
          userIdsByTour.putIfAbsent(tourId, () => {}).add(userId);
        }
      }

      for (final entry in bookedSeatsByTour.entries) {
        final tourId = entry.key;
        final totalBooked = entry.value;
        if (totalBooked <= 0) continue;

        final tourRef = _firestore.collection('tours').doc(tourId);
        final tourDoc = await tourRef.get();
        if (!tourDoc.exists) continue;

        final tourData = tourDoc.data() ?? {};
        final currentBookedSeats = _intFrom(tourData['bookedSeats']);
        final remaining = _intFrom(
          tourData['available_seats'] ?? tourData['remainingSeats'],
        );
        var total = _intFrom(tourData['totalSeats']);
        final bookedUserIds = _toStringList(tourData['bookedUserIds']);
        final firstBookedUserId = (tourData['firstBookedUserId'] ?? '')
            .toString();

        final hasBookingMarkers =
            currentBookedSeats > 0 ||
            bookedUserIds.isNotEmpty ||
            firstBookedUserId.isNotEmpty;
        final appearsIdle = total > 0 && remaining >= total;
        final needsSync =
            !hasBookingMarkers ||
            appearsIdle ||
            currentBookedSeats != totalBooked;

        if (!needsSync) continue;

        if (total <= 0) {
          total = remaining > 0 ? remaining + totalBooked : totalBooked;
        }
        final newAvailable = (total - totalBooked).clamp(0, total);
        final userIds = userIdsByTour[tourId]?.toList() ?? bookedUserIds;

        final update = <String, dynamic>{
          'totalSeats': total,
          'bookedSeats': totalBooked,
          'available_seats': newAvailable,
          'remainingSeats': newAvailable,
          'bookedUserIds': userIds,
        };
        if (firstBookedUserId.isEmpty && userIds.isNotEmpty) {
          update['firstBookedUserId'] = userIds.first;
        }

        await tourRef.update(update);
        debugPrint(
          '✅ Synced tour $tourId from bookings: $totalBooked/$total seats booked',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing tour statuses from bookings: $e');
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
    debugPrint(
      '📡 Starting combined tours+instances stream... Firestore: $_firestore',
    );

    final controller = StreamController<List<Tour>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? latestToursSnap;
    QuerySnapshot<Map<String, dynamic>>? latestInstSnap;
    Set<String> latestBookedTourIds = {};
    void emitCombinedLatest() {
      try {
        final toursDocs =
            latestToursSnap?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final instDocs =
            latestInstSnap?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        final tours = toursDocs
            .map((d) => _mergeWithCache(parseTour(d.data(), d.id)))
            .whereType<Tour>()
            .toList(growable: false);

        final instances = instDocs
            .map((d) => _mergeWithCache(parseTour(d.data(), d.id)))
            .whereType<Tour>()
            .toList(growable: false);

        final instanceSourceIds = instances
            .map((tour) => tour.sourceIdleTourId)
            .where((id) => id.isNotEmpty)
            .toSet();
        final visibleTours = tours
            .where(
              (tour) =>
                  tour.sourceIdleTourId.isEmpty ||
                  !instanceSourceIds.contains(tour.id),
            )
            .toList(growable: false);

        // If instances are unavailable (permission denied), synthesize
        // active markers for tours that have bookings so UI still shows
        // them as active.
        List<Tour> effectiveTours = visibleTours;
        if (instDocs.isEmpty && latestBookedTourIds.isNotEmpty) {
          effectiveTours = visibleTours
              .map((t) {
                if (latestBookedTourIds.contains(t.id)) {
                  // Ensure the tour appears active by marking at least one booked
                  // seat and a bookedUserIds entry. This doesn't modify Firestore.
                  return t.copyWith(
                    bookedSeats: t.bookedSeats > 0 ? t.bookedSeats : 1,
                    bookedUserIds: t.bookedUserIds.isNotEmpty
                        ? t.bookedUserIds
                        : ['_booked'],
                    firstBookedUserId: t.firstBookedUserId.isNotEmpty
                        ? t.firstBookedUserId
                        : '_booked',
                  );
                }
                return t;
              })
              .toList(growable: false);
          debugPrint(
            '🔧 Synthesized active markers for booked tours: ${latestBookedTourIds.toList()}',
          );
        }

        final combined = [...effectiveTours, ...instances]
          ..sort((a, b) => a.startDate.compareTo(b.startDate));

        for (final tour in combined) {
          _tourCache[tour.id] = tour;
        }

        debugPrint(
          '📣 Emitting combined tours+instances: count=${combined.length} ids=${combined.map((t) => t.id).take(8).toList()}',
        );
        controller.add(combined);
      } catch (e, st) {
        debugPrint('❌ Error combining tours and instances: $e');
        debugPrint('📍 $st');
        controller.addError(e, st);
      }
    }

    final toursSub = _firestore
        .collection('tours')
        .snapshots()
        .listen(
          (tSnap) {
            latestToursSnap = tSnap as QuerySnapshot<Map<String, dynamic>>;
            emitCombinedLatest();
          },
          onError: (e, st) {
            final errStr = e?.toString() ?? '$e';
            if (errStr.contains('permission-denied')) {
              debugPrint(
                '⚠️ Tours stream permission denied: $e — continuing without tours snapshots',
              );
              latestToursSnap = null;
              // Emit whatever we have (likely instances only)
              emitCombinedLatest();
            } else {
              debugPrint('❌ Tours stream error: $e');
              controller.addError(e, st);
            }
          },
        );

    final instSub = _firestore
        .collection('tour_instances')
        .snapshots()
        .listen(
          (iSnap) {
            latestInstSnap = iSnap as QuerySnapshot<Map<String, dynamic>>;
            emitCombinedLatest();
          },
          onError: (e, st) {
            final errStr = e?.toString() ?? '$e';
            if (errStr.contains('permission-denied')) {
              debugPrint(
                '⚠️ Instances stream permission denied: $e — hiding instances and continuing',
              );
              latestInstSnap = null;
              emitCombinedLatest();
            } else {
              debugPrint('❌ Instances stream error: $e');
              controller.addError(e, st);
            }
          },
        );

    // Also listen to bookings to infer which tours have active bookings when
    // `tour_instances` cannot be read by the client. This allows the UI to
    // show booked tours as active even under restrictive Firestore rules.
    Set<String> bookedIds = {};
    final bookingsSub = _firestore
        .collection('bookings')
        .snapshots()
        .listen(
          (bSnap) {
            try {
              bookedIds = bSnap.docs
                  .map((d) => (d.data()['tourId'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toSet();
            } catch (e) {
              bookedIds = {};
            }
            latestBookedTourIds = bookedIds;
            emitCombinedLatest();
          },
          onError: (e, st) {
            final errStr = e?.toString() ?? '$e';
            if (errStr.contains('permission-denied')) {
              debugPrint(
                '⚠️ Bookings stream permission denied: $e — cannot infer booked tours',
              );
              latestBookedTourIds = {};
              emitCombinedLatest();
            } else {
              debugPrint('❌ Bookings stream error: $e');
            }
          },
        );

    controller.onCancel = () async {
      await toursSub.cancel();
      await instSub.cancel();
      await bookingsSub.cancel();
    };

    return controller.stream;
  }

  Tour parseTour(Map<String, dynamic> map, String docId) {
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

    final bookedUserIds = _toStringList(
      _pick(map, ['bookedUserIds', 'booked_user_ids', 'bookedUsers']),
    );
    final firstBookedUserId = _stringFrom(
      _pick(map, ['firstBookedUserId', 'first_booked_user_id']),
    );

    final bookedSeats = bookedSeatsField != null
        ? _intFrom(bookedSeatsField)
        : bookedUserIds.length;
    final hasBookings =
        bookedSeats > 0 ||
        bookedUserIds.isNotEmpty ||
        firstBookedUserId.isNotEmpty;

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

    // IMPORTANT FIX: If totalSeats was not explicitly set in Firestore but
    // available_seats exists, use available_seats only before any booking.
    // After a booking, available_seats has already been reduced, so capacity
    // must be reconstructed from available + booked seats when possible.
    if (!hadExplicitTotalSeats && resolvedRemainingSeats > 0) {
      if (bookedSeats > 0) {
        totalSeats = resolvedRemainingSeats + bookedSeats;
        debugPrint(
          '   🔧 RECOVER: totalSeats missing after booking - setting totalSeats=$totalSeats from available + booked',
        );
        _writeInitialTotalSeatsToFirestore(docId, totalSeats);
      } else if (!hasBookings && totalSeats <= 0) {
        // Only establish capacity for brand-new tours. Never shrink totalSeats
        // down to remaining — that makes booked tours look idle.
        debugPrint(
          '   🔧 INIT: totalSeats not in Firestore but available_seats=$resolvedRemainingSeats - setting totalSeats=$resolvedRemainingSeats',
        );
        totalSeats = resolvedRemainingSeats;
        _writeInitialTotalSeatsToFirestore(docId, totalSeats);
      }
    }

    if (totalSeats <= 0) {
      debugPrint('   ⚠️ totalSeats still 0 - setting to 1');
      totalSeats = 1;
    }

    // FIX: If remainingSeats was missing or 0, but totalSeats is set and no one has actually booked, default to totalSeats
    if (remainingSeatsField == null && !hasBookings && totalSeats > 0) {
      debugPrint(
        '   🔧 FIX: remainingSeats was missing but totalSeats=$totalSeats and no bookings - defaulting remainingSeats to totalSeats',
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
      firstBookedUserId: firstBookedUserId,
      bookedUserIds: bookedUserIds,
      bookedSeats: bookedSeats,
      sourceIdleTourId: _stringFrom(
        _pick(map, ['sourceIdleTourId', 'source_idle_tour_id']),
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
