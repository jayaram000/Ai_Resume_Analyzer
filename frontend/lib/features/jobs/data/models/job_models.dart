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

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final skillsRaw = json['required_skills'] ?? json['skills'] ?? [];
    final List<String> skills = [];
    if (skillsRaw is List) {
      for (final s in skillsRaw) {
        skills.add(s.toString());
      }
    }

    return JobModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Position').toString(),
      companyName: (json['company_name'] ?? json['company'] ?? 'Confidential').toString(),
      location: json['location']?.toString(),
      description: json['description']?.toString(),
      jobType: json['job_type'] ?? json['type'],
      experienceLevel: json['experience_level'] ?? json['experience'],
      salaryRange: json['salary_range'] ?? json['salary'],
      applyUrl: json['apply_url'] ?? json['url'],
      requiredSkills: skills,
      isSaved: json['is_saved'] ?? false,
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
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
