import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_share_app/screens/booking_details_screen.dart';
import 'package:trip_share_app/screens/chat_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/dynamic_link_service.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/theme/design_system.dart';

class JoinedToursScreen extends StatefulWidget {
  const JoinedToursScreen({super.key});

  @override
  State<JoinedToursScreen> createState() => _JoinedToursScreenState();
}

class _JoinedToursScreenState extends State<JoinedToursScreen> {
  @override
  void initState() {
    super.initState();
    JoinedTourService().addListener(_onUpdate);
  }

  @override
  void dispose() {
    JoinedTourService().removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surface.withOpacity(0.8),
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: const JoinedToursBody(),
    );
  }
}

/// Body-only widget for embedding in HomeScreen nav tabs
class JoinedToursBody extends StatefulWidget {
  const JoinedToursBody({super.key});

  @override
  State<JoinedToursBody> createState() => _JoinedToursBodyState();
}

class _JoinedToursBodyState extends State<JoinedToursBody> {
  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
    // Load bookings once to populate cache
    JoinedTourService().loadBookings();
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().userId;
    return StreamBuilder<List<JoinedTour>>(
      key: ValueKey(userId),
      stream: userId.isEmpty
          ? Stream.value(const <JoinedTour>[])
          : JoinedTourService().streamBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: DesignColors.accent),
          );
        }

        final joined = snapshot.data ?? [];

        return joined.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.luggage_outlined,
                      size: 64,
                      color: DesignColors.textSecondary.withOpacity(0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No bookings yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Book a tour from the home screen',
                      style: TextStyle(
                        fontSize: 13,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: joined.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < joined.length - 1 ? 12 : 0,
                    ),
                    child: _JoinedTourCard(joinedTour: joined[index]),
                  );
                },
              );
      },
    );
  }
}

class _JoinedTourCard extends StatelessWidget {
  final JoinedTour joinedTour;

  const _JoinedTourCard({required this.joinedTour});

  @override
  Widget build(BuildContext context) {
    final tour = joinedTour.tour;

    return GestureDetector(
      onTap: () => _openBooking(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            color: DesignColors.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: DesignColors.background.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 110,
                  child: CachedNetworkImage(
                    imageUrl: tour.imageUrl,
                    fit: BoxFit.cover,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: DesignColors.primary.withOpacity(0.1),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              DesignColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: DesignColors.primary.withOpacity(0.1),
                      child: const Center(
                        child: Icon(
                          Icons.landscape,
                          size: 36,
                          color: DesignColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tour name
                      Text(
                        '${tour.name} - ${_formatShortDate(tour.startDate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: DesignColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Highlighted start date
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: DesignColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: DesignColors.primary.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: DesignColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Starts ${_formatDate(tour.startDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DesignColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: DesignColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(tour.startDate),
                              style: const TextStyle(
                                fontSize: 11,
                                color: DesignColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Persons
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 13,
                            color: DesignColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${joinedTour.persons} person(s) booked',
                            style: const TextStyle(
                              fontSize: 11,
                              color: DesignColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Seats left
                      Row(
                        children: [
                          const Icon(
                            Icons.event_seat,
                            size: 13,
                            color: DesignColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tour.remainingSeats > 0
                                ? '${tour.remainingSeats} seats left'
                                : 'Fully booked',
                            style: const TextStyle(
                              fontSize: 11,
                              color: DesignColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Journey status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: joinedTour.isLiveLocationAvailable
                              ? DesignColors.success.withOpacity(0.12)
                              : DesignColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          joinedTour.isLiveLocationAvailable
                              ? 'Journey In Progress'
                              : 'Not Started Yet',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: joinedTour.isLiveLocationAvailable
                                ? DesignColors.success
                                : DesignColors.accentSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Buttons row: View booking + Share + Chat
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: () => _openBooking(context),
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'View',
                                  style: TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: () => _shareBooking(context),
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Chat button
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(tour: tour),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Chat',
                                  style: TextStyle(fontSize: 10),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DesignColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatShortDate(DateTime date) {
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

  void _openBooking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(tour: joinedTour.tour),
      ),
    );
  }

  Future<void> _shareBooking(BuildContext context) async {
    try {
      final message = await DynamicLinkService().getTourShareMessage(
        joinedTour.tour,
      );
      await SharePlus.instance.share(
        ShareParams(
          text:
              'My booking: ${joinedTour.tour.name}\n'
              'Date: ${_formatDate(joinedTour.tour.startDate)} at '
              '${_formatTime(joinedTour.tour.startDate)}\n\n'
              '$message',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share booking: $e'),
          backgroundColor: DesignColors.error,
        ),
      );
    }
  }

  String _formatTime(DateTime date) {
    final h = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${h == 0 ? 12 : h}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
