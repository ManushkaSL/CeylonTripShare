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
  int _formStep = 0;
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
    _formStep = 0;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DesignColors.error),
    );
  }

  void _continueForm() {
    if (!_formKey.currentState!.validate()) return;
    if (_formStep == 1 && !_estimatedArrivalAt.isAfter(_departureAt)) {
      _showError('Estimated arrival must be after departure.');
      return;
    }
    if (_formStep < 3) setState(() => _formStep++);
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
        _buildRideHeader(),
        _buildViewSwitcher(),
        Expanded(child: _viewIndex == 0 ? _buildForm() : _buildMyRides()),
      ],
    );
  }

  Widget _buildRideHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignColors.primary, DesignColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: DesignColors.primaryLight,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share your journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Offer spare seats and travel together.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcher() {
    Widget item(int value, IconData icon, String label) {
      final selected = _viewIndex == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _viewIndex = value),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 45,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: DesignColors.primaryDark.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? DesignColors.primary
                      : DesignColors.textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? DesignColors.textPrimary
                        : DesignColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesignColors.secondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          item(0, Icons.add_road_rounded, 'Create Ride'),
          item(1, Icons.list_alt_rounded, 'My Rides'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildStepProgress(),
          const SizedBox(height: 16),
          if (_formStep == 0)
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
          if (_formStep == 1)
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
          if (_formStep == 2)
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
          if (_formStep == 3)
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
          if (_formStep == 3) ...[
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
            _buildRidePreview(),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              if (_formStep > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _formStep--),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignColors.primary,
                        side: const BorderSide(color: DesignColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: _formStep == 0 ? 1 : 2,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DesignColors.primary, DesignColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: DesignColors.primary.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _submitting
                        ? null
                        : _formStep == 3
                        ? _submit
                        : _continueForm,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _formStep == 3
                                ? Icons.send_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      _submitting
                          ? 'Submitting...'
                          : _formStep == 3
                          ? 'Submit for Approval'
                          : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    const labels = ['Route', 'Time', 'Seats', 'Contact'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= _formStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 5,
                      decoration: BoxDecoration(
                        color: active
                            ? DesignColors.primary
                            : DesignColors.divider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: index == _formStep
                            ? DesignColors.primary
                            : DesignColors.textTertiary,
                        fontSize: 10,
                        fontWeight: index == _formStep
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1) const SizedBox(width: 7),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRidePreview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5EADF), Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DesignColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RIDE PREVIEW',
            style: TextStyle(
              color: DesignColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _origin.text.isEmpty ? 'From' : _origin.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: DesignColors.primary,
                ),
              ),
              Expanded(
                child: Text(
                  _destination.text.isEmpty ? 'Destination' : _destination.text,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatDateTime(_departureAt)}  •  ${_seats.text} seats  •  Rs. ${_price.text.isEmpty ? '0' : _price.text} each',
            style: const TextStyle(
              color: DesignColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignColors.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
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
                  color: color.withValues(alpha: 0.1),
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: DesignColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: DesignColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(ride.departureAt),
                    style: const TextStyle(
                      color: DesignColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _rideFact(Icons.event_seat_rounded, '${ride.offeredSeats} seats'),
              _rideFact(
                Icons.payments_outlined,
                'Rs. ${ride.pricePerPassenger.toStringAsFixed(0)} each',
              ),
            ],
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

  Widget _rideFact(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.secondary.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DesignColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: DesignColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignColors.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DesignColors.secondary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: DesignColors.primary, size: 20),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
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
        filled: true,
        fillColor: DesignColors.background.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: DesignColors.divider.withValues(alpha: 0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: DesignColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: DesignColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: DesignColors.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: DesignColors.background.withValues(alpha: 0.7),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DesignColors.secondary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.calendar_month_rounded,
          color: DesignColors.primary,
          size: 20,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(_formatDateTime(value)),
      trailing: const Icon(Icons.edit_calendar_rounded),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: DesignColors.divider),
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}
