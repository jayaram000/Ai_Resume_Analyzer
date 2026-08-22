import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/network/api_client.dart';

// Auth Clean Architecture
import 'package:frontend/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/domain/usecases/auth_usecases.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';

// Resume Clean Architecture
import 'package:frontend/features/resume/data/datasources/resume_remote_data_source.dart';
import 'package:frontend/features/resume/data/repositories/resume_repository_impl.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:frontend/features/resume/domain/usecases/resume_usecases.dart';

// Jobs Clean Architecture
import 'package:frontend/features/jobs/data/datasources/job_remote_data_source.dart';
import 'package:frontend/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:frontend/features/jobs/domain/repositories/job_repository.dart';
import 'package:frontend/features/jobs/domain/usecases/job_usecases.dart';

// Skill Gap & Roadmap Clean Architecture
import 'package:frontend/features/skill_gap/data/skill_gap_data.dart';
import 'package:frontend/features/skill_gap/domain/repositories/skill_gap_repository.dart';
import 'package:frontend/features/roadmap/data/roadmap_clean.dart';

final GetIt sl = GetIt.instance;

Future<void> initDependencyInjection() async {
  // --- Core Infrastructure ---
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<SecureStorageService>()));
  sl.registerLazySingleton<Dio>(() => sl<ApiClient>().dio);

  // --- Auth Feature ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl<ApiClient>(), storage: sl<SecureStorageService>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl<AuthRemoteDataSource>()),
  );
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton<RegisterUseCase>(() => RegisterUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton<GetProfileUseCase>(() => GetProfileUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerFactory<AuthBloc>(() => AuthBloc(authRepository: sl<AuthRepository>()));

  // --- Resume Feature ---
  sl.registerLazySingleton<ResumeRemoteDataSource>(
    () => ResumeRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<ResumeRepository>(
    () => ResumeRepositoryImpl(remoteDataSource: sl<ResumeRemoteDataSource>()),
  );
  sl.registerLazySingleton<GetMyResumesUseCase>(() => GetMyResumesUseCase(sl<ResumeRepository>()));
  sl.registerLazySingleton<GetATSAnalysisUseCase>(() => GetATSAnalysisUseCase(sl<ResumeRepository>()));
  sl.registerLazySingleton<GetResumeImprovementUseCase>(() => GetResumeImprovementUseCase(sl<ResumeRepository>()));
  sl.registerLazySingleton<AutoTailorResumeUseCase>(() => AutoTailorResumeUseCase(sl<ResumeRepository>()));
  sl.registerLazySingleton<CalculateJDMatchUseCase>(() => CalculateJDMatchUseCase(sl<ResumeRepository>()));

  // --- Jobs Feature ---
  sl.registerLazySingleton<JobRemoteDataSource>(
    () => JobRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<JobRepository>(
    () => JobRepositoryImpl(remoteDataSource: sl<JobRemoteDataSource>()),
  );
  sl.registerLazySingleton<SearchJobsUseCase>(() => SearchJobsUseCase(sl<JobRepository>()));
  sl.registerLazySingleton<GetJobRecommendationsUseCase>(() => GetJobRecommendationsUseCase(sl<JobRepository>()));
  sl.registerLazySingleton<GetSavedJobsUseCase>(() => GetSavedJobsUseCase(sl<JobRepository>()));
  sl.registerLazySingleton<ToggleSaveJobUseCase>(() => ToggleSaveJobUseCase(sl<JobRepository>()));

  // --- Skill Gap & Roadmap ---
  sl.registerLazySingleton<SkillGapRemoteDataSource>(
    () => SkillGapRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<SkillGapRepository>(
    () => SkillGapRepositoryImpl(remoteDataSource: sl<SkillGapRemoteDataSource>()),
  );
  sl.registerLazySingleton<AnalyzeSkillGapUseCase>(() => AnalyzeSkillGapUseCase(sl<SkillGapRepository>()));

  sl.registerLazySingleton<RoadmapRemoteDataSource>(
    () => RoadmapRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<RoadmapRepository>(
    () => RoadmapRepositoryImpl(remoteDataSource: sl<RoadmapRemoteDataSource>()),
  );
  sl.registerLazySingleton<GenerateRoadmapUseCase>(() => GenerateRoadmapUseCase(sl<RoadmapRepository>()));
}
