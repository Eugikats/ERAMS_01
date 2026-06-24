import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/message_service.dart';

/// Live stream of messages for a given incident.
/// autoDispose ensures the Supabase channel is released when no widget
/// is watching (e.g., when the relevant screen is not visible).
final messagesProvider =
    StreamProvider.family.autoDispose<List<ChatMessage>, String>(
  (ref, incidentId) => MessageService().streamMessages(incidentId),
);

/// Tracks how many messages the current user has "seen" per incident.
/// Used to compute the unread badge count on chat buttons.
class ChatSeenNotifier extends StateNotifier<Map<String, int>> {
  ChatSeenNotifier() : super(const {});

  void markSeen(String incidentId, int count) {
    state = {...state, incidentId: count};
  }
}

final chatSeenProvider =
    StateNotifierProvider<ChatSeenNotifier, Map<String, int>>(
  (_) => ChatSeenNotifier(),
);
