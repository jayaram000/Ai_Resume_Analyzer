class JobEntity {
  final String id;
  final String title;
  final String companyName;
  final String? location;
  final String? description;
  final String? jobType;
  final String? experienceLevel;
  final String? salaryRange;
  final String? applyUrl;
  final List<String> requiredSkills;
  final bool isSaved;
  final int matchScore;

  const JobEntity({
    required this.id,
    required this.title,
    required this.companyName,
    this.location,
    this.description,
    this.jobType,
    this.experienceLevel,
    this.salaryRange,
    this.applyUrl,
    this.requiredSkills = const [],
    this.isSaved = false,
    this.matchScore = 0,
  });
}
