import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/location_service.dart';
import 'package:trip_share_app/screens/chat_screen.dart';
import 'package:trip_share_app/models/tour.dart';

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
            content: Text('Stop sharing on the current tour first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _openChat(String tourId) async {
    try {
      debugPrint('💬 Opening chat for tour: $tourId');

      // Fetch the tour from Firestore
      final tourDoc = await _firestore.collection('tours').doc(tourId).get();
      debugPrint('📡 Tour document exists: ${tourDoc.exists}');

      if (!tourDoc.exists) {
        debugPrint('❌ Tour document not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tour not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final data = tourDoc.data() as Map<String, dynamic>;
      debugPrint('✅ Tour data loaded: ${data['name']}');

      final tour = Tour(
        id: tourDoc.id,
        name: data['name'] ?? 'Unnamed Tour',
        imageUrl: data['imageUrl'] ?? '',
        startDate:
            (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        totalSeats: data['totalSeats'] ?? 0,
        remainingSeats: data['remainingSeats'] ?? 0,
        price: (data['price'] ?? 0).toDouble(),
        description: data['description'] ?? '',
        photos: List<String>.from(data['photos'] ?? []),
        category: data['category'] ?? '',
        startLocation: data['startLocation'] ?? '',
        endLocation: data['endLocation'] ?? '',
        endTime: data['endTime'] ?? '',
      );

      if (mounted) {
        debugPrint('🚀 Navigating to ChatScreen');
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ChatScreen(tour: tour)));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error opening chat: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _auth.userEmail;
    final isRootScreen = Navigator.of(context).canPop() == false;

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
              leading: isRootScreen
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1B5E20),
                      ),
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
              actions: isRootScreen
                  ? [
                      IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Color(0xFF1B5E20),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Log Out'),
                              content: const Text(
                                'Are you sure you want to log out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await _auth.logout();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text(
                                    'Log Out',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ]
                  : null,
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
          Expanded(child: _buildToursList(userEmail)),
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

  Widget _buildToursList(String userEmail) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('driverEmail', isEqualTo: userEmail)
          .orderBy('tourDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading assigned tours: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
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
                    'No assigned tours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Assigned bookings will appear here.',
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
            final bookingId = docs[index].id;
            final tourName = data['tourName'] ?? 'Unnamed Tour';
            final tourDate = data['tourDate'] as String? ?? '';
            final totalPersons = data['totalPersons'] ?? 0;
            final pickupLocation = data['pickupLocation'] ?? '';
            final userId = data['userId'] ?? '';
            final tourId = data['tourId'] ?? '';
            final isSharingThis = _isSharing && _sharingTourId == bookingId;

            return _buildBookingCard(
              bookingId: bookingId,
              tourId: tourId,
              tourName: tourName,
              tourDate: tourDate,
              totalPersons: totalPersons,
              pickupLocation: pickupLocation,
              userId: userId,
              isSharingThis: isSharingThis,
            );
          },
        );
      },
    );
  }

  Widget _buildBookingCard({
    required String bookingId,
    required String tourId,
    required String tourName,
    required String tourDate,
    required int totalPersons,
    required String pickupLocation,
    required String userId,
    required bool isSharingThis,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tourName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tourDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$totalPersons passengers',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pickupLocation,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleSharing(bookingId, tourName),
                    icon: Icon(
                      isSharingThis ? Icons.my_location : Icons.location_off,
                      size: 18,
                    ),
                    label: Text(
                      isSharingThis ? 'Sharing' : 'Share Location',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSharingThis
                          ? const Color(0xFF1B5E20)
                          : Colors.grey.withValues(alpha: 0.15),
                      foregroundColor: isSharingThis
                          ? Colors.white
                          : const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isSharingThis ? 2 : 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(tourId),
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF1B5E20,
                      ).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
