import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/jobs/domain/entities/job_entities.dart';
import 'package:frontend/features/jobs/domain/repositories/job_repository.dart';
import 'package:frontend/features/jobs/data/datasources/job_remote_data_source.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;

  JobRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<JobEntity>>> searchJobs({String? query, String? location, String? jobType}) async {
    try {
      final jobs = await remoteDataSource.searchJobs(query: query, location: location, jobType: jobType);
      return Result.success(jobs);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<JobEntity>>> getRecommendations() async {
    try {
      final jobs = await remoteDataSource.getRecommendations();
      return Result.success(jobs);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<JobEntity>>> getSavedJobs() async {
    try {
      final jobs = await remoteDataSource.getSavedJobs();
      return Result.success(jobs);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> toggleSaveJob(String jobId) async {
    try {
      final saved = await remoteDataSource.toggleSaveJob(jobId);
      return Result.success(saved);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<JobEntity>> getJobDetail(String jobId) async {
    try {
      final job = await remoteDataSource.getJobDetail(jobId);
      return Result.success(job);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
