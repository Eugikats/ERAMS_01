import '../models/chat_message.dart';
import 'supabase_service.dart';

class MessageService {
  Stream<List<ChatMessage>> streamMessages(String incidentId) {
    return supabaseClient
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('incident_id', incidentId)
        .order('created_at', ascending: true)
        .map((data) =>
            data.map(ChatMessage.fromJson).toList());
  }

  Future<void> sendMessage(String incidentId, String body) async {
    await supabaseClient.from('messages').insert({
      'incident_id': incidentId,
      'sender_id': supabaseClient.auth.currentUser!.id,
      'body': body.trim(),
    });
  }

  // Marks all messages in an incident (sent by others) as seen by current user.
  Future<void> markSeen(String incidentId) async {
    try {
      await supabaseClient.rpc(
        'mark_messages_seen',
        params: {'p_incident_id': incidentId},
      );
    } catch (_) {
      // Non-fatal: ticks are cosmetic, never block the UI.
    }
  }
}
