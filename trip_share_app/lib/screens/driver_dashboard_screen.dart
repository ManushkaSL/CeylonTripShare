import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/location_service.dart';

/// Driver dashboard accessible from Profile → "Driver Dashboard".
/// Shows tours the driver is assigned to (guideId == current user)
/// and lets them start / stop live-location sharing per tour.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _auth = AuthService();
  final _location = LocationService();
  final _firestore = FirebaseFirestore.instance;

  bool _isSharing = false;
  String? _sharingTourId;

  @override
  void initState() {
    super.initState();
    _isSharing = _location.isSharing;
    _sharingTourId = _location.activeTourId;
  }

  Future<void> _toggleSharing(String tourId, String tourName) async {
    if (_isSharing && _sharingTourId == tourId) {
      // Stop sharing
      await _location.stopSharing();
      if (mounted) {
        setState(() {
          _isSharing = false;
          _sharingTourId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stopped sharing location for "$tourName"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else if (!_isSharing) {
      // Start sharing
      final started = await _location.startSharing(tourId);
      if (mounted) {
        if (started) {
          setState(() {
            _isSharing = true;
            _sharingTourId = tourId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sharing location for "$tourName"'),
              backgroundColor: const Color(0xFF1B5E20),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not start sharing. Check location permissions.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Already sharing on a different tour
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Stop sharing on the current tour first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Driver Dashboard',
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
          ),
          // Status banner
          _buildStatusBanner(),
          const SizedBox(height: 16),
          // Tour list
          Expanded(
            child: _buildToursList(userId),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSharing
                ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                : [const Color(0xFF424242), const Color(0xFF616161)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isSharing ? const Color(0xFF1B5E20) : Colors.grey)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isSharing ? Icons.my_location : Icons.location_off,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSharing
                        ? 'Sharing Live Location'
                        : 'Location Sharing Off',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSharing
                        ? 'Passengers can see your vehicle on the map'
                        : 'Tap a tour below to start sharing',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSharing)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToursList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tours')
          .where('guideId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading tours: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF1B5E20),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No tours assigned',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tours where you are the guide will appear here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final tourId = docs[index].id;
            final tourName = data['name'] ?? 'Unnamed Tour';
            final imageUrl = data['imageUrl'] ?? data['image'] ?? '';
            final startDate = data['startDate'] as String? ?? '';
            final isSharingThis = _isSharing && _sharingTourId == tourId;

            return _buildTourCard(
              tourId: tourId,
              tourName: tourName,
              imageUrl: imageUrl,
              startDate: startDate,
              isSharingThis: isSharingThis,
            );
          },
        );
      },
    );
  }

  Widget _buildTourCard({
    required String tourId,
    required String tourName,
    required String imageUrl,
    required String startDate,
    required bool isSharingThis,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSharingThis
              ? Border.all(color: const Color(0xFF1B5E20), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Tour image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _tourPlaceholder(),
                      )
                    : _tourPlaceholder(),
              ),
              const SizedBox(width: 14),
              // Tour info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (startDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        startDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (isSharingThis) ...[
                      const SizedBox(height: 6),
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
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Share button
              GestureDetector(
                onTap: () => _toggleSharing(tourId, tourName),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSharingThis
                        ? Colors.red.withValues(alpha: 0.1)
                        : const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSharingThis ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: isSharingThis
                        ? Colors.red
                        : const Color(0xFF1B5E20),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tourPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.directions_bus,
        color: Color(0xFF1B5E20),
        size: 28,
      ),
    );
  }
}
