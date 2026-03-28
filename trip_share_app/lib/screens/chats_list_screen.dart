import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trip_share_app/services/joined_tour_service.dart';
import 'package:trip_share_app/screens/chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
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
          'Chats',
          style: TextStyle(
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: const ChatsListBody(),
    );
  }
}

/// Body-only widget for embedding in HomeScreen nav tabs
class ChatsListBody extends StatefulWidget {
  const ChatsListBody({super.key});

  @override
  State<ChatsListBody> createState() => _ChatsListBodyState();
}

class _ChatsListBodyState extends State<ChatsListBody> {
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
    final allChats = JoinedTourService().joinedTours;

    // Deduplicate chats by tour ID
    final uniqueChats = <String, JoinedTour>{};
    for (final chat in allChats) {
      uniqueChats[chat.tour.id] = chat;
    }

    // Show all chats (both available and unavailable)
    final chats = uniqueChats.values.toList();

    return chats.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No chats yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Join a tour to chat with passengers',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Chats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 10),
              // Debug info for testing
              _buildDebugInfo(chats),
              const SizedBox(height: 12),
              for (final jt in chats) _buildChatTile(context, jt),
            ],
          );
  }

  Widget _buildDebugInfo(List<JoinedTour> chats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.withValues(alpha: 0.2),
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐛 DEBUG INFO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          for (final jt in chats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tour: ${jt.tour.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'lastJoiningTime: ${jt.tour.lastJoiningTime}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    'Now: ${DateTime.now()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    'Available: ${jt.isChatAvailable}',
                    style: TextStyle(
                      fontSize: 10,
                      color: jt.isChatAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, JoinedTour jt) {
    final tour = jt.tour;
    final isAvailable = jt.isChatAvailable;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isAvailable
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ChatScreen(tour: tour)),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Tour image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: tour.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.landscape,
                          color: Color(0xFF1B5E20),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tour.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable
                                      ? const Color(0xFF1B5E20)
                                      : Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isAvailable)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'Opens later',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tour.totalSeats - tour.remainingSeats} passengers',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable
                                ? Colors.grey
                                : Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chat_bubble,
                    size: 20,
                    color: isAvailable
                        ? const Color(0xFF1B5E20)
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
