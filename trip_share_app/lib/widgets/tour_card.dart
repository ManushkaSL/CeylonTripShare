import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/booking_screen.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/services/dynamic_link_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';
import 'package:trip_share_app/widgets/custom_button.dart';
import 'package:trip_share_app/widgets/skeleton_loader.dart';
import 'package:trip_share_app/theme/design_system.dart';

class TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback? onCardTap;

  const TourCard({super.key, required this.tour, this.onCardTap});

  void _openDetails(BuildContext context) {
    if (onCardTap != null) {
      onCardTap!();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToFormat = DateTime(date.year, date.month, date.day);

    if (dateToFormat == today) {
      return 'Today';
    } else if (dateToFormat == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${date.day} ${_getMonthName(date.month)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final bool isFull = !tour.canBook;

    return GestureDetector(
      onTap: () => _openDetails(context),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DesignColors.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: DesignColors.textPrimary.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: DesignColors.background.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left image (fixed width)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 100,
                  height: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: tour.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      color: Colors.grey.shade200.withOpacity(0.06),
                      child: const Center(
                        child: SkeletonLoader(height: 60, width: 80),
                      ),
                    ),
                    errorWidget: (c, u, e) => Container(
                      color: DesignColors.primary.withOpacity(0.15),
                      child: const Center(
                        child: Icon(
                          Icons.landscape,
                          size: 40,
                          color: DesignColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Upper section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          tour.name.length > 48
                              ? tour.name.substring(0, 45) + '...'
                              : tour.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Location with icon
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: DesignColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tour.startLocation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DesignColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Date & Time
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 13,
                              color: DesignColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatDate(tour.startDate)} at ${_formatTime(tour.startDate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: DesignColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Bottom section with price, seats, status, and actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: DesignColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: DesignColors.accent.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '\$${tour.price.toInt()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DesignColors.accent,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Seats indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isFull
                                ? DesignColors.accentSecondary.withOpacity(0.12)
                                : DesignColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFull
                                  ? DesignColors.accentSecondary.withOpacity(
                                      0.3,
                                    )
                                  : DesignColors.success.withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isFull
                                ? 'Full'
                                : '${tour.remainingSeats}/${tour.totalSeats}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isFull
                                  ? DesignColors.accentSecondary
                                  : DesignColors.success,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Compact action buttons
                        if (!isFull)
                          SizedBox(
                            height: 32,
                            child: CustomButton(
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
                                    builder: (_) => BookingScreen(tour: tour),
                                  ),
                                );
                              },
                              backgroundColor: DesignColors.accent.withOpacity(
                                0.2,
                              ),
                              border: Border.all(
                                color: DesignColors.accent.withOpacity(0.4),
                                width: 0.8,
                              ),
                              textColor: DesignColors.accent,
                              borderRadius: 8,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                tour.status == TourStatus.idle
                                    ? 'Start'
                                    : 'Join',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        if (!isFull) const SizedBox(width: 6),

                        SizedBox(
                          width: 58,
                          height: 32,
                          child: CustomButton(
                            onPressed: () async {
                              try {
                                final message = await DynamicLinkService()
                                    .getTourShareMessage(tour);
                                await SharePlus.instance.share(
                                  ShareParams(text: message),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to share: $e'),
                                      backgroundColor: DesignColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            backgroundColor: DesignColors.surface.withOpacity(
                              0.4,
                            ),
                            border: Border.all(
                              color: DesignColors.textPrimary.withOpacity(0.1),
                              width: 0.8,
                            ),
                            textColor: DesignColors.textPrimary,
                            borderRadius: 8,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: const Text(
                              'Share',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomButton(
                            onPressed: () => _openDetails(context),
                            backgroundColor: DesignColors.primary.withOpacity(
                              0.2,
                            ),
                            border: Border.all(
                              color: DesignColors.primary.withOpacity(0.4),
                              width: 0.8,
                            ),
                            textColor: DesignColors.textPrimary,
                            borderRadius: 8,
                            padding: EdgeInsets.zero,
                            child: const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: DesignColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
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
}
