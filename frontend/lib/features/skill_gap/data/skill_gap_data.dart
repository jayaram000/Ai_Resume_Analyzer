import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/usecases/usecase.dart';
import 'package:frontend/core/error/failures.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/skill_gap/domain/entities/skill_gap_entities.dart';
import 'package:frontend/features/skill_gap/domain/repositories/skill_gap_repository.dart';

class SkillGapModel extends SkillGapEntity {
  const SkillGapModel({
    super.id,
    required super.targetRole,
    required super.readinessScore,
    super.readinessLevel = 'Role Transition Analysis',
    super.readinessSummary = '',
    super.matchingSkills = const [],
    super.missingSkills = const [],
    super.categorizedGaps = const {},
    super.roadmap = const [],
    super.recommendedProjects = const [],
    super.recommendedCertifications = const [],
    super.resumeTransitionTips = const [],
    super.isGuidingMode = false,
  });

  factory SkillGapModel.fromJson(Map<String, dynamic> json, String role) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    // Parse categorized gaps
    final Map<String, List<String>> parsedCategorized = {};
    if (json['categorized_gaps'] is Map) {
      final rawCat = json['categorized_gaps'] as Map;
      rawCat.forEach((key, val) {
        if (val is List) {
          parsedCategorized[key.toString()] = val.map((e) => e.toString()).toList();
        }
      });
    }

    // Parse roadmap
    final List<Map<String, dynamic>> parsedRoadmap = [];
    if (json['roadmap'] is List) {
      for (final item in json['roadmap']) {
        if (item is Map) {
          parsedRoadmap.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Parse recommended projects
    final List<Map<String, dynamic>> parsedProjects = [];
    if (json['recommended_projects'] is List) {
      for (final p in json['recommended_projects']) {
        if (p is Map) {
          parsedProjects.add(Map<String, dynamic>.from(p));
        }
      }
    }

    final target = json['target_role']?.toString() ?? role;

    return SkillGapModel(
      id: json['id']?.toString(),
      targetRole: target,
      readinessScore: (json['readiness_score'] ?? json['match_score'] as num?)?.toInt() ?? 65,
      readinessLevel: json['readiness_level']?.toString() ?? 'Strategic Role Transition',
      readinessSummary: json['readiness_summary']?.toString() ?? '',
      matchingSkills: parseStringList(json['matched_skills'] ?? json['matching_skills']),
      missingSkills: parseStringList(json['missing_skills']),
      categorizedGaps: parsedCategorized,
      roadmap: parsedRoadmap,
      recommendedProjects: parsedProjects,
      recommendedCertifications: parseStringList(json['recommended_certifications']),
      resumeTransitionTips: parseStringList(json['resume_transition_tips']),
      isGuidingMode: json['is_guiding_mode'] == true,
    );
  }
}

abstract class SkillGapRemoteDataSource {
  Future<SkillGapModel> analyzeSkillGap({required String targetRole, String? experience, String? resumeId});
  Future<List<SkillGapModel>> getRecentSkillGaps();
  Future<bool> deleteSkillGap(String id);
}

class SkillGapRemoteDataSourceImpl implements SkillGapRemoteDataSource {
  final ApiClient apiClient;
  SkillGapRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<SkillGapModel> analyzeSkillGap({required String targetRole, String? experience, String? resumeId}) async {
    try {
      final response = await apiClient.post('analysis/skill-gap/', data: {
        'target_role': targetRole,
        if (experience != null) 'experience': experience,
        if (resumeId != null) 'resume_id': resumeId,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return SkillGapModel.fromJson(Map<String, dynamic>.from(data as Map), targetRole);
      }
      throw ServerException("Failed to analyze skill gap.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<SkillGapModel>> getRecentSkillGaps() async {
    try {
      final response = await apiClient.get('analysis/skill-gap/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        if (data is List) {
          return data
              .map((e) => SkillGapModel.fromJson(Map<String, dynamic>.from(e as Map), e['target_role'] ?? 'Role'))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> deleteSkillGap(String id) async {
    try {
      final response = await apiClient.delete('analysis/skill-gap/$id/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class SkillGapRepositoryImpl implements SkillGapRepository {
  final SkillGapRemoteDataSource remoteDataSource;
  SkillGapRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<SkillGapEntity>> analyzeSkillGap({required String targetRole, String? experience, String? resumeId}) async {
    try {
      final result = await remoteDataSource.analyzeSkillGap(targetRole: targetRole, experience: experience, resumeId: resumeId);
      return Result.success(result);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<SkillGapEntity>>> getRecentSkillGaps() async {
    try {
      final result = await remoteDataSource.getRecentSkillGaps();
      return Result.success(result);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> deleteSkillGap(String id) async {
    try {
      final result = await remoteDataSource.deleteSkillGap(id);
      return Result.success(result);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
