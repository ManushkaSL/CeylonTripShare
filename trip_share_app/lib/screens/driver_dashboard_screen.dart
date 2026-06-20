import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/services/location_service.dart';
import 'package:trip_share_app/screens/chat_screen.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/theme/design_system.dart';

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
  int _selectedIndex = 0;

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
            backgroundColor: DesignColors.warning,
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
              backgroundColor: DesignColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not start sharing. Check location permissions.',
              ),
              backgroundColor: DesignColors.error,
            ),
          );
        }
      }
    } else {
      // Already sharing on a different tour
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Stop sharing on the current tour first.'),
            backgroundColor: DesignColors.warning,
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
            backgroundColor: DesignColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: DesignColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              JoinedTourService().clearCache();
              await _auth.logout();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text('Log Out', style: TextStyle(color: DesignColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _auth.userEmail;

    return Scaffold(
      backgroundColor: DesignColors.background,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: kIsWeb
              ? AppBar(
                  backgroundColor: DesignColors.surface.withOpacity(0.95),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Driver Dashboard',
                    style: TextStyle(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.logout, color: DesignColors.primary),
                      onPressed: _showLogoutDialog,
                    ),
                  ],
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AppBar(
                    backgroundColor: DesignColors.surface.withOpacity(0.95),
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    title: const Text(
                      'Driver Dashboard',
                      style: TextStyle(
                        color: DesignColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.logout, color: DesignColors.primary),
                        onPressed: _showLogoutDialog,
                      ),
                    ],
                  ),
                ),
        ),
      ),
      body: _selectedIndex == 0
          ? Column(
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                ),
                _buildStatusBanner(),
                const SizedBox(height: 16),
                Expanded(child: _buildToursList(userEmail)),
              ],
            )
          : _buildDriverProfileSection(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: DesignColors.surface,
        surfaceTintColor: DesignColors.surface,
        indicatorColor: DesignColors.primary.withOpacity(0.16),
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Assigned Tours',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDriverProfileSection() {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + kToolbarHeight + 16,
        16,
        24,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: DesignColors.primary.withOpacity(0.12),
                backgroundImage: _auth.photoUrl.isNotEmpty
                    ? NetworkImage(_auth.photoUrl)
                    : null,
                child: _auth.photoUrl.isEmpty
                    ? Text(
                        _auth.userName.isNotEmpty
                            ? _auth.userName[0].toUpperCase()
                            : 'D',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: DesignColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _auth.userName.isNotEmpty ? _auth.userName : 'Driver',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _auth.userEmail,
                      style: TextStyle(
                        fontSize: 13,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Driver Tools',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.primary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Use Assigned Tours to share live location and chat with passengers in tours already assigned to you.',
                style: TextStyle(fontSize: 13, color: DesignColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _showLogoutDialog,
            icon: Icon(Icons.logout, color: DesignColors.error),
            label: Text(
              'Log Out',
              style: TextStyle(
                color: DesignColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: DesignColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
                ? [DesignColors.primary, DesignColors.primaryDark]
                : [DesignColors.textSecondary, DesignColors.divider],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (_isSharing
                          ? DesignColors.primary
                          : DesignColors.textSecondary)
                      .withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.85),
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
                  color: DesignColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.success.withOpacity(0.6),
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
              style: TextStyle(color: DesignColors.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: DesignColors.primary),
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
                    color: DesignColors.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No assigned tours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assigned bookings will appear here.',
                    style: TextStyle(
                      fontSize: 14,
                      color: DesignColors.textSecondary,
                    ),
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
            final tourName = data['tourName'] ?? 'Unnamed Tour';
            final tourDate = data['tourDate'] as String? ?? '';
            final totalPersons = data['totalPersons'] ?? 0;
            final pickupLocation = data['pickupLocation'] ?? '';
            final tourId = data['tourId'] ?? '';
            final isSharingThis = _isSharing && _sharingTourId == tourId;

            return _buildBookingCard(
              tourId: tourId,
              tourName: tourName,
              tourDate: tourDate,
              totalPersons: totalPersons,
              pickupLocation: pickupLocation,
              isSharingThis: isSharingThis,
            );
          },
        );
      },
    );
  }

  Widget _buildBookingCard({
    required String tourId,
    required String tourName,
    required String tourDate,
    required int totalPersons,
    required String pickupLocation,
    required bool isSharingThis,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: DesignColors.success,
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
                    onPressed: () => _toggleSharing(tourId, tourName),
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
                          ? DesignColors.success
                          : Colors.grey.withOpacity(0.15),
                      foregroundColor: isSharingThis
                          ? Colors.white
                          : DesignColors.success,
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
                      backgroundColor: DesignColors.success.withOpacity(0.15),
                      foregroundColor: DesignColors.success,
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
