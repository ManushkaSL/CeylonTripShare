import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_share_app/services/location_service.dart';

/// Passenger view – shows the driver's live location on a Google Map
/// for a specific tour.
class LiveTrackingScreen extends StatefulWidget {
  final String tourId;
  final String tourName;

  const LiveTrackingScreen({
    super.key,
    required this.tourId,
    required this.tourName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  StreamSubscription? _locationSub;

  LatLng? _driverPosition;
  double _driverHeading = 0;
  String _driverName = 'Driver';
  bool _isDriverOnline = false;
  DateTime? _lastUpdate;

  // Default camera — Sri Lanka center
  static const _defaultCamera = CameraPosition(
    target: LatLng(7.8731, 80.7718),
    zoom: 8,
  );

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenToDriverLocation() {
    _locationSub = _locationService
        .streamDriverLocation(widget.tourId)
        .listen((data) {
      if (!mounted) return;

      if (data != null) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final heading = (data['heading'] as num?)?.toDouble() ?? 0;
        final name = data['driverName'] as String? ?? 'Driver';

        if (lat != null && lng != null) {
          final newPos = LatLng(lat, lng);
          setState(() {
            _driverPosition = newPos;
            _driverHeading = heading;
            _driverName = name;
            _isDriverOnline = true;
            _lastUpdate = DateTime.now();
          });

          // Animate camera to driver position
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPos, 15),
          );
        }
      } else {
        setState(() {
          _isDriverOnline = false;
        });
      }
    });
  }

  Set<Marker> _buildMarkers() {
    if (_driverPosition == null) return {};

    return {
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition!,
        rotation: _driverHeading,
        infoWindow: InfoWindow(
          title: _driverName,
          snippet: 'Vehicle location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tourName,
              style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isDriverOnline ? const Color(0xFF4CAF50) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isDriverOnline ? 'Driver is live' : 'Driver offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDriverOnline ? const Color(0xFF4CAF50) : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _defaultCamera,
            onMapCreated: (controller) {
              _mapController = controller;
              // If driver position already loaded, move camera
              if (_driverPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_driverPosition!, 15),
                );
              }
            },
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Driver info card at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: _buildDriverInfoCard(),
          ),

          // Re-center button
          if (_driverPosition != null)
            Positioned(
              right: 16,
              bottom: 140 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                onPressed: () {
                  if (_driverPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_driverPosition!, 15),
                    );
                  }
                },
                child: const Icon(
                  Icons.my_location,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isDriverOnline
          ? Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF1B5E20),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _lastUpdate != null
                                ? 'Updated ${_timeSince(_lastUpdate!)}'
                                : 'Live',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xFF4CAF50),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_off,
                    color: Colors.grey,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Driver is offline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Location sharing is not active yet',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
