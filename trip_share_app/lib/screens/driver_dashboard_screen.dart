import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/screens/driver_tour_details_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/theme/design_system.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        elevation: 0,
        title: Text(
          switch (_selectedIndex) {
            0 => 'Dashboard',
            1 => 'Driver Chat',
            _ => 'Driver Profile',
          },
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildPlaceholder(
            Icons.chat_bubble_outline_rounded,
            'Driver Chat',
            'Chat details will be added next.',
          ),
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: DesignColors.surface,
        indicatorColor: DesignColors.primary.withOpacity(0.14),
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageState(
            Icons.error_outline_rounded,
            'Could not load assigned tours',
            snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: DesignColors.primary),
          );
        }

        final assignments = _groupAssignedTours(snapshot.data!.docs);
        if (assignments.isEmpty) {
          return _messageState(
            Icons.assignment_outlined,
            'No assigned tours',
            'Tours assigned to your driver account will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              '${assignments.length} assigned '
              '${assignments.length == 1 ? 'tour' : 'tours'}',
              style: const TextStyle(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final assignment in assignments)
              _buildTourCard(assignment),
          ],
        );
      },
    );
  }

  List<_DriverTourAssignment> _groupAssignedTours(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final userEmail = _auth.userEmail.trim().toLowerCase();
    final userId = _auth.userId;
    final grouped = <String, _DriverTourAssignment>{};

    for (final doc in docs) {
      final data = doc.data();
      final driverEmail = (data['driverEmail'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final driverId = (data['driverId'] ?? '').toString();
      final isAssigned =
          (userEmail.isNotEmpty && driverEmail == userEmail) ||
          (userId.isNotEmpty && driverId == userId);
      if (!isAssigned) continue;

      final tourDate =
          DateTime.tryParse(data['tourDate']?.toString() ?? '') ??
          DateTime.now();
      final instanceId = (data['instanceId'] ?? '').toString();
      final tourId = (data['tourId'] ?? '').toString();
      final templateTourId = (data['templateTourId'] ?? tourId).toString();
      final key = instanceId.isNotEmpty
          ? instanceId
          : '$tourId|${tourDate.toIso8601String()}';
      final assignment = grouped.putIfAbsent(
        key,
        () => _DriverTourAssignment(
          instanceId: instanceId.isNotEmpty ? instanceId : tourId,
          templateTourId: templateTourId,
          tourName: (data['tourName'] ?? 'Unnamed Tour').toString(),
          startDate: tourDate,
        ),
      );

      final passengerCount = _toInt(data['totalPersons']);
      assignment.passengerCount += passengerCount;
      assignment.passengers.add(
        DriverPassengerRecord(
          name: _passengerName(data),
          phoneNumber: (data['phoneNumber'] ?? '').toString(),
          pickupLocation: (data['pickupLocation'] ?? '').toString(),
          passengerCount: passengerCount,
        ),
      );
    }

    final result = grouped.values.toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return result;
  }

  String _passengerName(Map<String, dynamic> data) {
    final passengers = data['passengers'];
    if (passengers is List && passengers.isNotEmpty) {
      final first = passengers.first;
      if (first is Map) {
        final name = (first['name'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    }
    final fallback = (data['userName'] ?? data['name'] ?? '').toString().trim();
    return fallback.isEmpty ? 'Passenger' : fallback;
  }

  Widget _buildTourCard(_DriverTourAssignment assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: DesignColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DesignColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DriverTourDetailsScreen(
                instanceId: assignment.instanceId,
                templateTourId: assignment.templateTourId,
                tourName: assignment.tourName,
                startDate: assignment.startDate,
                passengerCount: assignment.passengerCount,
                passengers: assignment.passengers,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DesignColors.primary.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: DesignColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.tourName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _cardInfo(
                      Icons.calendar_month_rounded,
                      _formatDateTime(assignment.startDate),
                    ),
                    const SizedBox(height: 7),
                    _cardInfo(
                      Icons.groups_rounded,
                      '${assignment.passengerCount} '
                          '${assignment.passengerCount == 1 ? 'passenger' : 'passengers'}',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 17, color: DesignColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: DesignColors.primary.withOpacity(0.12),
          child: Text(
            _auth.userName.isEmpty
                ? 'D'
                : _auth.userName.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: DesignColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _auth.userName.isEmpty ? 'Driver' : _auth.userName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: DesignColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _auth.userEmail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: DesignColors.textSecondary),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _showLogoutDialog,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: DesignColors.error,
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: DesignColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(IconData icon, String title, String subtitle) {
    return _messageState(icon, title, subtitle);
  }

  Widget _messageState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: DesignColors.textSecondary.withOpacity(0.45),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: DesignColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) await _auth.logout();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} '
        '$period';
  }
}

class _DriverTourAssignment {
  final String instanceId;
  final String templateTourId;
  final String tourName;
  final DateTime startDate;
  int passengerCount = 0;
  final List<DriverPassengerRecord> passengers = [];

  _DriverTourAssignment({
    required this.instanceId,
    required this.templateTourId,
    required this.tourName,
    required this.startDate,
  });
}
