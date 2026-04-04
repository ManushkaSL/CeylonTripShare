import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';
import 'package:trip_share_app/screens/booking_screen.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';

class TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback? onCardTap;

  const TourCard({super.key, required this.tour, this.onCardTap});

  @override
  Widget build(BuildContext context) {
    final isFull = !tour.canBook;
    void openTourDetails() {
      if (onCardTap != null) {
        onCardTap!();
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openTourDetails,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
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
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        child: const Center(
                          child: Icon(
                            Icons.landscape,
                            size: 36,
                            color: Color(0xFF1B5E20),
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
                          tour.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Date & time row
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(tour.startDate),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.access_time,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(tour.startDate),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Capacity row
                        Row(
                          children: [
                            const Icon(
                              Icons.event_seat,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            isFull
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Full',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${tour.remainingSeats} of ${tour.totalSeats} seats',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Price
                        Text(
                          '\$${tour.price.toInt()} per person',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Status Badge
                        _buildStatusBadge(tour.status),
                        const Spacer(),
                        // Buttons row
                        Row(
                          children: [
                            // Join/Start button (hidden when full)
                            if (!isFull)
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (!AuthService().isLoggedIn) {
                                        final loggedIn = await LoginDialog.show(
                                          context,
                                        );
                                        if (!loggedIn) return;
                                      }
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              BookingScreen(tour: tour),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B5E20),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      tour.status == TourStatus.idle
                                          ? 'Start'
                                          : 'Join',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ),
                            if (!isFull) const SizedBox(width: 6),
                            // Details button
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: OutlinedButton(
                                  onPressed: openTourDetails,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF1B5E20),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Details',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Share button
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: IconButton.outlined(
                                onPressed: () {
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text:
                                          'Check out this tour: ${tour.name} - \$${tour.price.toInt()} per person!',
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.share, size: 14),
                                color: const Color(0xFF1B5E20),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF1B5E20),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TourStatus status) {
    final (String label, Color bgColor, Color fgColor) = switch (status) {
      TourStatus.fullBooked => ('Fully Booked', const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      TourStatus.idle => ('Idle', const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      TourStatus.active => ('Active', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fgColor,
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
