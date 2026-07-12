class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final AgentActionResult? actionResult;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.actionResult,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'actionResult': actionResult?.toJson(),
      'isError': isError,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
      actionResult: json['actionResult'] != null ? AgentActionResult.fromJson(json['actionResult'] as Map<String, dynamic>) : null,
      isError: json['isError'] as bool? ?? false,
    );
  }
}

class AgentActionResult {
  final String actionType;
  final bool success;
  final String? details;

  AgentActionResult({
    required this.actionType,
    required this.success,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'success': success,
      'details': details,
    };
  }

  factory AgentActionResult.fromJson(Map<String, dynamic> json) {
    return AgentActionResult(
      actionType: json['actionType'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      details: json['details'] as String?,
    );
  }
}
