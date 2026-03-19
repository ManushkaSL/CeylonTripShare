import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';
import 'package:trip_share_app/screens/booking_screen.dart';

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BookingScreen(tour: tour)));
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final status = tour.status;
    final photos = _allPhotos;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Photo gallery header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1B5E20),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white54,
                child: Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
              ),
              onPressed: () => Navigator.of(context).pop(),
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
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                          child: const Center(
                            child: Icon(
                              Icons.landscape,
                              size: 60,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Photo indicators
                  if (photos.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          return Container(
                            width: _currentPhoto == i ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _currentPhoto == i
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tour name
                  Text(
                    tour.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  if (tour.category.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tour.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Status badge & operator
                  Row(
                    children: [
                      _buildStatusBadge(status),
                      if (tour.operatorName.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'by ${tour.operatorName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info cards row
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.attach_money,
                        '\$${tour.price.toInt()}/person',
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        Icons.event_seat,
                        '${tour.remainingSeats} of ${tour.totalSeats} seats',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.calendar_today,
                        _formatDate(tour.startDate),
                      ),
                      const SizedBox(width: 10),
                      _buildInfoChip(
                        Icons.access_time,
                        _formatTime(tour.startDate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Start / End / Last Joining
                  _buildSectionTitle('Schedule'),
                  const SizedBox(height: 10),
                  _buildDetailCard([
                    _buildDetailRow(
                      Icons.play_circle_outline,
                      'Start',
                      '${_formatTime(tour.startDate)} at ${tour.startLocation}',
                    ),
                    if (tour.lastJoiningTime != null)
                      _buildDetailRow(
                        Icons.schedule,
                        'Last Joining',
                        '${_formatTime(tour.lastJoiningTime!)} on ${_formatDate(tour.lastJoiningTime!)}',
                      ),
                    if (tour.endTime.isNotEmpty)
                      _buildDetailRow(
                        Icons.stop_circle_outlined,
                        'End',
                        '${tour.endTime} at ${tour.endLocation}',
                      ),
                  ]),
                  const SizedBox(height: 24),

                  // Description
                  _buildSectionTitle('About This Tour'),
                  const SizedBox(height: 10),
                  Text(
                    tour.description.isNotEmpty
                        ? tour.description
                        : 'No description available for this tour yet.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Route
                  if (tour.route.isNotEmpty) ...[
                    _buildSectionTitle('Route'),
                    const SizedBox(height: 10),
                    _buildRouteTimeline(),
                    const SizedBox(height: 24),
                  ],

                  // What's Included
                  if (tour.whatsIncluded.isNotEmpty) ...[
                    _buildSectionTitle("What's Included"),
                    const SizedBox(height: 10),
                    _buildChipList(
                      tour.whatsIncluded,
                      Icons.check_circle,
                      const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tour Features
                  if (tour.tourFeatures.isNotEmpty) ...[
                    _buildSectionTitle('Tour Features'),
                    const SizedBox(height: 10),
                    _buildChipList(
                      tour.tourFeatures,
                      Icons.star_rounded,
                      const Color(0xFFF57F17),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Photo gallery section
                  if (photos.length > 1) ...[
                    _buildSectionTitle('Photos'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 130,
                                decoration: BoxDecoration(
                                  border: _currentPhoto == index
                                      ? Border.all(
                                          color: const Color(0xFF1B5E20),
                                          width: 2,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Image.network(
                                  photos[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(
                                      0xFF1B5E20,
                                    ).withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.landscape,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Operator
                  if (tour.operatorName.isNotEmpty) ...[
                    _buildSectionTitle('Operator'),
                    const SizedBox(height: 10),
                    _buildDetailCard([
                      _buildDetailRow(
                        Icons.business,
                        'Operated by',
                        tour.operatorName,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // Bottom spacing for the button
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bottom Join/Start button
      bottomNavigationBar: status != TourStatus.fullBooked
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Price summary
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '\$${tour.price.toInt()} per person',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Join button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _onJoinPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      child: Text(
                        status == TourStatus.idle ? 'Start Tour' : 'Join Tour',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFC62828),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFFC62828),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'This tour is fully booked',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ],
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
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
      ),
      TourStatus.idle => (
        'Idle',
        const Color(0xFFFFF8E1),
        const Color(0xFFF57F17),
      ),
      TourStatus.active => (
        'Active',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline() {
    final stops = widget.tour.route;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(stops.length, (i) {
          final stop = stops[i];
          final isLast = i == stops.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dots & line
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == 0 || isLast
                              ? const Color(0xFF1B5E20)
                              : Colors.white,
                          border: Border.all(
                            color: const Color(0xFF1B5E20),
                            width: 2,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: const Color(
                              0xFF1B5E20,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Stop details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF444444),
                            ),
                          ),
                        ),
                        Text(
                          stop.time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B5E20),
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

  Widget _buildChipList(List<String> items, IconData icon, Color iconColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                item,
                style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
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
