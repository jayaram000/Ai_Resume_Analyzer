import 'package:frontend/features/jobs/domain/entities/job_entities.dart';

class JobModel extends JobEntity {
  const JobModel({
    required super.id,
    required super.title,
    required super.companyName,
    super.location,
    super.description,
    super.jobType,
    super.experienceLevel,
    super.salaryRange,
    super.applyUrl,
    super.requiredSkills = const [],
    super.isSaved = false,
    super.matchScore = 0,
  });

  factory JobModel.fromJson(Map<String, dynamic> rawJson) {
    // If rawJson contains a nested 'job' object, merge it
    final Map<String, dynamic> json = rawJson.containsKey('job') && rawJson['job'] is Map<String, dynamic>
        ? {
            ...rawJson['job'] as Map<String, dynamic>,
            'match_score': rawJson['match_score'] ?? (rawJson['job'] as Map<String, dynamic>)['match_score'],
            'reasons': rawJson['reasons'] ?? (rawJson['job'] as Map<String, dynamic>)['reasons'],
            'is_saved': rawJson['is_saved'] ?? (rawJson['job'] as Map<String, dynamic>)['is_saved'],
          }
        : rawJson;

    final skillsRaw = json['required_skills'] ?? json['skills'] ?? (json['raw_data'] is Map ? json['raw_data']['required_skills'] : null) ?? [];
    final List<String> skills = [];
    if (skillsRaw is List) {
      for (final s in skillsRaw) {
        skills.add(s.toString());
      }
    }

    final title = (json['title'] ?? json['job_title'] ?? 'Software Developer').toString();
    final company = (json['company_name'] ?? json['company'] ?? 'Tech Enterprise').toString();
    final location = (json['location'] ?? 'Remote').toString();
    final description = (json['description'] ?? 'Exciting opportunity for $title in $location.').toString();
    final applyUrl = (json['apply_link'] ?? json['apply_url'] ?? json['url'] ?? 'https://www.linkedin.com/jobs').toString();

    return JobModel(
      id: (json['id'] ?? json['jsearch_id'] ?? '').toString(),
      title: title,
      companyName: company,
      location: location,
      description: description,
      jobType: json['job_type'] ?? json['type'] ?? 'Full-time',
      experienceLevel: json['experience_level'] ?? json['experience'] ?? 'Mid-Level',
      salaryRange: json['salary_range'] ?? json['salary'],
      applyUrl: applyUrl,
      requiredSkills: skills,
      isSaved: json['is_saved'] ?? false,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 85,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company_name': companyName,
      'location': location,
      'description': description,
      'job_type': jobType,
      'experience_level': experienceLevel,
      'salary_range': salaryRange,
      'apply_url': applyUrl,
      'required_skills': requiredSkills,
      'is_saved': isSaved,
      'match_score': matchScore,
    };
  }
}
