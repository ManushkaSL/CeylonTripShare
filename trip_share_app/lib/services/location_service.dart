import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_share_app/services/auth_service.dart';

/// Service that handles driver live-location sharing.
/// 
/// Driver starts sharing → GPS position is written to
/// `driver_locations/{tourId}` every few seconds.
/// Passengers subscribe to the same document to see the driver on a map.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  StreamSubscription<Position>? _positionSubscription;
  String? _activeTourId;

  bool get isSharing => _activeTourId != null;
  String? get activeTourId => _activeTourId;

  // ─── Driver side ──────────────────────────────────────

  /// Check & request location permissions. Returns true if granted.
  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Start sharing the driver's live location for [tourId].
  Future<bool> startSharing(String tourId) async {
    if (_activeTourId != null) {
      debugPrint('⚠️ Already sharing for tour $_activeTourId');
      return false;
    }

    final ok = await ensurePermissions();
    if (!ok) return false;

    _activeTourId = tourId;

    // Write initial position immediately
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _writePosition(tourId, pos);
    } catch (e) {
      debugPrint('⚠️ Could not get initial position: $e');
    }

    // Then stream updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres – update when moved ≥ 10 m
      ),
    ).listen(
      (pos) => _writePosition(tourId, pos),
      onError: (e) => debugPrint('❌ Location stream error: $e'),
    );

    debugPrint('📍 Started sharing location for tour $tourId');
    return true;
  }

  /// Stop sharing location.
  Future<void> stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_activeTourId != null) {
      // Mark as inactive in Firestore
      try {
        await _firestore
            .collection('driver_locations')
            .doc(_activeTourId)
            .update({'isActive': false});
      } catch (_) {}
      debugPrint('📍 Stopped sharing location for tour $_activeTourId');
      _activeTourId = null;
    }
  }

  Future<void> _writePosition(String tourId, Position pos) async {
    try {
      await _firestore.collection('driver_locations').doc(tourId).set({
        'tourId': tourId,
        'driverId': _authService.userId,
        'driverName': _authService.userName,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'accuracy': pos.accuracy,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error writing position: $e');
    }
  }

  // ─── Passenger side ───────────────────────────────────

  /// Stream driver location for a tour (passengers use this).
  Stream<Map<String, dynamic>?> streamDriverLocation(String tourId) {
    return _firestore
        .collection('driver_locations')
        .doc(tourId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data();
          if (data == null || data['isActive'] != true) return null;
          return data;
        });
  }
}
