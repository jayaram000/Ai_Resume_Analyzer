import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/error/exceptions.dart';
import 'package:frontend/features/jobs/data/models/job_models.dart';

abstract class JobRemoteDataSource {
  Future<List<JobModel>> searchJobs({String? query, String? location, String? jobType});
  Future<List<JobModel>> getRecommendations();
  Future<List<JobModel>> getSavedJobs();
  Future<bool> toggleSaveJob(String jobId);
  Future<JobModel> getJobDetail(String jobId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final ApiClient apiClient;

  JobRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<JobModel>> searchJobs({String? query, String? location, String? jobType}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (query != null && query.isNotEmpty) queryParams['search'] = query;
      if (location != null && location.isNotEmpty) queryParams['location'] = location;
      if (jobType != null && jobType.isNotEmpty) queryParams['job_type'] = jobType;

      final response = await apiClient.get('jobs/', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data is List
            ? response.data
            : (response.data['results'] ?? response.data['data'] ?? []);
        return list.map((item) => JobModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobModel>> getRecommendations() async {
    try {
      final response = await apiClient.get('jobs/recommendations/');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data is List
            ? response.data
            : (response.data['data'] ?? response.data['results'] ?? []);
        return list.map((item) => JobModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<JobModel>> getSavedJobs() async {
    try {
      final response = await apiClient.get('jobs/saved/');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> list = response.data is List
            ? response.data
            : (response.data['data'] ?? response.data['results'] ?? []);
        return list.map((item) => JobModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> toggleSaveJob(String jobId) async {
    try {
      final response = await apiClient.post('jobs/$jobId/save/');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['saved'] ?? true;
      }
      return true;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> getJobDetail(String jobId) async {
    try {
      final response = await apiClient.get('jobs/$jobId/');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return JobModel.fromJson(data as Map<String, dynamic>);
      }
      throw ServerException("Failed to load job details.");
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
