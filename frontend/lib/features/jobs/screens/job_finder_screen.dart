import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/features/jobs/domain/repositories/job_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/theme/app_colors.dart';

class JobFinderScreen extends StatefulWidget {
  const JobFinderScreen({super.key});

  @override
  State<JobFinderScreen> createState() => _JobFinderScreenState();
}

class _JobFinderScreenState extends State<JobFinderScreen> {
  final _searchController = TextEditingController(text: "");
  final _locationController = TextEditingController(text: "Remote");

  String _experienceLevel = "Any";
  String _experienceYears = "Any";
  final List<String> _levelOptions = [
    "Any",
    "Entry level",
    "Fresher",
    "Junior",
    "Mid-level",
    "Senior",
    "Lead",
    "Director",
    "Executive"
  ];
  final List<String> _yearOptions = [
    "Any",
    "0-1",
    "1-3",
    "3-5",
    "5-8",
    "8+"
  ];

  List<dynamic> _jobs = [];
  List<dynamic> _recommendations = [];
  Set<String> _savedJobIds = {};

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendationsAndSaved();
  }

  Future<void> _loadRecommendationsAndSaved() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jobRepo = sl<JobRepository>();
      final recsRes = await jobRepo.getRecommendations();
      final savedRes = await jobRepo.getSavedJobs();

      if (recsRes.isSuccess && recsRes.data != null) {
        setState(() {
          _recommendations = recsRes.data!.map((j) => {
            'id': j.id,
            'title': j.title,
            'company_name': j.companyName,
            'location': j.location,
            'description': j.description,
            'job_type': j.jobType,
            'apply_url': j.applyUrl,
            'match_score': j.matchScore,
            'required_skills': j.requiredSkills,
          }).toList();
        });
      }

      if (savedRes.isSuccess && savedRes.data != null) {
        setState(() {
          _savedJobIds = savedRes.data!.map((j) => j.id).toSet();
        });
      }

      // Automatically search with default query to fill search results
      _searchJobs();
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load job recommendations.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchJobs() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) {
      query = "Software Developer";
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await sl<JobRepository>().searchJobs(
        query: query,
        location: _locationController.text.trim(),
        jobType: _experienceLevel == "Any" ? null : _experienceLevel,
      );

      if (res.isSuccess && res.data != null) {
        setState(() {
          _jobs = res.data!.map((j) => {
            'id': j.id,
            'title': j.title,
            'company_name': j.companyName,
            'location': j.location,
            'description': j.description,
            'job_type': j.jobType,
            'apply_url': j.applyUrl,
            'match_score': j.matchScore,
            'required_skills': j.requiredSkills,
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Job search error: $e");
      setState(() {
        _errorMessage = "RapidAPI search limit reached or connection issue. Showing recommendations below.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleBookmark(dynamic job) async {
    final jobId = job['id'].toString();
    final isSaved = _savedJobIds.contains(jobId);

    try {
      final res = await sl<JobRepository>().toggleSaveJob(jobId);
      if (res.isSuccess) {
        setState(() {
          if (isSaved) {
            _savedJobIds.remove(jobId);
          } else {
            _savedJobIds.add(jobId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isSaved ? "Job removed from bookmarks." : "Job saved successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error toggling bookmark: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _applyJob(dynamic job) async {
    final title = (job['title'] ?? 'Software Developer').toString();
    final company = (job['company_name'] ?? job['company'] ?? '').toString().trim();
    final location = (job['location'] ?? 'Remote').toString();
    final searchTerms = company.isNotEmpty ? '$company $title' : title;
    final fallbackUrl = 'https://www.linkedin.com/jobs/search/?keywords=${Uri.encodeComponent(searchTerms)}&location=${Uri.encodeComponent(location)}';
    final rawUrl = (job['apply_link'] ?? job['job_apply_link'] ?? job['apply_url'] ?? job['url'] ?? '').toString().trim();
    final applyUrl = (rawUrl.isNotEmpty && rawUrl.startsWith('http')) ? rawUrl : fallbackUrl;

    try {
      final Uri url = Uri.parse(applyUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Opening job application link...")),
        );
      }
    }
  }

  Widget _buildJobCard(dynamic jobData, {int? recommendationScore}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);

    // Check if it's the new schema (dict with job, match_score, reasons)
    final bool isRankedSchema =
        jobData is Map &&
        jobData.containsKey('job') &&
        jobData.containsKey('match_score');
    final job = isRankedSchema ? jobData['job'] : jobData;
    final int displayScore = isRankedSchema
        ? (jobData['match_score'] ?? 0)
        : (recommendationScore ?? 0);
    final reasons = isRankedSchema
        ? (jobData['reasons'] as List).cast<String>()
        : [];

    final jobId = job['id'].toString();
    final title = job['title'] ?? 'Software Developer';
    final company = job['company_name'] ?? 'Tech Company';
    final location = job['location'] ?? 'Remote';
    final isBookmarked = _savedJobIds.contains(jobId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: paperAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$company • $location",
                      style: TextStyle(
                        fontSize: 12,
                        color: inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (displayScore > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: forest.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: forest.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "$displayScore% MATCH",
                    style: TextStyle(
                      color: forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job['description'] ??
                'No job details summary available. Click Apply to see full posting details.',
            style: TextStyle(
              fontSize: 12,
              color: inkSoft,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "AUDIT MATCH REASONS:",
              style: TextStyle(
                color: cobalt,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reasons.join(" "),
              style: TextStyle(color: inkSoft, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked ? forest : inkSoft,
                ),
                onPressed: () => _toggleBookmark(job),
                tooltip: "Save Job",
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _applyJob(job),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text(
                  "APPLY LINK",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cobalt,
                  foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);

    return Scaffold(
      backgroundColor: paper,
      body: _isLoading && _jobs.isEmpty && _recommendations.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: cobalt),
            )
          : RefreshIndicator(
              onRefresh: _loadRecommendationsAndSaved,
              color: cobalt,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              hintText: "Search role (e.g. Flutter Engineer)",
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: inkSoft,
                                size: 20,
                              ),
                            ),
                            onSubmitted: (value) => _searchJobs(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _locationController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              hintText: "Location",
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                color: inkSoft,
                                size: 20,
                              ),
                            ),
                            onSubmitted: (value) => _searchJobs(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _searchJobs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cobalt,
                              foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: isDark ? AppColors.darkPaper : Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SEARCH",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          "Remote",
                          "Bengaluru",
                          "Kochi",
                          "Hyderabad",
                          "Mumbai",
                          "Chennai",
                          "London",
                          "USA"
                        ].map((loc) {
                          final isSelected = _locationController.text.trim().toLowerCase() == loc.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              label: Text(loc),
                              backgroundColor: isSelected
                                  ? cobalt.withValues(alpha: 0.12)
                                  : paperAlt,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: isSelected ? cobalt : inkSoft,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(
                                  color: isSelected ? cobalt : rule,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _locationController.text = loc;
                                });
                                _searchJobs();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _experienceLevel,
                            dropdownColor: paperAlt,
                            style: TextStyle(
                              color: ink,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Experience Level",
                              hintStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(
                                Icons.star_border_rounded,
                                color: inkSoft,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: paperAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: rule),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: rule),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: cobalt),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _levelOptions.map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(
                                  level == "Any" ? "Any Level" : level,
                                  style: TextStyle(color: ink),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _experienceLevel = val!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _experienceYears,
                            dropdownColor: paperAlt,
                            style: TextStyle(
                              color: ink,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Years",
                              hintStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(
                                Icons.timer_outlined,
                                color: inkSoft,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: paperAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: rule),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: rule),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: cobalt),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _yearOptions.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year == "Any" ? "Any Years" : year,
                                  style: TextStyle(color: ink),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _experienceYears = val!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.resolveOchre(isDark),
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Search Results (Show First)
                    if (_jobs.isNotEmpty || _isLoading) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            color: cobalt,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "ACTIVE JOB MARKET DOSSIERS",
                            style: TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_jobs.isEmpty && _isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: cobalt,
                            ),
                          ),
                        )
                      else if (_jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Text(
                              "No search results found. Try a different query.",
                              style: TextStyle(color: inkSoft),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _jobs.length,
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            return _buildJobCard(job);
                          },
                        ),
                      const SizedBox(height: 24),
                    ],

                    // AI Recommendations
                    if (_recommendations.isNotEmpty && _jobs.isEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: forest,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "RECOMMENDED JOB MATCHES",
                            style: TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recommendations.length,
                        itemBuilder: (context, index) {
                          final rec = _recommendations[index];
                          final job = rec['job'] ?? rec;
                          final score = rec['match_score'] ?? 80;
                          return _buildJobCard(job, recommendationScore: score);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
