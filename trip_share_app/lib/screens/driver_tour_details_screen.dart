import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/theme/design_system.dart';

class DriverPassengerRecord {
  final String name;
  final String phoneNumber;
  final String pickupLocation;
  final int passengerCount;

  const DriverPassengerRecord({
    required this.name,
    required this.phoneNumber,
    required this.pickupLocation,
    required this.passengerCount,
  });
}

class DriverTourDetailsScreen extends StatefulWidget {
  final String instanceId;
  final String templateTourId;
  final String tourName;
  final DateTime startDate;
  final int passengerCount;
  final List<DriverPassengerRecord> passengers;
  final List<String> bookingIds;

  const DriverTourDetailsScreen({
    super.key,
    required this.instanceId,
    required this.templateTourId,
    required this.tourName,
    required this.startDate,
    required this.passengerCount,
    required this.passengers,
    required this.bookingIds,
  });

  @override
  State<DriverTourDetailsScreen> createState() =>
      _DriverTourDetailsScreenState();
}

class _DriverTourDetailsScreenState extends State<DriverTourDetailsScreen> {
  bool _isCompleting = false;

  String get instanceId => widget.instanceId;
  String get templateTourId => widget.templateTourId;
  String get tourName => widget.tourName;
  DateTime get startDate => widget.startDate;
  int get passengerCount => widget.passengerCount;
  List<DriverPassengerRecord> get passengers => widget.passengers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Tour Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadTourDetails(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTourOverview(data),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Passengers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$passengerCount total',
                      style: const TextStyle(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (passengers.isEmpty)
                _emptyPassengers()
              else
                ...passengers.asMap().entries.map(
                  (entry) => _buildPassengerCard(entry.key + 1, entry.value),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isCompleting ? null : _confirmCompleteTour,
            icon: _isCompleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _isCompleting ? 'Completing...' : 'Complete Tour',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.success,
              foregroundColor: Colors.white,
              disabledBackgroundColor: DesignColors.success.withValues(
                alpha: 0.55,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCompleteTour() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete this tour?'),
        content: const Text(
          'This removes the tour from active assignments and moves it to '
          'Completed Tours in the admin panel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Tour'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCompleting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Please sign in again before completing this tour.');
      }
      if (widget.bookingIds.isEmpty) {
        throw StateError('No assigned bookings were found for this tour.');
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final completedAt = FieldValue.serverTimestamp();

      for (final bookingId in widget.bookingIds.toSet()) {
        batch.update(firestore.collection('bookings').doc(bookingId), {
          'status': 'completed',
          'completedAt': completedAt,
          'completedBy': user.uid,
          'updatedAt': completedAt,
        });
      }

      if (instanceId.isNotEmpty) {
        final instanceRef = firestore
            .collection('tour_instances')
            .doc(instanceId);
        final instanceSnapshot = await instanceRef.get();
        if (instanceSnapshot.exists) {
          batch.update(instanceRef, {
            'status': 'completed',
            'completedAt': completedAt,
            'completedBy': user.uid,
          });
        }

        final locationRef = firestore
            .collection('driver_locations')
            .doc(instanceId);
        final locationSnapshot = await locationRef.get();
        if (locationSnapshot.exists &&
            (locationSnapshot.data()?['driverId'] ?? '').toString() ==
                user.uid) {
          batch.delete(locationRef);
        }
      }

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour completed successfully.')),
      );
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      final message = error.code == 'permission-denied'
          ? 'Permission denied. Ask the admin to reassign this tour to your driver account.'
          : 'Could not complete the tour (${error.code}). Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      final message = error is StateError
          ? error.message.toString()
          : 'Could not complete the tour. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<Map<String, dynamic>> _loadTourDetails() async {
    final firestore = FirebaseFirestore.instance;
    if (instanceId.isNotEmpty) {
      final instance = await firestore
          .collection('tour_instances')
          .doc(instanceId)
          .get();
      if (instance.exists) return instance.data() ?? {};
    }

    final fallbackId = templateTourId.isNotEmpty ? templateTourId : instanceId;
    if (fallbackId.isEmpty) return {};
    final tour = await firestore.collection('tours').doc(fallbackId).get();
    return tour.data() ?? {};
  }

  Widget _buildTourOverview(Map<String, dynamic> data) {
    final startLocation = (data['startLocation'] ?? '').toString();
    final endLocation = (data['endLocation'] ?? '').toString();
    final description = (data['description'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tourName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: DesignColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow(
            Icons.calendar_month_rounded,
            'Start',
            _formatDateTime(startDate),
          ),
          if (startLocation.isNotEmpty)
            _detailRow(Icons.trip_origin_rounded, 'From', startLocation),
          if (endLocation.isNotEmpty)
            _detailRow(Icons.location_on_rounded, 'To', endLocation),
          _detailRow(Icons.groups_rounded, 'Passengers', '$passengerCount'),
          if (description.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              description,
              style: const TextStyle(
                color: DesignColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: DesignColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(int number, DriverPassengerRecord passenger) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: DesignColors.primary.withOpacity(0.12),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  passenger.name.isEmpty ? 'Passenger' : passenger.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ),
              if (passenger.passengerCount > 1)
                Text(
                  '${passenger.passengerCount} people',
                  style: const TextStyle(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _passengerInfo(
            Icons.phone_outlined,
            'Contact number',
            passenger.phoneNumber,
          ),
          const SizedBox(height: 10),
          _passengerInfo(
            Icons.location_on_outlined,
            'Pickup location',
            passenger.pickupLocation,
          ),
        ],
      ),
    );
  }

  Widget _passengerInfo(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: DesignColors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: DesignColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyPassengers() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'No passenger details available.',
          style: TextStyle(color: DesignColors.textSecondary),
        ),
      ),
    );
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
