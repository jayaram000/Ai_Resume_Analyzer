import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/features/jobs/domain/repositories/job_repository.dart';
import 'package:url_launcher/url_launcher.dart';

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
          backgroundColor: Colors.redAccent,
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

    return Card(
      color: const Color(0xFF1E293B).withOpacity(0.7),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$company • $location",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (displayScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "$displayScore% Match",
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              job['description'] ??
                  'No job details summary available. Click Apply to see full posting details.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE2E8F0),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "AI Analysis:",
                style: TextStyle(
                  color: const Color(0xFF6366F1),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                reasons.join(" "),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isBookmarked
                        ? const Color(0xFF14B8A6)
                        : const Color(0xFF94A3B8),
                  ),
                  onPressed: () => _toggleBookmark(job),
                  tooltip: "Save Job",
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _applyJob(job),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("Apply Link"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading && _jobs.isEmpty && _recommendations.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : RefreshIndicator(
              onRefresh: _loadRecommendationsAndSaved,
              color: const Color(0xFF6366F1),
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
                            decoration: const InputDecoration(
                              hintText: "Search role (e.g. Flutter)",
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF94A3B8),
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
                            decoration: const InputDecoration(
                              hintText: "Location",
                              prefixIcon: Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            onSubmitted: (value) => _searchJobs(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF14B8A6)],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _searchJobs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Search",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                                  ? const Color(0xFF6366F1).withOpacity(0.3)
                                  : const Color(0xFF1E293B),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
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
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Experience Level",
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              prefixIcon: const Icon(
                                Icons.star_border_rounded,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
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
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Years",
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                              ),
                              prefixIcon: const Icon(
                                Icons.timer_outlined,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
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
                                  year == "Any" ? "Any Years" : "$year Years",
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
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Search Results (Show First)
                    if (_jobs.isNotEmpty || _isLoading) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            color: Color(0xFF6366F1),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Active Job Market Results",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_jobs.isEmpty && _isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        )
                      else if (_jobs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Text(
                              "No search results found. Try a different query.",
                              style: TextStyle(color: Color(0xFF94A3B8)),
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
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF14B8A6),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Recommended Job Matches",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
