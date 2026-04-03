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
              for (final jt in chats) _buildChatTile(context, jt),
            ],
          );
  }

  Widget _buildChatTile(BuildContext context, JoinedTour jt) {
    final tour = jt.tour;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ChatScreen(tour: tour)));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
                      Text(
                        tour.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B5E20),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: JoinedTourService().getPassengerCountForTour(
                          tour.id,
                        ),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Text(
                            '$count ${count == 1 ? 'passenger' : 'passengers'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chat_bubble,
                  size: 20,
                  color: Color(0xFF1B5E20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
