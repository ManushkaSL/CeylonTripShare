import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/booking_details_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';
import 'package:trip_share_app/screens/booking_screen.dart';
import 'package:trip_share_app/theme/design_system.dart';

class TourDetailScreen extends StatefulWidget {
  final Tour tour;

  const TourDetailScreen({super.key, required this.tour});

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  int _currentPhoto = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    JoinedTourService().addListener(_onBookingsChanged);
    JoinedTourService().loadBookings();
  }

  @override
  void dispose() {
    JoinedTourService().removeListener(_onBookingsChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onBookingsChanged() {
    if (mounted) setState(() {});
  }

  List<String> get _allPhotos {
    if (widget.tour.photos.isEmpty) return [widget.tour.imageUrl];
    return widget.tour.photos;
  }

  void _onJoinPressed() async {
    final tour = widget.tour;
    if (!AuthService().isLoggedIn) {
      final loggedIn = await LoginDialog.show(context);
      if (!loggedIn) return;
      await JoinedTourService().loadBookings();
    }
    if (!mounted) return;

    if (JoinedTourService().isJoinedTour(tour)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookingDetailsScreen(tour: tour)),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BookingScreen(tour: tour)));
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final status = tour.status;
    final photos = _allPhotos;
    final isUserBooked = JoinedTourService().isJoinedTour(tour);

    return Scaffold(
      backgroundColor: DesignColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Photo gallery header
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            stretch: true,
            backgroundColor: DesignColors.background,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo page view
                  PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                    itemBuilder: (context, index) {
                      return Image.network(
                        photos[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: DesignColors.divider,
                          child: const Center(
                            child: Icon(
                              Icons.landscape_rounded,
                              size: 64,
                              color: DesignColors.textTertiary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Gradient overlay at bottom of photo slider for elegant overlay blending
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            DesignColors.background,
                            DesignColors.background.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Luxurious Photo indicators
                  if (photos.length > 1)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          final isActive = _currentPhoto == i;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            width: isActive ? 22 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? DesignColors.primary
                                  : DesignColors.surface.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Main body content (Luxury Alabaster White background panel)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2C2219).withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge & Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (tour.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: DesignColors.secondary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: DesignColors.primary.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            tour.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: DesignColors.primaryDark,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tour Name Title
                  Text(
                    tour.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: DesignColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Operator Description Label
                  if (tour.operatorName.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: DesignColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Operated by ${tour.operatorName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DesignColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(color: DesignColors.divider),
                  ),

                  // Elegant Grid Details Chips
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.attach_money_rounded,
                        '\$${tour.price.toInt()} / person',
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        Icons.people_outline_rounded,
                        '${tour.remainingSeats}/${tour.totalSeats} seats left',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (status != TourStatus.idle) ...[
                        _buildInfoChip(
                          Icons.calendar_month_rounded,
                          _formatDate(tour.startDate),
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildInfoChip(
                        Icons.access_time_rounded,
                        _formatTime(tour.startDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Schedule Card Details
                  _buildSectionTitle('SCHEDULE DETAIL'),
                  const SizedBox(height: 10),
                  _buildDetailCard([
                    _buildDetailRow(
                      Icons.play_arrow_rounded,
                      'Start Departure',
                      '${_formatTime(tour.startDate)} from ${tour.startLocation}',
                    ),
                    if (tour.lastJoiningTime != null)
                      _buildDetailRow(
                        Icons.hourglass_bottom_rounded,
                        'Last Booking',
                        '${_formatTime(tour.lastJoiningTime!)} on ${_formatDate(tour.lastJoiningTime!)}',
                      ),
                    if (tour.endTime.isNotEmpty)
                      _buildDetailRow(
                        Icons.flag_rounded,
                        'Arrival Destination',
                        '${tour.endTime} at ${tour.endLocation}',
                      ),
                  ]),
                  const SizedBox(height: 24),

                  // Tour Description About
                  _buildSectionTitle('ABOUT THE ADVENTURE'),
                  const SizedBox(height: 10),
                  Text(
                    tour.description.isNotEmpty
                        ? tour.description
                        : 'Experience a signature wildlife tour curated by our team, introducing high-end premium hospitality and sightseeing.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Timeline Stopover Map
                  if (tour.route.isNotEmpty) ...[
                    _buildSectionTitle('TOUR ROUTE TIMELINE'),
                    const SizedBox(height: 12),
                    _buildRouteTimeline(),
                    const SizedBox(height: 24),
                  ],

                  // What's Included Card
                  if (tour.whatsIncluded.isNotEmpty) ...[
                    _buildSectionTitle("WHAT'S INCLUDED"),
                    const SizedBox(height: 12),
                    _buildCheckList(
                      tour.whatsIncluded,
                      Icons.check_circle_rounded,
                      DesignColors.success,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Highlights / Special Features
                  if (tour.tourFeatures.isNotEmpty) ...[
                    _buildSectionTitle('TOUR HIGHLIGHTS'),
                    const SizedBox(height: 12),
                    _buildCheckList(
                      tour.tourFeatures,
                      Icons.star_rounded,
                      DesignColors.accent,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Dynamic Thumbnail slide indicators
                  if (photos.length > 1) ...[
                    _buildSectionTitle('PHOTO GALLERY'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        physics: const BouncingScrollPhysics(),
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final isSelected = _currentPhoto == index;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 110,
                                decoration: BoxDecoration(
                                  border: isSelected
                                      ? Border.all(
                                          color: DesignColors.primary,
                                          width: 2.5,
                                        )
                                      : Border.all(
                                          color: DesignColors.divider
                                              .withOpacity(0.5),
                                          width: 1,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.network(
                                  photos[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: DesignColors.divider,
                                    child: const Icon(
                                      Icons.landscape,
                                      color: DesignColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // bottom buffer space
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      // Sticky Call-to-action bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          border: Border(
            top: BorderSide(
              color: DesignColors.divider.withOpacity(0.8),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: isUserBooked
            ? SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingDetailsScreen(tour: tour),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                  label: const Text(
                    'View / Edit My Booking',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              )
            : tour.canBook
            ? Row(
                children: [
                  // Total price indicator
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL PRICE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: DesignColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${tour.price.toInt()} / person',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: DesignColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Luxury gradient confirm button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          DesignColors.primary,
                          DesignColors.primaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: DesignColors.primary.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _onJoinPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                      ),
                      child: Text(
                        status == TourStatus.idle
                            ? 'Start Tour'
                            : 'Join Tour',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_rounded, size: 19),
                  label: const Text(
                    'Filled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: DesignColors.error.withOpacity(
                      0.14,
                    ),
                    disabledForegroundColor: DesignColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: DesignColors.error.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge(TourStatus status) {
    final (String label, Color bg, Color fg) = switch (status) {
      TourStatus.fullBooked => (
        'Fully Booked',
        DesignColors.accentSecondary.withOpacity(0.15),
        DesignColors.accentSecondary,
      ),
      TourStatus.idle => (
        'Idle Available',
        DesignColors.primary.withOpacity(0.15),
        DesignColors.primaryDark,
      ),
      TourStatus.active => (
        'Active Safari',
        DesignColors.success.withOpacity(0.15),
        DesignColors.success,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: DesignColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: DesignColors.divider.withOpacity(0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: DesignColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: DesignColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: DesignColors.divider.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: DesignColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    final stops = widget.tour.route;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: DesignColors.divider.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        children: List.generate(stops.length, (i) {
          final stop = stops[i];
          final isLast = i == stops.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vertical elegant gold timeline bar
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == 0 || isLast
                              ? DesignColors.primary
                              : DesignColors.surface,
                          border: Border.all(
                            color: DesignColors.primary,
                            width: 2.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2.2,
                            color: DesignColors.primary.withOpacity(0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Location metadata
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stop.location,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          stop.time,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: DesignColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCheckList(List<String> items, IconData icon, Color iconColor) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
