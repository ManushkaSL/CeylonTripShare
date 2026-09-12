import 'package:flutter/material.dart';
import 'package:trip_share_app/models/community_ride.dart';
import 'package:trip_share_app/screens/chat_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/community_ride_service.dart';
import 'package:trip_share_app/theme/design_system.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';

class CommunityRidesBody extends StatefulWidget {
  const CommunityRidesBody({super.key});

  @override
  State<CommunityRidesBody> createState() => _CommunityRidesBodyState();
}

class _CommunityRidesBodyState extends State<CommunityRidesBody> {
  final _formKey = GlobalKey<FormState>();
  final _service = CommunityRideService();
  final _origin = TextEditingController();
  final _pickup = TextEditingController();
  final _destination = TextEditingController();
  final _dropoff = TextEditingController();
  final _routeStops = TextEditingController();
  final _seats = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _hostPhone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _driverName = TextEditingController();
  final _driverPhone = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _vehicleType = TextEditingController();
  final _notes = TextEditingController();

  int _viewIndex = 0;
  bool _isHostDriver = true;
  bool _hasAirConditioning = false;
  bool _luggageAvailable = true;
  bool _submitting = false;
  late DateTime _departureAt;
  late DateTime _estimatedArrivalAt;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _departureAt = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
    _estimatedArrivalAt = _departureAt.add(const Duration(hours: 4));
    AuthService().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    for (final controller in [
      _origin,
      _pickup,
      _destination,
      _dropoff,
      _routeStops,
      _seats,
      _price,
      _hostPhone,
      _whatsapp,
      _driverName,
      _driverPhone,
      _licenseNumber,
      _vehicleType,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (!_estimatedArrivalAt.isAfter(_departureAt)) {
      _showError('Estimated arrival must be after departure.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitRide(
        hostPhone: _hostPhone.text,
        whatsappNumber: _whatsapp.text,
        isHostDriver: _isHostDriver,
        driverName: _driverName.text,
        driverPhone: _driverPhone.text,
        driverLicenseNumber: _licenseNumber.text,
        origin: _origin.text,
        pickupLocation: _pickup.text,
        destination: _destination.text,
        dropoffLocation: _dropoff.text,
        routeStops: _routeStops.text
            .split(',')
            .map((stop) => stop.trim())
            .where((stop) => stop.isNotEmpty)
            .toList(),
        departureAt: _departureAt,
        estimatedArrivalAt: _estimatedArrivalAt,
        offeredSeats: int.parse(_seats.text),
        pricePerPassenger: double.parse(_price.text),
        vehicleType: _vehicleType.text,
        hasAirConditioning: _hasAirConditioning,
        luggageAvailable: _luggageAvailable,
        notes: _notes.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride submitted for administrator approval.'),
          backgroundColor: DesignColors.success,
        ),
      );
      _clearJourneyFields();
      setState(() => _viewIndex = 1);
    } catch (error) {
      _showError(error is StateError ? error.message.toString() : '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearJourneyFields() {
    for (final controller in [
      _origin,
      _pickup,
      _destination,
      _dropoff,
      _routeStops,
      _price,
      _notes,
    ]) {
      controller.clear();
    }
    _seats.text = '1';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DesignColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    if (!auth.isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.route_rounded,
                size: 64,
                color: DesignColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Offer your available seats',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to submit a Community Ride for administrator approval.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignColors.textSecondary),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => LoginDialog.show(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.add_road_rounded),
                label: Text('Create Ride'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.list_alt_rounded),
                label: Text('My Rides'),
              ),
            ],
            selected: {_viewIndex},
            onSelectionChanged: (selection) {
              setState(() => _viewIndex = selection.first);
            },
          ),
        ),
        Expanded(child: _viewIndex == 0 ? _buildForm() : _buildMyRides()),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section(
            title: 'Route',
            icon: Icons.route_rounded,
            children: [
              _field(_origin, 'From', hint: 'Kandy'),
              _field(_pickup, 'Exact pickup location'),
              _field(_destination, 'Destination', hint: 'Colombo'),
              _field(_dropoff, 'Drop-off location'),
              _field(
                _routeStops,
                'Route or stops (optional)',
                hint: 'Kadugannawa, Kegalle, Warakapola',
                required: false,
              ),
            ],
          ),
          _section(
            title: 'Schedule',
            icon: Icons.schedule_rounded,
            children: [
              _dateTile('Departure', _departureAt, () async {
                final selected = await _pickDateTime(_departureAt);
                if (selected != null && mounted) {
                  setState(() {
                    _departureAt = selected;
                    if (!_estimatedArrivalAt.isAfter(selected)) {
                      _estimatedArrivalAt = selected.add(
                        const Duration(hours: 4),
                      );
                    }
                  });
                }
              }),
              _dateTile('Estimated arrival', _estimatedArrivalAt, () async {
                final selected = await _pickDateTime(_estimatedArrivalAt);
                if (selected != null && mounted) {
                  setState(() => _estimatedArrivalAt = selected);
                }
              }),
            ],
          ),
          _section(
            title: 'Seats & Pricing',
            icon: Icons.event_seat_rounded,
            children: [
              _field(
                _seats,
                'Available passenger seats',
                hint: 'Do not include the driver or existing companions',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final seats = int.tryParse(value ?? '');
                  return seats == null || seats < 1 || seats > 20
                      ? 'Enter between 1 and 20 available seats'
                      : null;
                },
              ),
              _field(
                _price,
                'Price per passenger (LKR)',
                hint: '1500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final price = double.tryParse(value ?? '');
                  return price == null || price < 0
                      ? 'Enter a valid price (zero is allowed)'
                      : null;
                },
              ),
            ],
          ),
          _section(
            title: 'Driver & Contact',
            icon: Icons.contact_phone_rounded,
            children: [
              _field(
                _hostPhone,
                'Your contact number',
                keyboardType: TextInputType.phone,
              ),
              _field(
                _whatsapp,
                'WhatsApp number (optional)',
                keyboardType: TextInputType.phone,
                required: false,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isHostDriver,
                title: const Text('I am the driver'),
                subtitle: const Text(
                  'Turn this off if another person will drive.',
                ),
                onChanged: (value) => setState(() => _isHostDriver = value),
              ),
              if (!_isHostDriver) ...[
                _field(_driverName, 'Driver name'),
                _field(
                  _driverPhone,
                  'Driver contact number',
                  keyboardType: TextInputType.phone,
                ),
              ],
              _field(_licenseNumber, 'Driver licence number'),
            ],
          ),
          _section(
            title: 'Optional Details',
            icon: Icons.tune_rounded,
            children: [
              _field(
                _vehicleType,
                'Vehicle type (optional)',
                hint: 'Car, van, SUV',
                required: false,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _hasAirConditioning,
                title: const Text('Air conditioning available'),
                onChanged: (value) {
                  setState(() => _hasAirConditioning = value);
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _luggageAvailable,
                title: const Text('Luggage space available'),
                onChanged: (value) {
                  setState(() => _luggageAvailable = value);
                },
              ),
              _field(
                _notes,
                'Additional notes (optional)',
                required: false,
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit for Approval',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRides() {
    return StreamBuilder<List<CommunityRide>>(
      stream: _service.watchMyRides(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Could not load rides: ${snapshot.error}'));
        }
        final rides = snapshot.data ?? const [];
        if (rides.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'You have not offered any rides yet.',
                style: TextStyle(color: DesignColors.textSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: rides.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _rideCard(rides[index]),
        );
      },
    );
  }

  Widget _rideCard(CommunityRide ride) {
    final color = switch (ride.approvalStatus) {
      'approved' => DesignColors.success,
      'rejected' => DesignColors.error,
      _ => Colors.orange.shade700,
    };
    final label = switch (ride.approvalStatus) {
      'approved' => 'APPROVED',
      'rejected' => 'REJECTED',
      _ => 'PENDING REVIEW',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ride.origin} → ${ride.destination}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ride.status == 'cancelled' ? 'CANCELLED' : label,
                  style: TextStyle(
                    color: ride.status == 'cancelled'
                        ? DesignColors.error
                        : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_formatDateTime(ride.departureAt)),
          const SizedBox(height: 5),
          Text(
            '${ride.offeredSeats} passenger seats · Rs. ${ride.pricePerPassenger.toStringAsFixed(2)} each',
            style: const TextStyle(color: DesignColors.textSecondary),
          ),
          if (ride.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Admin note: ${ride.reviewNote}',
              style: const TextStyle(color: DesignColors.error),
            ),
          ],
          if (ride.canCancel) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (ride.isApproved)
                  TextButton.icon(
                    onPressed: () async {
                      final tour = await _service.loadApprovedTour(ride.id);
                      if (!mounted || tour == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(tour: tour),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Ride Chat'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await _service.cancelRide(ride.id);
                    } catch (error) {
                      _showError('$error');
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Ride'),
                  style: TextButton.styleFrom(
                    foregroundColor: DesignColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DesignColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children.expand((child) => [child, const SizedBox(height: 12)]),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator ?? (required ? _required : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.calendar_month_rounded),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(_formatDateTime(value)),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: DesignColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
