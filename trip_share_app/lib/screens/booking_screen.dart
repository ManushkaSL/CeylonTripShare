import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';

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
  bool _agreeToPolicy = false;

  // Card fields
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Pricing
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
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    if (!widget.tour.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This tour is fully booked'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the policy guidelines'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_totalPersons > widget.tour.remainingSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${widget.tour.remainingSeats} seats available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('📝 BOOKING: adults=$_adults, kids6to12=$_kids6to12, kidsUnder6=$_kidsUnder6, totalPersons=$_totalPersons');
    debugPrint('   Tour ${widget.tour.name}: remainingSeats=${widget.tour.remainingSeats}, totalSeats=${widget.tour.totalSeats}');

    // Save to Firestore with booking details
    await JoinedTourService().joinTour(
      tour: widget.tour,
      adults: _adults,
      kids6to12: _kids6to12,
      kidsUnder6: _kidsUnder6,
      pickupLocation: _pickupController.text,
      totalPrice: _totalPrice,
      cardHolderName: _cardHolderController.text,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 28),
            SizedBox(width: 8),
            Text('Booking Confirmed'),
          ],
        ),
        content: Text(
          'You have booked ${widget.tour.name} for $_totalPersons person(s).\n\nTotal: \$${_totalPrice.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Done',
              style: TextStyle(color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Book Tour',
          style: TextStyle(
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Tour info header
            _buildTourHeader(),
            const SizedBox(height: 20),

            // Group details
            _buildSectionTitle('Group Details'),
            const SizedBox(height: 10),
            _buildCounter('Adults (above 12 yrs)', _adults, 1, (v) {
              setState(() => _adults = v);
            }),
            const SizedBox(height: 8),
            _buildCounter('Kids (6 - 12 yrs)', _kids6to12, 0, (v) {
              setState(() => _kids6to12 = v);
            }),
            const SizedBox(height: 8),
            _buildCounter('Kids (under 6 yrs)', _kidsUnder6, 0, (v) {
              setState(() => _kidsUnder6 = v);
            }),
            const SizedBox(height: 20),

            // Pickup location
            _buildSectionTitle('Pickup Location'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _pickupController,
              decoration: InputDecoration(
                hintText: 'Enter hotel name or pickup location',
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF1B5E20),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter pickup location';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Real-time pricing
            _buildSectionTitle('Pricing Summary'),
            const SizedBox(height: 10),
            _buildPricingCard(),
            const SizedBox(height: 20),

            // Policy agreement
            _buildPolicyCheckbox(),
            const SizedBox(height: 20),

            // Card details
            _buildSectionTitle('Payment Details'),
            const SizedBox(height: 10),
            _buildCardDetailsSection(),
            const SizedBox(height: 24),

            // Join button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _confirmBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  widget.tour.status == TourStatus.idle
                      ? 'Start Tour'
                      : 'Join Tour',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTourHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.tour.imageUrl,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 70,
                    height: 70,
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.landscape,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tour.name,
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
                      '\$${widget.tour.price.toInt()} per person',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.tour.remainingSeats} of ${widget.tour.totalSeats} seats available',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
            ),
          ),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: const Color(0xFF1B5E20),
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: _totalPersons < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF1B5E20),
            iconSize: 26,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _buildPriceRow(
            'Adults x$_adults',
            '\$${_adultTotal.toStringAsFixed(2)}',
          ),
          if (_kids6to12 > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              'Kids (6-12) x$_kids6to12 (50% off)',
              '\$${_kids6to12Total.toStringAsFixed(2)}',
            ),
          ],
          if (_kidsUnder6 > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow('Kids (under 6) x$_kidsUnder6', 'Free'),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              Text(
                '\$${_totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(
          price,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPolicyCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreeToPolicy,
            onChanged: (v) => setState(() => _agreeToPolicy = v ?? false),
            activeColor: const Color(0xFF1B5E20),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text.rich(
                TextSpan(
                  text: 'I confirm the details above and agree to the ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF555555),
                  ),
                  children: [
                    TextSpan(
                      text: 'Tour Policy & Guidelines',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(
                          0xFF1B5E20,
                        ).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _cardHolderController,
            decoration: InputDecoration(
              labelText: 'Card Holder Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            maxLength: 19,
            decoration: InputDecoration(
              labelText: 'Card Number',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'MM/YY',
                    prefixIcon: const Icon(Icons.date_range),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    prefixIcon: const Icon(Icons.security),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
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
}
