import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/error/exceptions.dart';

// --- DOMAIN ENTITY ---
class RoadmapPhaseEntity {
  final String title;
  final String duration;
  final List<String> skills;
  final List<String> projects;

  const RoadmapPhaseEntity({
    required this.title,
    required this.duration,
    this.skills = const [],
    this.projects = const [],
  });
}

class RoadmapEntity {
  final String? id;
  final String targetRole;
  final String currentRole;
  final List<String> technologies;
  final List<String> certifications;
  final List<Map<String, dynamic>> learningPath;
  final List<RoadmapPhaseEntity> phases;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> youtubeVideos;
  final List<Map<String, dynamic>> youtubeChannels;
  final List<Map<String, dynamic>> documentationSites;
  final List<Map<String, dynamic>> popularCourses;
  final List<Map<String, dynamic>> freeCourses;
  final String? createdAt;

  const RoadmapEntity({
    this.id,
    required this.targetRole,
    this.currentRole = '',
    this.technologies = const [],
    this.certifications = const [],
    this.learningPath = const [],
    this.phases = const [],
    this.projects = const [],
    this.youtubeVideos = const [],
    this.youtubeChannels = const [],
    this.documentationSites = const [],
    this.popularCourses = const [],
    this.freeCourses = const [],
    this.createdAt,
  });
}

// --- DOMAIN REPOSITORY ---
abstract class RoadmapRepository {
  Future<Result<RoadmapEntity>> generateRoadmap({required String targetRole, String? currentRole});
  Future<Result<List<RoadmapEntity>>> getRecentRoadmaps();
  Future<Result<bool>> deleteRoadmap(String id);
}

// --- DOMAIN USECASE ---
class GenerateRoadmapUseCase implements UseCase<RoadmapEntity, String> {
  final RoadmapRepository repository;
  GenerateRoadmapUseCase(this.repository);

  @override
  Future<Result<RoadmapEntity>> call(String targetRole) {
    return repository.generateRoadmap(targetRole: targetRole);
  }
}

// --- DATA MODEL & DATASOURCE ---
class RoadmapModel extends RoadmapEntity {
  const RoadmapModel({
    super.id,
    required super.targetRole,
    super.currentRole = '',
    super.technologies = const [],
    super.certifications = const [],
    super.learningPath = const [],
    super.phases = const [],
    super.projects = const [],
    super.youtubeVideos = const [],
    super.youtubeChannels = const [],
    super.documentationSites = const [],
    super.popularCourses = const [],
    super.freeCourses = const [],
    super.createdAt,
  });

  factory RoadmapModel.fromJson(Map<String, dynamic> json, String targetRole) {
    final techRaw = (json['technologies'] as List<dynamic>?) ?? [];
    final certRaw = (json['certifications'] as List<dynamic>?) ?? [];
    final lpRaw = (json['learning_path'] as List<dynamic>?) ?? [];
    final phasesRaw = json['phases'] ?? lpRaw;

    final List<RoadmapPhaseEntity> parsedPhases = [];
    if (phasesRaw is List) {
      for (final p in phasesRaw) {
        if (p is Map) {
          parsedPhases.add(RoadmapPhaseEntity(
            title: (p['title'] ?? p['phase'] ?? p['name'] ?? 'Phase').toString(),
            duration: (p['duration'] ?? p['timeframe'] ?? '4 weeks').toString(),
            skills: (p['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            projects: (p['projects'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          ));
        }
      }
    }

    final List<Map<String, dynamic>> parsedLearningPath = [];
    if (lpRaw.isNotEmpty) {
      for (final item in lpRaw) {
        if (item is Map) {
          parsedLearningPath.add(Map<String, dynamic>.from(item));
        } else if (item is String) {
          parsedLearningPath.add({'phase': item, 'milestones': []});
        }
      }
    } else if (parsedPhases.isNotEmpty) {
      for (final p in parsedPhases) {
        parsedLearningPath.add({
          'phase': p.title,
          'milestones': p.skills.isNotEmpty ? p.skills : ['Master core skills', 'Complete milestone project']
        });
      }
    }

    // Projects & educational resources parsing
    List<Map<String, dynamic>> parseMapList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
      return [];
    }

    final projectsRaw = json['projects'];
    final videosRaw = json['youtube_videos'] ?? json['video_tutorials'];
    final channelsRaw = json['youtube_channels'];
    final docSitesRaw = json['documentation_sites'];
    final popCoursesRaw = json['popular_courses'];
    final freeCoursesRaw = json['free_courses'];

    final target = json['target_role']?.toString() ?? targetRole;

    return RoadmapModel(
      id: json['id']?.toString(),
      targetRole: target,
      currentRole: json['current_role']?.toString() ?? '',
      technologies: techRaw.map((e) => e.toString()).toList(),
      certifications: certRaw.map((e) => e.toString()).toList(),
      learningPath: parsedLearningPath,
      phases: parsedPhases,
      projects: parseMapList(projectsRaw),
      youtubeVideos: parseMapList(videosRaw),
      youtubeChannels: parseMapList(channelsRaw),
      documentationSites: parseMapList(docSitesRaw),
      popularCourses: parseMapList(popCoursesRaw),
      freeCourses: parseMapList(freeCoursesRaw),
      createdAt: json['created_at']?.toString(),
    );
  }
}

abstract class RoadmapRemoteDataSource {
  Future<RoadmapModel> generateRoadmap(String targetRole, [String? currentRole]);
  Future<List<RoadmapModel>> getRecentRoadmaps();
  Future<bool> deleteRoadmap(String id);
}

class RoadmapRemoteDataSourceImpl implements RoadmapRemoteDataSource {
  final ApiClient apiClient;
  RoadmapRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<RoadmapModel> generateRoadmap(String targetRole, [String? currentRole]) async {
    try {
      final response = await apiClient.post('analysis/roadmap/', data: {
        'current_role': currentRole ?? '',
        'target_role': targetRole,
      });
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return RoadmapModel.fromJson(Map<String, dynamic>.from(data as Map), targetRole);
      }
      throw ServerException("Failed to generate career roadmap.");
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<RoadmapModel>> getRecentRoadmaps() async {
    try {
      final response = await apiClient.get('analysis/roadmap/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        if (data is List) {
          return data
              .map((e) => RoadmapModel.fromJson(Map<String, dynamic>.from(e as Map), e['target_role'] ?? 'Roadmap'))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> deleteRoadmap(String id) async {
    try {
      final response = await apiClient.delete('analysis/roadmap/$id/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class RoadmapRepositoryImpl implements RoadmapRepository {
  final RoadmapRemoteDataSource remoteDataSource;
  RoadmapRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<RoadmapEntity>> generateRoadmap({required String targetRole, String? currentRole}) async {
    try {
      final model = await remoteDataSource.generateRoadmap(targetRole, currentRole);
      return Result.success(model);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<RoadmapEntity>>> getRecentRoadmaps() async {
    try {
      final models = await remoteDataSource.getRecentRoadmaps();
      return Result.success(models);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> deleteRoadmap(String id) async {
    try {
      final success = await remoteDataSource.deleteRoadmap(id);
      return Result.success(success);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
