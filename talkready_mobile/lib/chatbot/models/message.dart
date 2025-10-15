// Updated message.dart with fluency message type
class Message {
  final String id;
  final String text;
  final bool isUser;
  final String timestamp;
  final String? audioPath;
  final String? audioUrl;
  final bool typing;
  final MessageType type;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioPath,
    this.audioUrl,
    this.typing = false,
    this.type = MessageType.text,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp,
      'audioPath': audioPath,
      'audioUrl': audioUrl,
      'typing': typing,
      'type': type.toString(),
      'metadata': metadata,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: json['timestamp'] ?? '',
      audioPath: json['audioPath'],
      audioUrl: json['audioUrl'],
      typing: json['typing'] ?? false,
      type: _parseMessageType(json['type']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    String typeStr = type.toString().split('.').last;
    return MessageType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => MessageType.text,
    );
  }

  Message copyWith({
    String? id,
    String? text,
    bool? isUser,
    String? timestamp,
    String? audioPath,
    String? audioUrl,
    bool? typing,
    MessageType? type,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      typing: typing ?? this.typing,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum MessageType { text, audio, systemIntermediate }
