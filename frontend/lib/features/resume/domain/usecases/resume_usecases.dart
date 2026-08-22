import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/resume/domain/entities/resume_entities.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';

class GetMyResumesUseCase implements UseCase<List<ResumeEntity>, NoParams> {
  final ResumeRepository repository;
  GetMyResumesUseCase(this.repository);

  @override
  Future<Result<List<ResumeEntity>>> call(NoParams params) {
    return repository.getMyResumes();
  }
}

class GetATSAnalysisUseCase implements UseCase<ATSAnalysisEntity, String> {
  final ResumeRepository repository;
  GetATSAnalysisUseCase(this.repository);

  @override
  Future<Result<ATSAnalysisEntity>> call(String resumeId) {
    return repository.getATSAnalysis(resumeId);
  }
}

class GetResumeImprovementUseCase implements UseCase<ResumeImprovementEntity, ({String resumeId, bool refresh})> {
  final ResumeRepository repository;
  GetResumeImprovementUseCase(this.repository);

  @override
  Future<Result<ResumeImprovementEntity>> call(({String resumeId, bool refresh}) params) {
    return repository.getResumeImprovement(params.resumeId, refresh: params.refresh);
  }
}

class AutoTailorResumeUseCase implements UseCase<Map<String, dynamic>, ({String resumeId, String jobDescription})> {
  final ResumeRepository repository;
  AutoTailorResumeUseCase(this.repository);

  @override
  Future<Result<Map<String, dynamic>>> call(({String resumeId, String jobDescription}) params) {
    return repository.autoTailorResume(params.resumeId, params.jobDescription);
  }
}

class CalculateJDMatchUseCase implements UseCase<JDMatchEntity, ({String resumeId, String jobDescription})> {
  final ResumeRepository repository;
  CalculateJDMatchUseCase(this.repository);

  @override
  Future<Result<JDMatchEntity>> call(({String resumeId, String jobDescription}) params) {
    return repository.calculateJDMatch(params.resumeId, params.jobDescription);
  }
}
