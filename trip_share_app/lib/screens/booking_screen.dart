import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/services/pricing_service.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';
import 'package:trip_share_app/theme/design_system.dart';

class BookingScreen extends StatefulWidget {
  final Tour tour;

  const BookingScreen({super.key, required this.tour});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _adults = 1;
  int _kids6to12 = 0;
  int _kidsUnder6 = 0;
  final _pickupController = TextEditingController();
  final _phoneController = TextEditingController();
  String _countryCode = '+94'; // Default to Sri Lanka for tours
  bool _agreeToPolicy = false;

  // Card fields
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  DateTime? _selectedTourDate;
  bool _isPrivateTour = false;
  final PricingService _pricingService = PricingService();
  PricingQuote? _pricingQuote;
  Timer? _pricingDebounce;
  int _pricingRequestId = 0;
  bool _isLoadingPricing = true;
  String? _pricingError;

  // Local estimates are displayed only while the authoritative API quote loads.
  static const double _kidsDiscount = 0.5;
  static const double _toddlerPrice = 0.0;

  double get _adultTotal =>
      _pricingQuote?.adultTotal ?? _adults * _estimatedPassengerPrice;
  double get _kids6to12Total =>
      _pricingQuote?.childTotal ??
      _kids6to12 *
          _estimatedPassengerPrice *
          (_isFixedPricing || _isPerSeatPricing ? 1 : _kidsDiscount);
  double get _toddlerTotal =>
      _pricingQuote?.infantTotal ??
      _kidsUnder6 *
          (_isFixedPricing || _isPerSeatPricing
              ? _estimatedPassengerPrice
              : _toddlerPrice);
  double get _totalPrice =>
      _pricingQuote?.total ?? _adultTotal + _kids6to12Total + _toddlerTotal;
  int get _totalPersons => _adults + _kids6to12 + _kidsUnder6;
  String get _currency => _pricingQuote?.currency ?? 'LKR';
  bool get _isFixedPricing =>
      widget.tour.isFixedTourPricing ||
      _pricingQuote?.pricingMode == Tour.fixedTourPricing;
  bool get _isPerSeatPricing =>
      widget.tour.isCommunityRide ||
      _pricingQuote?.pricingMode == Tour.perSeatPricing;
  int get _estimatedPassengersAfterBooking =>
      _pricingQuote?.passengersAfterBooking ??
      (widget.tour.bookedSeats + _totalPersons)
          .clamp(1, widget.tour.totalSeats)
          .toInt();
  double get _fullTourPrice =>
      _pricingQuote?.fullTourPrice ?? widget.tour.fixedTourPrice;
  double get _fullTourTotal =>
      _pricingQuote?.fullTourTotal ?? widget.tour.fixedTourPrice;
  double get _estimatedPassengerPrice {
    if (!_isFixedPricing) return widget.tour.price;
    return _pricingQuote?.pricePerPassenger ??
        _fullTourPrice / _estimatedPassengersAfterBooking;
  }

