import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trip_share_app/services/chat_service.dart';

/// Service to cache chat messages locally using Hive
class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._();
  static const String _boxName = 'chat_messages';

  factory ChatCacheService() => _instance;
  ChatCacheService._();

  late Box<String> _box;

  /// Initialize Hive and open the chat messages box
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    debugPrint('✅ Chat cache initialized');
  }

  /// Save messages for a tour to local cache
  Future<void> saveMessagesForTour(
    String tourId,
    List<ChatMessage> messages,
  ) async {
    try {
      // Convert messages to JSON and save
      final jsonList = messages
          .map(
            (m) =>
                '${m.id}|${m.senderId}|${m.senderName}|${m.text}|${m.timestamp.toIso8601String()}',
          )
          .join('\n');

      await _box.put(tourId, jsonList);
      debugPrint('💾 Cached ${messages.length} messages for tour $tourId');
    } catch (e) {
      debugPrint('❌ Error saving chat cache: $e');
    }
  }

  /// Get cached messages for a tour
  List<ChatMessage> getMessagesForTour(String tourId) {
    try {
      final jsonStr = _box.get(tourId);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final messages = <ChatMessage>[];
      for (final line in jsonStr.split('\n')) {
        if (line.isEmpty) continue;
        final parts = line.split('|');
        if (parts.length >= 5) {
          messages.add(
            ChatMessage(
              id: parts[0],
              senderId: parts[1],
              senderName: parts[2],
              text: parts[3],
              timestamp: DateTime.parse(parts[4]),
            ),
          );
        }
      }
      debugPrint(
        '📦 Loaded ${messages.length} cached messages for tour $tourId',
      );
      return messages;
    } catch (e) {
      debugPrint('❌ Error loading chat cache: $e');
      return [];
    }
  }

  /// Clear cache for a specific tour
  Future<void> clearTourCache(String tourId) async {
    await _box.delete(tourId);
    debugPrint('🗑️ Cleared cache for tour $tourId');
  }

  /// Clear all chat cache
  Future<void> clearAllCache() async {
    await _box.clear();
    debugPrint('🗑️ Cleared all chat cache');
  }
}
