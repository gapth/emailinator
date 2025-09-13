class Task {
  final String id;
  final String userId;
  final String? emailId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? parentAction;
  final String? parentRequirementLevel;
  final String? studentAction;
  final String? studentRequirementLevel;
  final String? state;
  final DateTime? completedAt;
  final DateTime? dismissedAt;
  final DateTime? snoozedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentAt;

  const Task({
    required this.id,
    required this.userId,
    this.emailId,
    required this.title,
    this.description,
    this.dueDate,
    this.parentAction,
    this.parentRequirementLevel,
    this.studentAction,
    this.studentRequirementLevel,
    this.state,
    this.completedAt,
    this.dismissedAt,
    this.snoozedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.sentAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      userId: json['user_id'],
      emailId: json['email_id'],
      title: json['title'],
      description: json['description'],
      dueDate:
          json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      parentAction: json['parent_action'],
      parentRequirementLevel: json['parent_requirement_level'],
      studentAction: json['student_action'],
      studentRequirementLevel: json['student_requirement_level'],
      state: json['state'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.parse(json['dismissed_at'])
          : null,
      snoozedUntil: json['snoozed_until'] != null
          ? DateTime.parse(json['snoozed_until'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
    );
  }

  /// Gets the effective due date, prioritizing dueDate, then sentAt, then createdAt
  DateTime getEffectiveDueDate() {
    return dueDate ?? sentAt ?? createdAt;
  }
}
