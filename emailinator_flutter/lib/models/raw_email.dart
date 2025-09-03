class RawEmail {
  final String id;
  final String userId;
  final String? fromEmail;
  final String? toEmail;
  final String? subject;
  final String? textBody;
  final String? htmlBody;
  final DateTime? processedAt;
  final Map<String, dynamic>? providerMeta;
  final DateTime? sentAt;
  final String? messageId;
  final int? openaiInputCostNanoUsd;
  final int? openaiOutputCostNanoUsd;
  final int? tasksBefore;
  final int? tasksAfter;
  final String status;

  const RawEmail({
    required this.id,
    required this.userId,
    this.fromEmail,
    this.toEmail,
    this.subject,
    this.textBody,
    this.htmlBody,
    this.processedAt,
    this.providerMeta,
    this.sentAt,
    this.messageId,
    this.openaiInputCostNanoUsd,
    this.openaiOutputCostNanoUsd,
    this.tasksBefore,
    this.tasksAfter,
    required this.status,
  });

  factory RawEmail.fromJson(Map<String, dynamic> json) {
    return RawEmail(
      id: json['id'],
      userId: json['user_id'],
      fromEmail: json['from_email'],
      toEmail: json['to_email'],
      subject: json['subject'],
      textBody: json['text_body'],
      htmlBody: json['html_body'],
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      providerMeta: json['provider_meta'] as Map<String, dynamic>?,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      messageId: json['message_id'],
      openaiInputCostNanoUsd: json['openai_input_cost_nano_usd'],
      openaiOutputCostNanoUsd: json['openai_output_cost_nano_usd'],
      tasksBefore: json['tasks_before'],
      tasksAfter: json['tasks_after'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_email': fromEmail,
      'to_email': toEmail,
      'subject': subject,
      'text_body': textBody,
      'html_body': htmlBody,
      'processed_at': processedAt?.toIso8601String(),
      'provider_meta': providerMeta,
      'sent_at': sentAt?.toIso8601String(),
      'message_id': messageId,
      'openai_input_cost_nano_usd': openaiInputCostNanoUsd,
      'openai_output_cost_nano_usd': openaiOutputCostNanoUsd,
      'tasks_before': tasksBefore,
      'tasks_after': tasksAfter,
      'status': status,
    };
  }
}
