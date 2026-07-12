/// Status of a single plan step in the execution pipeline.
enum PlanStepStatus { pending, active, done, failed }

/// Represents a single step in an AI-generated execution plan.
///
/// Each step has a [title], optional [description], a current [status],
/// optional [substeps] for finer-grained breakdown, and an optional
/// [result] string that is populated after execution.
class PlanStep {
  final String title;
  final String description;
  final PlanStepStatus status;
  final List<String> substeps;
  final String? result;

  PlanStep({
    required this.title,
    this.description = '',
    this.status = PlanStepStatus.pending,
    this.substeps = const [],
    this.result,
  });

  PlanStep copyWith({
    String? title,
    String? description,
    PlanStepStatus? status,
    List<String>? substeps,
    String? result,
  }) {
    return PlanStep(
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      substeps: substeps ?? this.substeps,
      result: result ?? this.result,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'substeps': substeps,
      'result': result,
    };
  }

  factory PlanStep.fromJson(Map<String, dynamic> json) {
    return PlanStep(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: PlanStepStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlanStepStatus.pending,
      ),
      substeps: (json['substeps'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      result: json['result'] as String?,
    );
  }
}
