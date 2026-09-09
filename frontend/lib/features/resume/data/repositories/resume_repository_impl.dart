import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/resume/domain/entities/resume_entities.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:frontend/features/resume/data/datasources/resume_remote_data_source.dart';

class ResumeRepositoryImpl implements ResumeRepository {
  final ResumeRemoteDataSource remoteDataSource;

  ResumeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<ResumeEntity>>> getMyResumes() async {
    try {
      final list = await remoteDataSource.getMyResumes();
      return Result.success(list);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ResumeEntity>> uploadResume({required dynamic fileBytes, required String fileName, String? title}) async {
    try {
      final resume = await remoteDataSource.uploadResume(fileBytes: fileBytes, fileName: fileName, title: title);
      return Result.success(resume);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteResume(String resumeId) async {
    try {
      await remoteDataSource.deleteResume(resumeId);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ATSAnalysisEntity>> getATSAnalysis(String resumeId) async {
    try {
      final analysis = await remoteDataSource.getATSAnalysis(resumeId);
      return Result.success(analysis);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<ResumeImprovementEntity>> getResumeImprovement(String resumeId, {bool refresh = false}) async {
    try {
      final improvement = await remoteDataSource.getResumeImprovement(resumeId, refresh: refresh);
      return Result.success(improvement);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getResumeContent(String resumeId, {String type = 'diff_improved', bool refresh = false}) async {
    try {
      final content = await remoteDataSource.getResumeContent(resumeId, type: type, refresh: refresh);
      return Result.success(content);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> saveResumeContent(String resumeId, String content, {String type = 'diff_improved'}) async {
    try {
      await remoteDataSource.saveResumeContent(resumeId, content, type: type);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<JDMatchEntity>> calculateJDMatch(String resumeId, String jobDescription) async {
    try {
      final match = await remoteDataSource.calculateJDMatch(resumeId, jobDescription);
      return Result.success(match);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>>> autoTailorResume(String resumeId, String jobDescription) async {
    try {
      final result = await remoteDataSource.autoTailorResume(resumeId, jobDescription);
      return Result.success(result);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<dynamic>>> getMatchingJobs(String resumeId, {String? location}) async {
    try {
      final jobs = await remoteDataSource.getMatchingJobs(resumeId, location: location);
      return Result.success(jobs);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
