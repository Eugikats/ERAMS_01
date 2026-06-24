class ChatMessage {
  final String id;
  final String incidentId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.incidentId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  bool isMe(String userId) => senderId == userId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        incidentId: json['incident_id'] as String,
        senderId: json['sender_id'] as String,
        senderRole: json['sender_role'] as String? ?? '',
        senderName: json['sender_name'] as String? ?? '',
        body: json['body'] as String,
        createdAt:
            DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
