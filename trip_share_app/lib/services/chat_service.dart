import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:trip_share_app/services/chat_cache_service.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessage(
      id: docId,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Unknown',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Map<String, dynamic> toMapWithTourId(String tourId) {
    return {
      'tourId': tourId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  bool get isMe => senderId == _currentUserId;
  static String _currentUserId = '';

  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }
}

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final ChatCacheService _cacheService = ChatCacheService();

  /// Stream of messages for a specific tour's chat with local caching
  /// Shows cached messages INSTANTLY, then streams live updates from Firestore
  Stream<List<ChatMessage>> streamChatMessages(String tourId) {
    debugPrint('📡 Setting up chat stream for tour: $tourId');

    // 1️⃣ Create the Firestore live stream
    final firestoreStream = _firestore
        .collection('messages')
        .where('tourId', isEqualTo: tourId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList(growable: false);

          debugPrint(
            '🔄 Stream received ${messages.length} messages for tour $tourId',
          );

          // Save to cache whenever new data arrives
          if (messages.isNotEmpty) {
            _cacheService.saveMessagesForTour(tourId, messages);
          }

          return messages;
        })
        .handleError((error, stackTrace) {
          // ⚠️ LOG THE FULL ERROR — this often contains the index creation URL
          debugPrint('❌ ERROR streaming messages for tour $tourId: $error');
          debugPrint('❌ Stack trace: $stackTrace');
          debugPrint(
            '💡 If you see a "FAILED_PRECONDITION" error, you need to create '
            'a composite index in Firestore for the "messages" collection '
            'with fields: tourId (Ascending) + timestamp (Ascending). '
            'Check the error message above for a direct link to create it.',
          );
        });

    // 2️⃣ Emit cached messages first, then Firestore live updates
    return _emitCachedThenLive(tourId, firestoreStream);
  }

  /// Helper: yields cached messages first, then live Firestore updates
  Stream<List<ChatMessage>> _emitCachedThenLive(
    String tourId,
    Stream<List<ChatMessage>> liveStream,
  ) async* {
    // Emit cached messages immediately
    final cachedMessages = _cacheService.getMessagesForTour(tourId);
    yield cachedMessages;
    debugPrint(
      '⚡ Emitted ${cachedMessages.length} cached messages instantly for tour $tourId',
    );

    // Then yield all live Firestore updates
    yield* liveStream;
  }

  /// Send a message to the tour's chat
  /// Stores in root-level messages collection with tourId
  Future<void> sendMessage({
    required String tourId,
    required String userId,
    required String senderName,
    required String messageText,
  }) async {
    try {
      if (tourId.isEmpty || userId.isEmpty || messageText.trim().isEmpty) {
        throw Exception('Invalid message data: missing required fields');
      }

      debugPrint(
        '📤 Sending message to tour: $tourId | From: $userId | Text: "$messageText"',
      );

      final messageData = ChatMessage(
        id: '',
        senderId: userId,
        senderName: senderName,
        text: messageText,
        timestamp: DateTime.now(),
      ).toMapWithTourId(tourId);

      debugPrint('📋 Message data to save: $messageData');

      await _firestore.collection('messages').add(messageData);

      debugPrint('✅ Message successfully sent to tour $tourId');
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Get all messages for a tour (one-time fetch)
  Future<List<ChatMessage>> getChatMessages(String tourId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('tourId', isEqualTo: tourId)
          .orderBy('timestamp')
          .get();

      debugPrint('✅ Fetched ${snapshot.docs.length} messages for tour $tourId');

      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList(growable: false);
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return [];
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String tourId, String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
      debugPrint('✅ Message deleted');
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      rethrow;
    }
  }

  /// Verify tour exists
  Future<bool> tourExists(String tourId) async {
    try {
      final doc = await _firestore.collection('tours').doc(tourId).get();
      debugPrint('📍 Tour $tourId exists: ${doc.exists}');
      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking tour: $e');
      return false;
    }
  }
}
