import 'package:frontend/features/resume/domain/entities/resume_entities.dart';

class ResumeModel extends ResumeEntity {
  const ResumeModel({
    required super.id,
    required super.title,
    super.fileUrl,
    super.atsScore = 0,
    super.completenessScore = 0,
    required super.createdAt,
    super.targetPosition,
    super.parsedContent,
  });

  factory ResumeModel.fromJson(Map<String, dynamic> json) {
    return ResumeModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Resume').toString(),
      fileUrl: json['file'] ?? json['file_url'],
      atsScore: (json['ats_score'] as num?)?.toInt() ?? 0,
      completenessScore: (json['completeness_score'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      targetPosition: json['target_position'],
      parsedContent: json['parsed_content'] is Map<String, dynamic> ? json['parsed_content'] : null,
    );
  }
}

class ATSAnalysisModel extends ATSAnalysisEntity {
  const ATSAnalysisModel({
    required super.id,
    required super.atsScore,
    required super.keywordScore,
    required super.formattingScore,
    required super.skillsScore,
    required super.experienceScore,
    required super.educationScore,
    required super.completenessScore,
    required super.suggestions,
  });

  factory ATSAnalysisModel.fromJson(Map<String, dynamic> json) {
    final suggestionsRaw = json['suggestions'];
    final List<String> suggestions = [];
    if (suggestionsRaw is List) {
      for (final s in suggestionsRaw) {
        suggestions.add(s.toString());
      }
    } else if (suggestionsRaw is String && suggestionsRaw.isNotEmpty) {
      suggestions.add(suggestionsRaw);
    }

    return ATSAnalysisModel(
      id: (json['id'] ?? '').toString(),
      atsScore: (json['ats_score'] as num?)?.toInt() ?? 0,
      keywordScore: (json['keyword_score'] as num?)?.toInt() ?? 0,
      formattingScore: (json['formatting_score'] as num?)?.toInt() ?? 0,
      skillsScore: (json['skills_score'] as num?)?.toInt() ?? 0,
      experienceScore: (json['experience_score'] as num?)?.toInt() ?? 0,
      educationScore: (json['education_score'] as num?)?.toInt() ?? 0,
      completenessScore: (json['completeness_score'] as num?)?.toInt() ?? 0,
      suggestions: suggestions,
    );
  }
}

class ResumeImprovementModel extends ResumeImprovementEntity {
  const ResumeImprovementModel({
    required super.id,
    required super.strengths,
    required super.weaknesses,
    required super.betterBulletPoints,
    required super.summarySuggestions,
    required super.missingSections,
    super.tailoredContent,
    super.jdTailoredContent,
  });

  factory ResumeImprovementModel.fromJson(Map<String, dynamic> json) {
    final Map<String, String> bulletPoints = {};
    if (json['better_bullet_points'] is Map) {
      (json['better_bullet_points'] as Map).forEach((k, v) {
        bulletPoints[k.toString()] = v.toString();
      });
    }

    return ResumeImprovementModel(
      id: (json['id'] ?? '').toString(),
      strengths: (json['strengths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weaknesses: (json['weaknesses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      betterBulletPoints: bulletPoints,
      summarySuggestions: (json['summary_suggestions'] ?? '').toString(),
      missingSections: (json['missing_sections'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tailoredContent: json['tailored_content']?.toString(),
      jdTailoredContent: json['jd_tailored_content']?.toString(),
    );
  }
}

class JDMatchModel extends JDMatchEntity {
  const JDMatchModel({
    required super.matchScore,
    required super.matchedSkills,
    required super.missingSkills,
    super.recommendations,
  });

  factory JDMatchModel.fromJson(Map<String, dynamic> json) {
    return JDMatchModel(
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      matchedSkills: (json['matched_skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      missingSkills: (json['missing_skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      recommendations: json['recommendations']?.toString(),
    );
  }
}
