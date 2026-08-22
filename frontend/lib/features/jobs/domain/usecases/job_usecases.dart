import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/features/jobs/domain/entities/job_entities.dart';
import 'package:frontend/features/jobs/domain/repositories/job_repository.dart';

class SearchJobsUseCase implements UseCase<List<JobEntity>, ({String? query, String? location, String? jobType})> {
  final JobRepository repository;
  SearchJobsUseCase(this.repository);

  @override
  Future<Result<List<JobEntity>>> call(({String? query, String? location, String? jobType}) params) {
    return repository.searchJobs(query: params.query, location: params.location, jobType: params.jobType);
  }
}

class GetJobRecommendationsUseCase implements UseCase<List<JobEntity>, NoParams> {
  final JobRepository repository;
  GetJobRecommendationsUseCase(this.repository);

  @override
  Future<Result<List<JobEntity>>> call(NoParams params) {
    return repository.getRecommendations();
  }
}

class GetSavedJobsUseCase implements UseCase<List<JobEntity>, NoParams> {
  final JobRepository repository;
  GetSavedJobsUseCase(this.repository);

  @override
  Future<Result<List<JobEntity>>> call(NoParams params) {
    return repository.getSavedJobs();
  }
}

class ToggleSaveJobUseCase implements UseCase<bool, String> {
  final JobRepository repository;
  ToggleSaveJobUseCase(this.repository);

  @override
  Future<Result<bool>> call(String jobId) {
    return repository.toggleSaveJob(jobId);
  }
}
