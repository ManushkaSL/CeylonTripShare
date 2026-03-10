import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/screens/chat_screen.dart';
import 'package:trip_share_app/screens/tour_detail_screen.dart';

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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        title: const Text(
          'Joined Tours',
          style: TextStyle(
            color: Color(0xFF1B5E20),
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
    final joined = JoinedTourService().joinedTours;

    return joined.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.luggage_outlined,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No joined tours yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Join a tour from the home screen',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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
                child: _JoinedTourCard(
                  joinedTour: joined[index],
                  onUpdate: () => setState(() {}),
                ),
              );
            },
          );
  }
}

class _JoinedTourCard extends StatelessWidget {
  final JoinedTour joinedTour;
  final VoidCallback onUpdate;

  const _JoinedTourCard({required this.joinedTour, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final tour = joinedTour.tour;

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => TourDetailScreen(tour: tour)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
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
                    child: Image.network(
                      tour.imageUrl,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => Container(
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
                        // Date row
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
                        // Persons
                        Row(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${joinedTour.persons} person(s) booked',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
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
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF8E1),
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
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFF57F17),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Buttons row: Live Location + Chat
                        Row(
                          children: [
                            // Live Location button
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: ElevatedButton.icon(
                                  onPressed: joinedTour.isLiveLocationAvailable
                                      ? () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Opening live location...',
                                              ),
                                              backgroundColor: Color(
                                                0xFF1B5E20,
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: Icon(
                                    Icons.location_on,
                                    size: 13,
                                    color: joinedTour.isLiveLocationAvailable
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  label: Text(
                                    joinedTour.isLiveLocationAvailable
                                        ? 'Live Location'
                                        : 'Not Available',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        joinedTour.isLiveLocationAvailable
                                        ? const Color(0xFF1B5E20)
                                        : Colors.grey.shade300,
                                    foregroundColor:
                                        joinedTour.isLiveLocationAvailable
                                        ? Colors.white
                                        : Colors.grey,
                                    disabledBackgroundColor:
                                        Colors.grey.shade200,
                                    disabledForegroundColor: Colors.grey,
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
                                  onPressed: joinedTour.isChatAvailable
                                      ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ChatScreen(tour: tour),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 13,
                                    color: joinedTour.isChatAvailable
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  label: Text(
                                    joinedTour.isChatAvailable
                                        ? 'Chat'
                                        : 'Chat Soon',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: joinedTour.isChatAvailable
                                        ? const Color(0xFF1B5E20)
                                        : Colors.grey.shade300,
                                    foregroundColor: joinedTour.isChatAvailable
                                        ? Colors.white
                                        : Colors.grey,
                                    disabledBackgroundColor:
                                        Colors.grey.shade200,
                                    disabledForegroundColor: Colors.grey,
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

  String _formatTime(DateTime date) {
    final h = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${h == 0 ? 12 : h}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
