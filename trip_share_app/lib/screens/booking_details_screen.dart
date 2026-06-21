import 'package:flutter/material.dart';
import 'package:trip_share_app/models/booking.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/theme/design_system.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Tour tour;

  const BookingDetailsScreen({super.key, required this.tour});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  Booking? _booking;
  bool _isLoading = true;
  bool _isSaving = false;
  int _passengerCount = 1;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final booking = await JoinedTourService().loadBookingForTour(widget.tour);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _passengerCount = booking?.totalPersons ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load booking: $e'),
          backgroundColor: DesignColors.error,
        ),
      );
    }
  }

  Future<void> _savePassengerCount() async {
    final booking = _booking;
    if (booking == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await JoinedTourService().updateBookingPassengerCount(
        booking,
        _passengerCount,
      );
      if (!mounted) return;
      await _loadBooking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passenger count updated'),
          backgroundColor: DesignColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message.toString() : 'Update failed: $e',
          ),
          backgroundColor: DesignColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: const Text('My Booking'),
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DesignColors.primary),
            )
          : booking == null
              ? const Center(child: Text('Booking details were not found.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _detailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tour.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _row(
                            Icons.calendar_month_rounded,
                            'Tour date',
                            _formatDate(booking.tourDate),
                          ),
                          _row(
                            Icons.location_on_outlined,
                            'Pickup',
                            booking.pickupLocation,
                          ),
                          _row(
                            Icons.phone_outlined,
                            'Phone',
                            booking.phoneNumber,
                          ),
                          _row(
                            Icons.payments_outlined,
                            'Total',
                            '\$${booking.totalPrice.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _detailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Passenger count',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'For now, this is the only booking detail you can edit.',
                            style: TextStyle(
                              color: DesignColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _countButton(
                                Icons.remove_rounded,
                                _passengerCount > 1
                                    ? () => setState(
                                          () => _passengerCount--,
                                        )
                                    : null,
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '$_passengerCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: DesignColors.primary,
                                  ),
                                ),
                              ),
                              _countButton(
                                Icons.add_rounded,
                                () => setState(() => _passengerCount++),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _isSaving ||
                                      _passengerCount == booking.totalPersons
                                  ? null
                                  : _savePassengerCount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Passenger Count',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TourDetailScreen(tour: widget.tour),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline_rounded),
                      label: const Text('View Tour Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _detailCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.divider),
      ),
      child: child,
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: DesignColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: DesignColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: DesignColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countButton(IconData icon, VoidCallback? onPressed) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: DesignColors.primary,
        disabledBackgroundColor: DesignColors.divider,
        foregroundColor: Colors.white,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
