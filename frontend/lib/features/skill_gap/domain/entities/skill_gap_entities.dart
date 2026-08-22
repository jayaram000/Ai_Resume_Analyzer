class SkillGapEntity {
  final String? id;
  final String targetRole;
  final int readinessScore;
  final String readinessLevel;
  final String readinessSummary;
  final List<String> matchingSkills;
  final List<String> missingSkills;
  final Map<String, List<String>> categorizedGaps;
  final List<Map<String, dynamic>> roadmap;
  final List<Map<String, dynamic>> recommendedProjects;
  final List<String> recommendedCertifications;
  final List<String> resumeTransitionTips;
  final bool isGuidingMode;

  const SkillGapEntity({
    this.id,
    required this.targetRole,
    required this.readinessScore,
    this.readinessLevel = 'Role Transition Analysis',
    this.readinessSummary = '',
    this.matchingSkills = const [],
    this.missingSkills = const [],
    this.categorizedGaps = const {},
    this.roadmap = const [],
    this.recommendedProjects = const [],
    this.recommendedCertifications = const [],
    this.resumeTransitionTips = const [],
    this.isGuidingMode = false,
  });
}
