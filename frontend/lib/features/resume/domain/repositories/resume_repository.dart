import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/resume/domain/entities/resume_entities.dart';

abstract class ResumeRepository {
  Future<Result<List<ResumeEntity>>> getMyResumes();
  Future<Result<ResumeEntity>> uploadResume({required dynamic fileBytes, required String fileName, String? title});
  Future<Result<void>> deleteResume(String resumeId);
  Future<Result<ATSAnalysisEntity>> getATSAnalysis(String resumeId);
  Future<Result<ResumeImprovementEntity>> getResumeImprovement(String resumeId, {bool refresh = false});
  Future<Result<String>> getResumeContent(String resumeId, {String type = 'diff_improved', bool refresh = false});
  Future<Result<void>> saveResumeContent(String resumeId, String content, {String type = 'diff_improved'});
  Future<Result<JDMatchEntity>> calculateJDMatch(String resumeId, String jobDescription);
  Future<Result<Map<String, dynamic>>> autoTailorResume(String resumeId, String jobDescription);
  Future<Result<List<dynamic>>> getMatchingJobs(String resumeId, {String? location});
}
