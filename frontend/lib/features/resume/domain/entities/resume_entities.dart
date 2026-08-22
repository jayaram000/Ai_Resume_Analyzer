class ResumeEntity {
  final String id;
  final String title;
  final String? fileUrl;
  final int atsScore;
  final int completenessScore;
  final DateTime createdAt;
  final String? targetPosition;
  final Map<String, dynamic>? parsedContent;

  const ResumeEntity({
    required this.id,
    required this.title,
    this.fileUrl,
    this.atsScore = 0,
    this.completenessScore = 0,
    required this.createdAt,
    this.targetPosition,
    this.parsedContent,
  });
}

class ATSAnalysisEntity {
  final String id;
  final int atsScore;
  final int keywordScore;
  final int formattingScore;
  final int skillsScore;
  final int experienceScore;
  final int educationScore;
  final int completenessScore;
  final List<String> suggestions;

  const ATSAnalysisEntity({
    required this.id,
    required this.atsScore,
    required this.keywordScore,
    required this.formattingScore,
    required this.skillsScore,
    required this.experienceScore,
    required this.educationScore,
    required this.completenessScore,
    required this.suggestions,
  });
}

class ResumeImprovementEntity {
  final String id;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, String> betterBulletPoints;
  final String summarySuggestions;
  final List<String> missingSections;
  final String? tailoredContent;
  final String? jdTailoredContent;

  const ResumeImprovementEntity({
    required this.id,
    required this.strengths,
    required this.weaknesses,
    required this.betterBulletPoints,
    required this.summarySuggestions,
    required this.missingSections,
    this.tailoredContent,
    this.jdTailoredContent,
  });
}

class JDMatchEntity {
  final int matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String? recommendations;

  const JDMatchEntity({
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    this.recommendations,
  });
}
