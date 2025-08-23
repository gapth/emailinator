class Task {
  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? consequenceIfIgnore;
  final String? parentAction;
  final String? parentRequirementLevel;
  final String? studentAction;
  final String? studentRequirementLevel;
  final String status;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.consequenceIfIgnore,
    this.parentAction,
    this.parentRequirementLevel,
    this.studentAction,
    this.studentRequirementLevel,
    required this.status,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      consequenceIfIgnore: json['consequence_if_ignore'],
      parentAction: json['parent_action'],
      parentRequirementLevel: json['parent_requirement_level'],
      studentAction: json['student_action'],
      studentRequirementLevel: json['student_requirement_level'],
      status: json['status'],
    );
  }
}
