import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
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

  // Pricing Constants
  static const double _kidsDiscount = 0.5;
  static const double _toddlerPrice = 0.0;

  double get _adultTotal => _adults * widget.tour.price;
  double get _kids6to12Total => _kids6to12 * widget.tour.price * _kidsDiscount;
  double get _toddlerTotal => _kidsUnder6 * _toddlerPrice;
  double get _totalPrice => _adultTotal + _kids6to12Total + _toddlerTotal;
  int get _totalPersons => _adults + _kids6to12 + _kidsUnder6;

  @override
  void dispose() {
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
    // If this is an idle tour (not an already scheduled/active instance),
    // prompt the user to pick a start date & time for the booked instance.
    if (widget.tour.status == TourStatus.idle) {
      final DateTime now = DateTime.now();
      final initialDate = widget.tour.startDate.isAfter(now)
          ? widget.tour.startDate
          : now;
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null) return; // cancelled

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.tour.startDate),
      );
      if (time == null) return; // cancelled

      chosenTourDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    setState(() => _isSubmitting = true);

    try {
      final fullPhoneNumber = '$_countryCode${_phoneController.text.trim()}';
      final success = await JoinedTourService().joinTour(
        tour: widget.tour,
        tourDate: chosenTourDate,
        adults: _adults,
        kids6to12: _kids6to12,
        kidsUnder6: _kidsUnder6,
        pickupLocation: _pickupController.text.trim(),
        totalPrice: _totalPrice,
        cardHolderName: _cardHolderController.text.trim(),
        phoneNumber: fullPhoneNumber,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Booking could not be completed. Please try again.',
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
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
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
              'Successfully reserved ${widget.tour.name} for $_totalPersons traveler(s).\n\nTotal Paid: \$${_totalPrice.toStringAsFixed(2)}',
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
          ),
        ),
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
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: DesignColors.divider),
                  ),
                  _buildCounter('Kids (6 - 12 yrs)', _kids6to12, 0, (v) {
                    setState(() => _kids6to12 = v);
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: DesignColors.divider),
                  ),
                  _buildCounter('Infants (Under 6 yrs)', _kidsUnder6, 0, (v) {
                    setState(() => _kidsUnder6 = v);
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
                  '\$${widget.tour.price.toInt()} per person',
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
          _buildPriceRow(
            'Adults (x$_adults)',
            '\$${_adultTotal.toStringAsFixed(2)}',
          ),
          if (_kids6to12 > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow(
              'Kids 6-12 (x$_kids6to12) [50% Off]',
              '\$${_kids6to12Total.toStringAsFixed(2)}',
              accented: true,
            ),
          ],
          if (_kidsUnder6 > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow('Kids under 6 (x$_kidsUnder6)', 'Free'),
          ],
          const Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: DesignColors.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: DesignColors.textPrimary,
                ),
              ),
              Text(
                '\$${_totalPrice.toStringAsFixed(2)}',
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
