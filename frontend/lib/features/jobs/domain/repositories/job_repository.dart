import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/jobs/domain/entities/job_entities.dart';

abstract class JobRepository {
  Future<Result<List<JobEntity>>> searchJobs({String? query, String? location, String? jobType});
  Future<Result<List<JobEntity>>> getRecommendations();
  Future<Result<List<JobEntity>>> getSavedJobs();
  Future<Result<bool>> toggleSaveJob(String jobId);
  Future<Result<JobEntity>> getJobDetail(String jobId);
}
