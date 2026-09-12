import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/theme/design_system.dart';

class PremiumTourCard extends StatelessWidget {
  const PremiumTourCard({
    super.key,
    required this.tour,
    required this.onTap,
    required this.onShare,
  });

  final Tour tour;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final bookedSeats = (tour.totalSeats - tour.remainingSeats).clamp(
      0,
      tour.totalSeats,
    );
    final fillRatio = tour.totalSeats > 0 ? bookedSeats / tour.totalSeats : 0.0;
    final isScheduled =
        tour.sourceIdleTourId.isNotEmpty || tour.isCommunityRide;
    final isLimited = tour.remainingSeats > 0 && tour.remainingSeats <= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: DesignColors.divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primaryDark.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              _buildImage(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetaItem(
                            icon: Icons.calendar_month_rounded,
                            label: 'SCHEDULE',
                            value: isScheduled
                                ? _formatDateTime(tour.startDate)
                                : 'Choose your date',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: DesignColors.divider,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _MetaItem(
                            icon: Icons.airline_seat_recline_normal_rounded,
                            label: 'SEATS',
                            value:
                                '${tour.remainingSeats} of ${tour.totalSeats} available',
                            valueColor: isLimited
                                ? DesignColors.accentSecondary
                                : null,
                          ),
                        ),
                      ],
                    ),
                    if (isScheduled) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: fillRatio.clamp(0, 1),
                          backgroundColor: DesignColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLimited
                                ? DesignColors.accentSecondary
                                : DesignColors.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(child: _buildPrice()),
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                DesignColors.primary,
                                DesignColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: DesignColors.primary.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'View details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
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

  Widget _buildImage(BuildContext context) {
    return SizedBox(
      height: 178,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (tour.imageUrl.trim().isEmpty)
            _rideBackdrop()
          else
            CachedNetworkImage(
              imageUrl: tour.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => _imageFallback(light: true),
              errorWidget: (_, _, _) => _imageFallback(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.48, 1],
                colors: [
                  Color(0x33000000),
                  Color(0x11000000),
                  Color(0xCC1E160F),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Row(
              children: [
                _ImageBadge(
                  icon: Icons.star_rounded,
                  label: tour.rating.toStringAsFixed(1),
                ),
                if (tour.isCommunityRide) ...[
                  const SizedBox(width: 8),
                  const _ImageBadge(
                    icon: Icons.route_rounded,
                    label: 'Community Ride',
                  ),
                ] else if (tour.isPrivate) ...[
                  const SizedBox(width: 8),
                  const _ImageBadge(
                    icon: Icons.lock_outline_rounded,
                    label: 'Private',
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Share tour',
                onPressed: onShare,
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: DesignColors.primaryDark,
                  size: 19,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tour.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.12,
                    letterSpacing: -0.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 15,
                      color: DesignColors.primaryLight,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tour.startLocation.isEmpty
                            ? 'Sri Lanka'
                            : tour.startLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _imageFallback({bool light = false}) {
    if (tour.isCommunityRide) return _rideBackdrop();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: light
              ? const [Color(0xFFE9DFD4), Color(0xFFF7F0E9)]
              : const [Color(0xFFB99572), Color(0xFF6A4528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.landscape_rounded,
        color: light ? DesignColors.primaryLight : Colors.white70,
        size: 52,
      ),
    );
  }

  Widget _rideBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5A3C22), Color(0xFF9A704B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -54,
            right: -22,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.055),
              ),
            ),
          ),
          Positioned(
            left: -35,
            bottom: -74,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.primaryLight.withValues(alpha: 0.1),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.45, -0.05),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: DesignColors.primaryLight,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrice() {
    final price = tour.isFixedTourPricing
        ? 'Rs. ${tour.fullTourPrice.toInt()}'
        : 'Rs. ${tour.price.toInt()}';
    final caption = tour.isFixedTourPricing
        ? 'full tour · Rs. ${tour.currentPassengerPrice.toStringAsFixed(0)} each now'
        : tour.isCommunityRide
        ? 'per passenger'
        : 'per person';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          price,
          style: const TextStyle(
            color: DesignColors.primaryDark,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: DesignColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
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
    final rawHour = date.hour % 12;
    final hour = rawHour == 0 ? 12 : rawHour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]}, $hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB3211812),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DesignColors.primaryLight),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: DesignColors.secondary.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: DesignColors.primary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: DesignColors.textTertiary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? DesignColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
