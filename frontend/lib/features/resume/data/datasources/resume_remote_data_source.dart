import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/resume/data/models/resume_models.dart';

abstract class ResumeRemoteDataSource {
  Future<List<ResumeModel>> getMyResumes();
  Future<ResumeModel> uploadResume({required dynamic fileBytes, required String fileName, String? title});
  Future<void> deleteResume(String resumeId);
  Future<ATSAnalysisModel> getATSAnalysis(String resumeId);
  Future<ResumeImprovementModel> getResumeImprovement(String resumeId, {bool refresh = false});
  Future<String> getResumeContent(String resumeId, {String type = 'diff_improved', bool refresh = false});
  Future<void> saveResumeContent(String resumeId, String content, {String type = 'diff_improved'});
  Future<JDMatchModel> calculateJDMatch(String resumeId, String jobDescription);
  Future<Map<String, dynamic>> autoTailorResume(String resumeId, String jobDescription);
  Future<List<dynamic>> getMatchingJobs(String resumeId);
}

class ResumeRemoteDataSourceImpl implements ResumeRemoteDataSource {
  final ApiClient apiClient;

  ResumeRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<ResumeModel>> getMyResumes() async {
    try {
      final response = await apiClient.get('resumes/');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data is List
            ? response.data
            : (response.data['data'] ?? response.data['results'] ?? []);
        return list.map((item) => ResumeModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw ServerException("Failed to fetch resumes.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ResumeModel> uploadResume({required dynamic fileBytes, required String fileName, String? title}) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        if (title != null) 'title': title,
      });

      final response = await apiClient.post('resumes/upload/', data: formData);
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return ResumeModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException("Failed to upload resume.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteResume(String resumeId) async {
    try {
      await apiClient.delete('resumes/$resumeId/');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ATSAnalysisModel> getATSAnalysis(String resumeId) async {
    try {
      final response = await apiClient.get('analysis/ats/$resumeId/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return ATSAnalysisModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException("Failed to load ATS analysis.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ResumeImprovementModel> getResumeImprovement(String resumeId, {bool refresh = false}) async {
    try {
      final response = await apiClient.get('analysis/improve/$resumeId/${refresh ? '?refresh=true' : ''}');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return ResumeImprovementModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException("Failed to load improvement data.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> getResumeContent(String resumeId, {String type = 'diff_improved', bool refresh = false}) async {
    try {
      final response = await apiClient.get('analysis/improve/$resumeId/content/?type=$type${refresh ? '&refresh=true' : ''}');
      if (response.statusCode == 200 && response.data != null) {
        return (response.data['data']?['content'] ?? '').toString();
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  @override
  Future<void> saveResumeContent(String resumeId, String content, {String type = 'diff_improved'}) async {
    try {
      await apiClient.put('analysis/improve/$resumeId/content/', data: {
        'content': content,
        'type': type,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JDMatchModel> calculateJDMatch(String resumeId, String jobDescription) async {
    try {
      final response = await apiClient.post('analysis/jd-match/$resumeId/', data: {
        'job_description': jobDescription,
      });
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return JDMatchModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException("Failed to compute JD match.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> autoTailorResume(String resumeId, String jobDescription) async {
    try {
      final response = await apiClient.post('analysis/auto-tailor/$resumeId/', data: {
        'job_description': jobDescription,
      });
      if (response.statusCode == 200 && response.data != null) {
        return (response.data['data'] ?? response.data) as Map<String, dynamic>;
      }
      throw ServerException("Failed to auto-tailor resume.");
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<dynamic>> getMatchingJobs(String resumeId) async {
    try {
      final response = await apiClient.get('jobs/resume-matches/$resumeId/');
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map && response.data['data'] is List) {
          return response.data['data'];
        } else if (response.data is List) {
          return response.data;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