  @override
  void initState() {
    super.initState();
    _isPrivateTour = widget.tour.isPrivate || widget.tour.isFixedTourPricing;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPricing());
  }

  String _formatMoney(double value) {
    final amount = value.toStringAsFixed(2);
    return _currency == 'LKR' ? 'Rs. $amount' : '$_currency $amount';
  }

  void _schedulePricingRefresh() {
    _pricingDebounce?.cancel();
    final requestId = ++_pricingRequestId;
    setState(() {
      _pricingQuote = null;
      _pricingError = null;
      _isLoadingPricing = true;
    });
    _pricingDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _refreshPricing(requestId: requestId),
    );
  }

  Future<PricingQuote?> _refreshPricing({int? requestId}) async {
    final currentRequestId = requestId ?? ++_pricingRequestId;
    if (mounted && requestId == null) {
      setState(() {
        _pricingError = null;
        _isLoadingPricing = true;
      });
    }

    try {
      final quote = await _pricingService.calculateTourPrice(
        tourId: widget.tour.id,
        adults: _adults,
        kids6to12: _kids6to12,
        kidsUnder6: _kidsUnder6,
        isPrivate: _isPrivateTour,
      );
      if (!mounted || currentRequestId != _pricingRequestId) return null;
      setState(() {
        _pricingQuote = quote;
        _pricingError = null;
        _isLoadingPricing = false;
      });
      return quote;
    } catch (error) {
      if (!mounted || currentRequestId != _pricingRequestId) return null;
      setState(() {
        _pricingError = error.toString();
        _isLoadingPricing = false;
      });
      return null;
    }
  }

  DateTime get _firstSelectableDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _initialSelectableDate {
    final adminDate = DateTime(
      widget.tour.startDate.year,
      widget.tour.startDate.month,
      widget.tour.startDate.day,
    );
    return adminDate.isBefore(_firstSelectableDate)
        ? _firstSelectableDate
        : adminDate;
  }

  DateTime get _lastSelectableDate {
    final oneYearFromToday = _firstSelectableDate.add(
      const Duration(days: 365),
    );
    return _initialSelectableDate.isAfter(oneYearFromToday)
        ? _initialSelectableDate.add(const Duration(days: 365))
        : oneYearFromToday;
  }

  Future<void> _selectTourDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTourDate ?? _initialSelectableDate,
      firstDate: _firstSelectableDate,
      lastDate: _lastSelectableDate,
    );
    if (date != null && mounted) {
      setState(() => _selectedTourDate = date);
    }
  }

  @override
  void dispose() {
    _pricingDebounce?.cancel();
    _pickupController.dispose();
    _phoneController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting) return;

    if (!widget.tour.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This tour is fully booked'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the tour policy guidelines'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_totalPersons > widget.tour.remainingSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${widget.tour.remainingSeats} seats available'),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    DateTime? chosenTourDate;
    if (widget.tour.status == TourStatus.idle) {
      final date = _selectedTourDate;
      if (date == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select your preferred tour date'),
            backgroundColor: DesignColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // The customer selects only the date. Tour time is fixed by admin.
      chosenTourDate = DateTime(
        date.year,
        date.month,
        date.day,
        widget.tour.startDate.hour,
        widget.tour.startDate.minute,
        widget.tour.startDate.second,
      );
    }

    setState(() => _isSubmitting = true);

    try {
      // Require authentication for booking. If not logged in, show login dialog.
      if (AuthService().userId.isEmpty) {
        final loggedIn = await LoginDialog.show(context);
        if (!loggedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please sign in to complete booking'),
                backgroundColor: DesignColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      if (widget.tour.isCommunityRide &&
          widget.tour.hostUserId == AuthService().userId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You are hosting this ride, so you cannot book its passenger seats.',
              ),
              backgroundColor: DesignColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      _pricingDebounce?.cancel();
      final authoritativeQuote = await _refreshPricing();
      if (authoritativeQuote == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _pricingError ??
                    'Could not verify the booking price. Please try again.',
              ),
              backgroundColor: DesignColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final fullPhoneNumber = '$_countryCode${_phoneController.text.trim()}';
      final success = await JoinedTourService().joinTour(
        tour: widget.tour,
        tourDate: chosenTourDate,
        isPrivate: _isPrivateTour,
        adults: _adults,
        kids6to12: _kids6to12,
        kidsUnder6: _kidsUnder6,
        pickupLocation: _pickupController.text.trim(),
        totalPrice: authoritativeQuote.total,
        currency: authoritativeQuote.currency,
        pricingVersion: authoritativeQuote.pricingVersion,
        pricingBreakdown: authoritativeQuote.toBookingPricingMap(),
        cardHolderName: _cardHolderController.text.trim(),
        phoneNumber: fullPhoneNumber,
      );

      if (!mounted) return;

      if (!success) {
        final reason = JoinedTourService().lastError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reason == null || reason.isEmpty
                  ? 'Booking could not be completed. Please try again.'
                  : 'Booking failed: $reason',
            ),
            backgroundColor: DesignColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Gorgeous success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          final dialog = AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: DesignColors.success,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Text(
              'Successfully reserved ${widget.tour.name} for $_totalPersons traveler(s).\n\nTotal: ${_formatMoney(authoritativeQuote.total)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignColors.textSecondary,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Container(
                width: 140,
                height: 44,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DesignColors.primary, DesignColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss dialog
                    Navigator.of(context).pop(); // Exit booking
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Great',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          );

          if (kIsWeb) {
            // Some web renderers can throw engine assertions when using
            // ImageFilter/BackdropFilter. Use a simple dialog without blur on web.
            return dialog;
          }

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: dialog,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: DesignColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Book Your Safari',
          style: TextStyle(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // Tour info header
            _buildTourHeader(),
            const SizedBox(height: 24),

            if (widget.tour.status == TourStatus.idle) ...[
              _buildSectionTitle('SELECT TOUR DATE'),
              const SizedBox(height: 10),
              _buildTourDateSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('TOUR VISIBILITY'),
              const SizedBox(height: 10),
              _buildTourVisibilitySection(),
              const SizedBox(height: 24),
            ],

            // Group details counter card
            _buildSectionTitle('TRAVELERS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: DesignColors.divider.withOpacity(0.8),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  _buildCounter('Adults (Above 12 yrs)', _adults, 1, (v) {
                    setState(() => _adults = v);
                    _schedulePricingRefresh();
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: DesignColors.divider),
                  ),
                  _buildCounter('Kids (6 - 12 yrs)', _kids6to12, 0, (v) {
                    setState(() => _kids6to12 = v);
                    _schedulePricingRefresh();
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: DesignColors.divider),
                  ),
                  _buildCounter('Infants (Under 6 yrs)', _kidsUnder6, 0, (v) {
                    setState(() => _kidsUnder6 = v);
                    _schedulePricingRefresh();
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact Info
            _buildSectionTitle('CONTACT DETAILS'),
            const SizedBox(height: 10),
            Row(
              children: [
                // Country Code
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _countryCode,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Code',
                      labelStyle: const TextStyle(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.divider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (v) => setState(() => _countryCode = v),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                // Phone Number
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: const TextStyle(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.phone_iphone_rounded,
                        color: DesignColors.primary,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.divider,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.divider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DesignColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Please enter your phone';
                      if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 6)
                        return 'Invalid phone number';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pickup location
            _buildSectionTitle('PICKUP LOCATION'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _pickupController,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Hotel Name / Address',
                labelStyle: const TextStyle(
                  color: DesignColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.hotel_rounded,
                  color: DesignColors.primary,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: DesignColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: DesignColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: DesignColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please enter hotel pickup location';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Real-time pricing details card (luxury receipt design)
            _buildSectionTitle('PRICING SUMMARY'),
            const SizedBox(height: 10),
            _buildPricingCard(),
            const SizedBox(height: 24),

            // Card details
            _buildSectionTitle('PAYMENT DETAIL'),
            const SizedBox(height: 10),
            _buildCardDetailsSection(),
            const SizedBox(height: 20),

            // Policy agreement
            _buildPolicyCheckbox(),
            const SizedBox(height: 28),

            // Confirm Submit Button (luxury gradient)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DesignColors.primary, DesignColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.tour.status == TourStatus.idle
                              ? 'Start Tour Adventure'
                              : 'Confirm Booking Reservation',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourVisibilitySection() {
    if (widget.tour.isCommunityRide) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DesignColors.primary.withOpacity(0.2)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.public_rounded, color: DesignColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Public Community Ride\nPassenger seats can be joined immediately while they remain available.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_isFixedPricing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DesignColors.primary.withOpacity(0.2)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, color: DesignColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Private fixed-price tour\nThe full tour price is shared equally by all passengers who join through the private link.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.divider, width: 1.2),
      ),
      child: Column(
        children: [
          _buildVisibilityOption(
            isPrivate: false,
            icon: Icons.public_rounded,
            title: 'Public tour',
            subtitle: 'Shown in Active Tours so anyone can discover and join.',
          ),
          const Divider(height: 1, color: DesignColors.divider),
          _buildVisibilityOption(
            isPrivate: true,
            icon: Icons.lock_outline_rounded,
            title: 'Private tour',
            subtitle:
                'Hidden from Active Tours. People can join using your link.',
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption({
    required bool isPrivate,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _isPrivateTour == isPrivate;

    return InkWell(
      onTap: () {
        if (_isPrivateTour == isPrivate) return;
        setState(() => _isPrivateTour = isPrivate);
        _schedulePricingRefresh();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? DesignColors.primary
                  : DesignColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: DesignColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? DesignColors.primary
                  : DesignColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DesignColors.divider.withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              widget.tour.imageUrl,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 76,
                height: 76,
                color: DesignColors.divider,
                child: const Icon(
                  Icons.landscape_rounded,
                  color: DesignColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tour.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DesignColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatMoney(widget.tour.price)} per person',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: DesignColors.success,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.tour.remainingSeats} of ${widget.tour.totalSeats} seats left',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: DesignColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTourDateSection() {
    final fixedTime = TimeOfDay.fromDateTime(widget.tour.startDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedTourDate == null
              ? DesignColors.divider.withOpacity(0.8)
              : DesignColors.primary.withOpacity(0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _selectTourDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: DesignColors.primary,
                    size: 21,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedTourDate == null
                          ? 'Tap to select tour date'
                          : _formatSelectedDate(_selectedTourDate!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _selectedTourDate == null
                            ? DesignColors.textSecondary
                            : DesignColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: DesignColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: DesignColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Tour start time',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  fixedTime.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedTourDate == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Choose the date you want. The tour time is fixed by the administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: DesignColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildCounter(
    String label,
    int value,
    int min,
    ValueChanged<int> onChanged,
  ) {
    final max = widget.tour.remainingSeats;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DesignColors.textPrimary,
            ),
          ),
        ),
        // Minus Button
        GestureDetector(
          onTap: value > min ? () => onChanged(value - 1) : null,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value > min
                  ? DesignColors.secondary.withOpacity(0.4)
                  : DesignColors.divider.withOpacity(0.5),
              border: Border.all(
                color: value > min
                    ? DesignColors.primary.withOpacity(0.3)
                    : DesignColors.divider,
              ),
            ),
            child: Icon(
              Icons.remove,
              size: 16,
              color: value > min
                  ? DesignColors.primaryDark
                  : DesignColors.textTertiary,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: DesignColors.textPrimary,
            ),
          ),
        ),
        // Plus Button
        GestureDetector(
          onTap: _totalPersons < max ? () => onChanged(value + 1) : null,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _totalPersons < max
                  ? DesignColors.secondary.withOpacity(0.4)
                  : DesignColors.divider.withOpacity(0.5),
              border: Border.all(
                color: _totalPersons < max
                    ? DesignColors.primary.withOpacity(0.3)
                    : DesignColors.divider,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: _totalPersons < max
                  ? DesignColors.primaryDark
                  : DesignColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: DesignColors.divider.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          if (_isLoadingPricing) ...[
            const LinearProgressIndicator(
              minHeight: 3,
              color: DesignColors.primary,
              backgroundColor: DesignColors.divider,
            ),
            const SizedBox(height: 14),
          ],
          if (_pricingError != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 18,
                  color: DesignColors.error,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Estimated price shown. Connect to verify before booking.',
                    style: TextStyle(
                      color: DesignColors.error,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isLoadingPricing ? null : _refreshPricing,
                  child: const Text('Retry'),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_isFixedPricing) ...[
            _buildPriceRow(
              'Full tour base price',
              _formatMoney(_fullTourPrice),
            ),
            if ((_pricingQuote?.fullTourTotal ?? 0) > _fullTourPrice) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Full tour total (fees included)',
                _formatMoney(_fullTourTotal),
              ),
            ],
            const SizedBox(height: 10),
            _buildPriceRow(
              'Passengers after booking',
              '$_estimatedPassengersAfterBooking',
            ),
            const SizedBox(height: 10),
            _buildPriceRow(
              'Current price per passenger',
              _formatMoney(_estimatedPassengerPrice),
              accented: true,
            ),
            const SizedBox(height: 10),
            _buildPriceRow(
              'Your passengers (x$_totalPersons)',
              _formatMoney(_totalPrice),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your share decreases when more passengers join. All existing booking totals are recalculated automatically.',
              style: TextStyle(
                color: DesignColors.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ] else if (_isPerSeatPricing) ...[
            _buildPriceRow(
              'Price per passenger',
              _formatMoney(
                _pricingQuote?.pricePerPassenger ?? widget.tour.price,
              ),
              accented: true,
            ),
            const SizedBox(height: 10),
            _buildPriceRow(
              'Passengers (x$_totalPersons)',
              _formatMoney(_pricingQuote?.subtotal ?? _totalPrice),
            ),
            if ((_pricingQuote?.serviceFee ?? 0) > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Service fee (${_pricingQuote!.serviceFeePercent.toStringAsFixed(1)}%)',
                _formatMoney(_pricingQuote!.serviceFee),
              ),
            ],
          ] else ...[
            _buildPriceRow('Adults (x$_adults)', _formatMoney(_adultTotal)),
            if (_kids6to12 > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Kids 6-12 (x$_kids6to12) [50% Off]',
                _formatMoney(_kids6to12Total),
                accented: true,
              ),
            ],
            if (_kidsUnder6 > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Kids under 6 (x$_kidsUnder6)',
                _toddlerTotal == 0 ? 'Free' : _formatMoney(_toddlerTotal),
              ),
            ],
            if ((_pricingQuote?.privateTourSurcharge ?? 0) > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Private tour surcharge',
                _formatMoney(_pricingQuote!.privateTourSurcharge),
              ),
            ],
            if ((_pricingQuote?.serviceFee ?? 0) > 0) ...[
              const SizedBox(height: 10),
              _buildPriceRow(
                'Service fee (${_pricingQuote!.serviceFeePercent.toStringAsFixed(1)}%)',
                _formatMoney(_pricingQuote!.serviceFee),
              ),
            ],
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: DesignColors.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isFixedPricing ? 'Your Current Share' : 'Total Amount',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: DesignColors.textPrimary,
                ),
              ),
              Text(
                _formatMoney(_totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: DesignColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String price, {bool accented = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: accented
                ? DesignColors.accentSecondary
                : DesignColors.textSecondary,
            fontWeight: accented ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: accented
                ? DesignColors.accentSecondary
                : DesignColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreeToPolicy,
            onChanged: (v) => setState(() => _agreeToPolicy = v ?? false),
            activeColor: DesignColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(
              color: DesignColors.textTertiary,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'I verify all traveler details and accept the ',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DesignColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: 'Tour Policies & Reservation Guidelines',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: DesignColors.primary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: DesignColors.divider.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Card Holder
          TextFormField(
            controller: _cardHolderController,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: DesignColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Cardholder Name',
              labelStyle: const TextStyle(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: DesignColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFFBF8F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DesignColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DesignColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: DesignColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter card holder name'
                : null,
          ),
          const SizedBox(height: 12),
          // Card Number
          TextFormField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            maxLength: 19,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: DesignColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Card Number',
              labelStyle: const TextStyle(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.credit_card_rounded,
                color: DesignColors.primary,
                size: 20,
              ),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFFBF8F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DesignColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: DesignColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: DesignColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            validator: (v) => (v == null || v.trim().length < 15)
                ? 'Please enter a valid card number'
                : null,
          ),
          const SizedBox(height: 12),
          // Expiry & CVV
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  keyboardType: TextInputType.datetime,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Expiry MM/YY',
                    labelStyle: const TextStyle(
                      color: DesignColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.date_range_rounded,
                      color: DesignColors.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFBF8F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: DesignColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'CVV Code',
                    labelStyle: const TextStyle(
                      color: DesignColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.security_rounded,
                      color: DesignColors.primary,
                      size: 20,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFFBF8F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: DesignColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: DesignColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
