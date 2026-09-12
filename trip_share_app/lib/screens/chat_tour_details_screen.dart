import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/theme/design_system.dart';

class ChatTourDetailsScreen extends StatefulWidget {
  final Tour tour;

  const ChatTourDetailsScreen({super.key, required this.tour});

  @override
  State<ChatTourDetailsScreen> createState() => _ChatTourDetailsScreenState();
}

class _ChatTourDetailsScreenState extends State<ChatTourDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  bool get _canViewPassengers =>
      _auth.isDriver ||
      (widget.tour.isCommunityRide && widget.tour.hostUserId == _auth.userId);

  late Future<_ChatTourDetails> _detailsFuture;
  late bool _lastKnownDriverRole;

  @override
  void initState() {
    super.initState();
    _lastKnownDriverRole = _auth.isDriver;
    _auth.addListener(_handleAuthChanged);
    _detailsFuture = _loadDetails();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted || _lastKnownDriverRole == _auth.isDriver) return;
    _lastKnownDriverRole = _auth.isDriver;
    setState(() => _detailsFuture = _loadDetails());
  }

  Future<_ChatTourDetails> _loadDetails() async {
    final instanceSnapshot = await _firestore
        .collection('tour_instances')
        .doc(widget.tour.id)
        .get();
    final instance = instanceSnapshot.data() ?? <String, dynamic>{};
    final templateId = _firstText([
      instance['sourceIdleTourId'],
      instance['templateTourId'],
      widget.tour.sourceIdleTourId,
      widget.tour.id,
    ]);

    Map<String, dynamic> template = const {};
    if (templateId.isNotEmpty) {
      final templateSnapshot = await _firestore
          .collection('tours')
          .doc(templateId)
          .get();
      template = templateSnapshot.data() ?? <String, dynamic>{};
    }

    final merged = <String, dynamic>{...template, ...instance};
    final passengers = _canViewPassengers
        ? await _loadAssignedPassengers()
        : const <_PassengerSummary>[];

    return _ChatTourDetails(data: merged, passengers: passengers);
  }

  Future<List<_PassengerSummary>> _loadAssignedPassengers() async {
    final snapshots = await Future.wait([
      _firestore
          .collection('bookings')
          .where('instanceId', isEqualTo: widget.tour.id)
          .get(),
      _firestore
          .collection('bookings')
          .where('tourId', isEqualTo: widget.tour.id)
          .get(),
    ]);
    final bookings = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snapshot in snapshots) {
      for (final booking in snapshot.docs) {
        bookings[booking.id] = booking;
      }
    }

    final userId = _auth.userId;
    final userEmail = _auth.userEmail.trim().toLowerCase();
    final result = <_PassengerSummary>[];
    for (final booking in bookings.values) {
      final data = booking.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') continue;

      final driverId = (data['driverId'] ?? '').toString();
      final driverEmail = (data['driverEmail'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final assignedToCurrentDriver =
          (userId.isNotEmpty && driverId == userId) ||
          (userEmail.isNotEmpty && driverEmail == userEmail);
      if (!assignedToCurrentDriver) continue;

      final passengerData = (data['passengers'] is List)
          ? (data['passengers'] as List).whereType<Map>().firstOrNull
          : null;
      result.add(
        _PassengerSummary(
          name: _firstText([
            passengerData?['name'],
            data['userName'],
            data['name'],
          ], fallback: 'Passenger'),
          email: _firstText([passengerData?['email'], data['userEmail']]),
          phone: _firstText([
            data['phoneNumber'],
            passengerData?['phone'],
            data['phone'],
          ]),
          pickupLocation: _firstText([data['pickupLocation']]),
          people: _toInt(data['totalPersons'] ?? data['numberOfPeople']),
        ),
      );
    }
    return result;
  }

  static String _firstText(List<dynamic> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DesignColors.textPrimary,
        title: Text(_canViewPassengers ? 'Tour & passengers' : 'Tour summary'),
      ),
      body: FutureBuilder<_ChatTourDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: DesignColors.primary),
            );
          }
          if (snapshot.hasError) {
            return _errorState(snapshot.error);
          }

          final details = snapshot.data!;
          return RefreshIndicator(
            color: DesignColors.primary,
            onRefresh: () async {
              final next = _loadDetails();
              setState(() => _detailsFuture = next);
              await next;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _tourSummary(details.data),
                if (_description(details.data).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _textSection('About this tour', _description(details.data)),
                ],
                if (_route(details.data).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _routeSection(_route(details.data)),
                ],
                if (_canViewPassengers) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Tour passengers (${details.passengers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: DesignColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (details.passengers.isEmpty)
                    _emptyPassengers()
                  else
                    ...details.passengers.asMap().entries.map(
                      (entry) => _passengerCard(entry.key + 1, entry.value),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tourSummary(Map<String, dynamic> data) {
    final totalSeats = _toInt(data['totalSeats'] ?? widget.tour.totalSeats);
    final remainingSeats = _toInt(
      data['available_seats'] ??
          data['remainingSeats'] ??
          widget.tour.remainingSeats,
    );
    final bookedSeats = _toInt(
      data['bookedSeats'] ?? (totalSeats - remainingSeats),
    );
    final startDate = _dateTime(data['startDate']) ?? widget.tour.startDate;
    final isPrivate =
        data['isPrivate'] == true ||
        (data['visibility'] ?? '').toString().toLowerCase() == 'private';
    final name = _firstText([data['name'], data['title'], widget.tour.name]);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: DesignColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isPrivate
                      ? Colors.deepPurple.withValues(alpha: 0.1)
                      : DesignColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPrivate ? 'Private' : 'Public',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isPrivate ? Colors.deepPurple : DesignColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(
            Icons.calendar_month_rounded,
            'Start',
            _formatDate(startDate),
          ),
          _optionalDetail(
            data,
            const ['startLocation', 'start_location', 'location'],
            Icons.trip_origin_rounded,
            'From',
          ),
          _optionalDetail(
            data,
            const ['endLocation', 'end_location'],
            Icons.location_on_rounded,
            'To',
          ),
          _optionalDetail(
            data,
            const ['operatorName', 'operator_name'],
            Icons.business_rounded,
            'Operator',
          ),
          _detailRow(
            Icons.groups_rounded,
            'Passengers',
            '$bookedSeats booked · $remainingSeats available · $totalSeats total',
          ),
          _detailRow(
            Icons.payments_outlined,
            'Price',
            'Rs. ${_price(data).toStringAsFixed(2)} per person',
          ),
        ],
      ),
    );
  }

  Widget _optionalDetail(
    Map<String, dynamic> data,
    List<String> keys,
    IconData icon,
    String label,
  ) {
    final value = _value(data, keys).toString().trim();
    return value.isEmpty
        ? const SizedBox.shrink()
        : _detailRow(icon, label, value);
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: DesignColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
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

  Widget _textSection(String title, String text) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: DesignColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            color: DesignColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _routeSection(List<Map<String, String>> route) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: DesignColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (final stop in route)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: DesignColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    stop['location'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if ((stop['time'] ?? '').isNotEmpty)
                  Text(
                    stop['time']!,
                    style: const TextStyle(color: DesignColors.textSecondary),
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _passengerCard(int index, _PassengerSummary passenger) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: DesignColors.primary.withValues(alpha: 0.12),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  passenger.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${passenger.people} ${passenger.people == 1 ? 'person' : 'people'}',
                style: const TextStyle(
                  color: DesignColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _passengerLine(Icons.phone_outlined, passenger.phone),
          _passengerLine(Icons.email_outlined, passenger.email),
          _passengerLine(Icons.location_on_outlined, passenger.pickupLocation),
        ],
      ),
    ),
  );

  Widget _passengerLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: DesignColors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emptyPassengers() => _card(
    child: const Center(
      child: Text(
        'No passenger details are available for this tour.',
        style: TextStyle(color: DesignColors.textSecondary),
      ),
    ),
  );

  Widget _errorState(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44, color: DesignColors.error),
          const SizedBox(height: 12),
          const Text('Could not load tour information.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _detailsFuture = _loadDetails()),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: DesignColors.divider),
    ),
    child: child,
  );

  dynamic _value(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return '';
  }

  String _description(Map<String, dynamic> data) =>
      _value(data, const ['description', 'details']).toString();

  double _price(Map<String, dynamic> data) {
    final value = data['price'] ?? widget.tour.price;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? widget.tour.price;
  }

  List<Map<String, String>> _route(Map<String, dynamic> data) {
    final raw = data['route'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((stop) {
          return {
            'location': _firstText([
              stop['location'],
              stop['place'],
              stop['name'],
            ]),
            'time': _firstText([stop['time'], stop['at']]),
          };
        })
        .where((stop) => (stop['location'] ?? '').isNotEmpty)
        .toList();
  }

  DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _formatDate(DateTime date) {
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

class _ChatTourDetails {
  final Map<String, dynamic> data;
  final List<_PassengerSummary> passengers;

  const _ChatTourDetails({required this.data, required this.passengers});
}

class _PassengerSummary {
  final String name;
  final String email;
  final String phone;
  final String pickupLocation;
  final int people;

  const _PassengerSummary({
    required this.name,
    required this.email,
    required this.phone,
    required this.pickupLocation,
    required this.people,
  });
}
