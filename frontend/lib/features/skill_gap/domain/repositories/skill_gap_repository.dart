import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/skill_gap/domain/entities/skill_gap_entities.dart';

abstract class SkillGapRepository {
  Future<Result<SkillGapEntity>> analyzeSkillGap({required String targetRole, String? experience, String? resumeId});
  Future<Result<List<SkillGapEntity>>> getRecentSkillGaps();
  Future<Result<bool>> deleteSkillGap(String id);
}

class AnalyzeSkillGapUseCase implements UseCase<SkillGapEntity, ({String targetRole, String? experience, String? resumeId})> {
  final SkillGapRepository repository;
  AnalyzeSkillGapUseCase(this.repository);

  @override
  Future<Result<SkillGapEntity>> call(({String targetRole, String? experience, String? resumeId}) params) {
    return repository.analyzeSkillGap(
      targetRole: params.targetRole,
      experience: params.experience,
      resumeId: params.resumeId,
    );
  }
}
