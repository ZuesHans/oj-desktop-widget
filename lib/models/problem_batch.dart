import 'problem_record.dart';

/// Only named fields are changed, using the latest row inside a transaction.
class ProblemBatchChange {
  const ProblemBatchChange(
      {this.folder,
      this.addTags = const [],
      this.removeTags = const [],
      this.status});

  final String? folder;
  final List<String> addTags;
  final List<String> removeTags;
  final ProblemWorkflowStatus? status;

  ProblemRecord apply(ProblemRecord problem, DateTime now) {
    final removed = removeTags.map((tag) => tag.toLowerCase()).toSet();
    return problem.copyWith(
      folder: folder,
      tags: normalizeProblemTags([...problem.tags, ...addTags])
          .where((tag) => !removed.contains(tag.toLowerCase()))
          .toList(),
      workflowStatus: status,
      archivedAt: status == ProblemWorkflowStatus.archived ? now : null,
      clearArchivedAt:
          status != null && status != ProblemWorkflowStatus.archived,
      updatedAt: now,
    );
  }
}
