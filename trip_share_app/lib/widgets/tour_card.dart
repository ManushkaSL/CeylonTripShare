import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trip_share_app/models/tour.dart';
import 'package:trip_share_app/screens/booking_screen.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';
import 'package:trip_share_app/services/auth_service.dart';
import 'package:trip_share_app/widgets/login_dialog.dart';

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
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFCCE1FF).withValues(alpha: 0.14),
                  const Color(0xFF8FB2FF).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF8CC3FF).withValues(alpha: 0.2),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: 104,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: tour.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white.withValues(alpha: 0.08),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1E6DE2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.white.withValues(alpha: 0.08),
                            child: const Center(
                              child: Icon(
                                Icons.landscape,
                                size: 36,
                                color: Color(0xFF9FA9C2),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.04),
                                Colors.black.withValues(alpha: 0.48),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Color(0xFFFFD769),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tour.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 11,
                                  color: Color(0xFF8D99B8),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    tour.startLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF8D99B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '\$${tour.price.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                isFull
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFF7D9D,
                                          ).withValues(alpha: 0.2),
                                          border: Border.all(
                                            color: const Color(
                                              0xFFFF7D9D,
                                            ).withValues(alpha: 0.45),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: const Text(
                                          'Full',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFF7D9D),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        '${tour.remainingSeats}/${tour.totalSeats}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFF8D99B8),
                                        ),
                                      ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildStatusBadge(tour.status),
                          ],
                        ),
                        Row(
                          children: [
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
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.17,
                                      ),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      tour.status == TourStatus.idle
                                          ? 'Start'
                                          : 'Join',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!isFull) const SizedBox(width: 6),
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: OutlinedButton(
                                  onPressed: openTourDetails,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1.1,
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.08,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Details',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD6DEEF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
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
                                icon: const Icon(Icons.share, size: 13),
                                color: const Color(0xFFD6DEEF),
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.1,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
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
      ),
    );
  }

  Widget _buildStatusBadge(TourStatus status) {
    final (String label, Color bgColor, Color fgColor) = switch (status) {
      TourStatus.fullBooked => (
        'Fully Booked',
        const Color(0xFF3D1720),
        const Color(0xFFFF7D9D),
      ),
      TourStatus.idle => (
        'Idle',
        const Color(0xFF2C2A14),
        const Color(0xFFFFCF5B),
      ),
      TourStatus.active => (
        'Active',
        const Color(0xFF162D36),
        const Color(0xFF57D4FF),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: fgColor,
        ),
      ),
    );
  }
}
