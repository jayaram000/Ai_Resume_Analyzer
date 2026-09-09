import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/widgets/circular_score_gauge.dart';
import 'package:frontend/core/widgets/progress_bar_row.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class ATSAnalysisScreen extends StatefulWidget {
  final String resumeId;
  final String resumeTitle;
  final int initialTabIndex;
  final String? initialJdText;
  final String? fileUrl;

  const ATSAnalysisScreen({
    super.key,
    required this.resumeId,
    required this.resumeTitle,
    this.initialTabIndex = 0,
    this.initialJdText,
    this.fileUrl,
  });

  @override
  State<ATSAnalysisScreen> createState() => _ATSAnalysisScreenState();
}

class _ATSAnalysisScreenState extends State<ATSAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _atsData = {};
  Map<String, dynamic>? _improvementData;

  final TextEditingController _jdController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedLocation = "";
  String _detectedRole = "Software Developer";
  bool _isJobsLoading = false;
  final List<String> _quickLocations = [
    "Trivandrum",
    "Kochi",
    "Kerala",
    "Bengaluru",
    "Hyderabad",
    "Mumbai",
    "Chennai",
    "Remote",
    "London",
    "USA",
  ];

  bool _isJdLoading = false;
  Map<String, dynamic>? _jdMatchData;
  String? _jdErrorMessage;

  bool _isTailorLoading = false;
  String? _jdTailoredMarkdown;
  String? _improvedOriginalMarkdown;
  String? _originalMarkdown;
  List<dynamic> _tailorChanges = [];
  List<dynamic> _tailorKeywordsAdded = [];

  List<dynamic> _matchingJobs = [];
  Map<String, String> _userJobStatuses = {};

  // INTERACTIVE RED / GREEN DIFF SUGGESTIONS STATE
  late List<Map<String, dynamic>> _diffSuggestions;

  @override
  void initState() {
    super.initState();
    // 3 Clean Tabs: Overview, Score Breakdown & JD Matcher, Suggestions & Live Diff Editor
    final int initIdx = widget.initialTabIndex > 2 ? 2 : widget.initialTabIndex;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initIdx);

    _diffSuggestions = [];

    if (widget.initialJdText != null) {
      _jdController.text = widget.initialJdText!;
    }
    _loadAnalysisData();
    _loadUserJobStatuses();
  }

  Future<void> _loadUserJobStatuses() async {
    try {
      final res = await sl<ApiClient>().get('jobs/selected/');
      if (res.statusCode == 200) {
        final List list = (res.data is List) ? res.data : (res.data['data'] ?? []);
        final Map<String, String> map = {};
        for (var item in list) {
          final comp = (item['company_name'] ?? '').toString().toLowerCase().trim();
          final ttl = (item['job_title'] ?? '').toString().toLowerCase().trim();
          if (comp.isNotEmpty && ttl.isNotEmpty) {
            map['${comp}_$ttl'] = (item['status'] ?? 'SAVED').toString();
          }
          if (item['job'] != null && item['job'] is Map && item['job']['id'] != null) {
            map[item['job']['id'].toString()] = (item['status'] ?? 'SAVED').toString();
          }
          if (item['id'] != null) {
            map[item['id'].toString()] = (item['status'] ?? 'SAVED').toString();
          }
        }
        if (mounted) {
          setState(() {
            _userJobStatuses = map;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _updateJobTrackerStatus(dynamic job, String newStatus) async {
    final title = (job is Map ? (job['title'] ?? job['job_title']) : null) ?? 'Software Developer';
    final company = (job is Map ? (job['company_name'] ?? job['company']) : null) ?? 'TechCorp Solutions';
    final location = (job is Map ? job['location'] : null) ?? _selectedLocation;
    final applyLink = (job is Map ? (job['apply_link'] ?? job['url'] ?? job['apply_url']) : null) ?? '';
    final jobId = (job is Map ? job['id'] : null)?.toString();

    final key = '${company.toLowerCase().trim()}_${title.toLowerCase().trim()}';
    setState(() {
      _userJobStatuses[key] = newStatus;
      if (jobId != null) _userJobStatuses[jobId] = newStatus;
    });

    try {
      final res = await sl<ApiClient>().post('jobs/selected/', data: {
        if (jobId != null) 'job_id': jobId,
        'company_name': company,
        'job_title': title,
        'location': location,
        'apply_link': applyLink,
        'status': newStatus,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          final label = _statusTitles[newStatus] ?? newStatus;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✔ Moved to '$label' in Your Jobs!"),
              backgroundColor: _statusColors[newStatus] ?? const Color(0xFF14B8A6),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating job tracker: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  static const Map<String, String> _statusTitles = {
    'SAVED': 'Saved',
    'SHORTLISTED': 'Shortlisted',
    'APPLIED': 'Applied',
    'INTERVIEWING': 'Interviewing',
    'OFFER_RECEIVED': 'Offered',
    'REJECTED': 'Rejected',
  };

  static const Map<String, Color> _statusColors = {
    'SAVED': Color(0xFF6366F1),
    'SHORTLISTED': Color(0xFFF59E0B),
    'APPLIED': Color(0xFF3B82F6),
    'INTERVIEWING': Color(0xFF8B5CF6),
    'OFFER_RECEIVED': Color(0xFF22C55E),
    'REJECTED': Color(0xFFEF4444),
  };

  static const Map<String, IconData> _statusIcons = {
    'SAVED': Icons.bookmark_rounded,
    'SHORTLISTED': Icons.star_rounded,
    'APPLIED': Icons.send_rounded,
    'INTERVIEWING': Icons.forum_rounded,
    'OFFER_RECEIVED': Icons.emoji_events_rounded,
    'REJECTED': Icons.cancel_rounded,
  };

  @override
  void dispose() {
    _tabController.dispose();
    _jdController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobsForLocation([String? location]) async {
    final targetLoc = location ?? (_locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null);
    setState(() {
      _isJobsLoading = true;
      if (targetLoc != null && targetLoc.isNotEmpty) {
        _selectedLocation = targetLoc;
        _locationController.text = targetLoc;
      }
    });

    try {
      final locQuery = (targetLoc != null && targetLoc.trim().isNotEmpty)
          ? '?location=${Uri.encodeComponent(targetLoc.trim())}'
          : '';
      final response = await sl<ApiClient>().get('jobs/resume-matches/${widget.resumeId}/$locQuery');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = (data is Map && data['data'] is List) ? data['data'] : (data is List ? data : []);
        final detectedLoc = (data is Map && data['detected_location'] != null) ? data['detected_location'].toString() : null;
        final searchedLoc = (data is Map && data['searched_location'] != null) ? data['searched_location'].toString() : null;
        final detectedRole = (data is Map && data['detected_role'] != null) ? data['detected_role'].toString() : "Software Developer";

        final finalLoc = searchedLoc ?? detectedLoc ?? targetLoc ?? "Remote";
        if (mounted) {
          setState(() {
            _matchingJobs = list;
            _selectedLocation = finalLoc;
            _locationController.text = finalLoc;
            _detectedRole = detectedRole;
          });
        }
      }
    } catch (e) {
      debugPrint("Location jobs fetch error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isJobsLoading = false;
        });
      }
    }
  }

  Future<void> _loadAnalysisData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resumeRepo = sl<ResumeRepository>();

      // 1. ATS Analysis
      final atsRes = await resumeRepo.getATSAnalysis(widget.resumeId);
      if (atsRes.isSuccess && atsRes.data != null) {
        final a = atsRes.data!;
        _atsData = {
          'ats_score': a.atsScore,
          'keyword_score': a.keywordScore,
          'formatting_score': a.formattingScore,
          'skills_score': a.skillsScore,
          'experience_score': a.experienceScore,
          'education_score': a.educationScore,
          'completeness_score': a.completenessScore,
          'suggestions': a.suggestions,
        };
      }

      // 2. Resume Improvement (Loads cached data instantly from database)
      final impRes = await resumeRepo.getResumeImprovement(widget.resumeId, refresh: false);
      if (impRes.isSuccess && impRes.data != null) {
        final imp = impRes.data!;
        _improvementData = {
          'strengths': imp.strengths,
          'weaknesses': imp.weaknesses,
          'better_bullet_points': imp.betterBulletPoints,
          'summary_suggestions': imp.summarySuggestions,
          'missing_sections': imp.missingSections,
        };
      }

      // Build diff suggestions from real backend better_bullet_points
      if (_improvementData != null && _improvementData!['better_bullet_points'] != null) {
        final bulletPoints = _improvementData!['better_bullet_points'];
        if (bulletPoints is Map) {
          int idx = 0;
          final List<Map<String, dynamic>> realSuggestions = [];
          bulletPoints.forEach((oldText, newText) {
            idx++;
            realSuggestions.add({
              "id": idx.toString(),
              "section": "Resume Improvement #$idx",
              "oldText": oldText.toString(),
              "newText": newText.toString(),
              "status": "pending",
            });
          });
          _diffSuggestions = realSuggestions;
        }
      }

      // Also add summary suggestion if available
      if (_improvementData != null && _improvementData!['summary_suggestions'] != null) {
        final summaryText = _improvementData!['summary_suggestions'].toString().trim();
        if (summaryText.isNotEmpty && summaryText.length > 20) {
          _diffSuggestions.add({
            "id": "${_diffSuggestions.length + 1}",
            "section": "Professional Summary",
            "oldText": "(Current professional summary)",
            "newText": summaryText,
            "status": "pending",
          });
        }
      }

      // 3. Auto-load the original/improved resume content for Tab 3 (cached)
      final contentRes = await resumeRepo.getResumeContent(widget.resumeId, type: 'diff_improved', refresh: false);
      if (contentRes.isSuccess && contentRes.data != null && contentRes.data!.trim().length > 50) {
        _improvedOriginalMarkdown = contentRes.data!;
      }

      // 4. Also load existing JD tailored content if any
      final jdContentRes = await resumeRepo.getResumeContent(widget.resumeId, type: 'jd_tailored');
      if (jdContentRes.isSuccess && jdContentRes.data != null && jdContentRes.data!.trim().length > 50) {
        _jdTailoredMarkdown = jdContentRes.data!;
      }

      // 5. Matching jobs for resume's detected location
      await _fetchJobsForLocation();
    } catch (e) {
      debugPrint("General ATS loading error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isDownloading = false;

  Future<void> _calculateJdMatch() async {
    final jdText = _jdController.text.trim();
    if (jdText.length < 15) {
      setState(() {
        _jdErrorMessage = "Please paste a realistic job description (at least 15 characters).";
      });
      return;
    }

    setState(() {
      _isJdLoading = true;
      _jdErrorMessage = null;
    });

    try {
      final res = await sl<ResumeRepository>().calculateJDMatch(widget.resumeId, jdText);
      if (res.isSuccess && res.data != null) {
        final m = res.data!;
        setState(() {
          _jdMatchData = {
            'match_score': m.matchScore,
            'matched_skills': m.matchedSkills,
            'missing_skills': m.missingSkills,
            'recommendations': m.recommendations,
          };
        });
      } else {
        setState(() {
          _jdErrorMessage = res.failure?.message ?? "Failed to compute match score.";
        });
      }
    } catch (e) {
      setState(() {
        _jdErrorMessage = "Error computing match score: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJdLoading = false;
        });
      }
    }
  }

  Future<void> _generateTailoredResume() async {
    final jdText = _jdController.text.trim();
    if (jdText.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Job Description first.")),
      );
      return;
    }

    setState(() {
      _isTailorLoading = true;
    });

    try {
      final res = await sl<ResumeRepository>().autoTailorResume(widget.resumeId, jdText);
      if (res.isSuccess && res.data != null) {
        setState(() {
          _jdTailoredMarkdown = res.data!['markdown'] ?? res.data!['tailored_markdown'] ?? '';
          _originalMarkdown = res.data!['original_markdown'];
          _tailorChanges = res.data!['changes'] ?? [];
          _tailorKeywordsAdded = res.data!['keywords_added'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Tailoring error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isTailorLoading = false;
        });
      }
    }
  }

  Future<void> _downloadResumeWithTemplate(String templateKey, {required String downloadType}) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() {
      _isDownloading = true;
    });

    try {
      final resumeRepo = sl<ResumeRepository>();
      // Sync the content to the backend before downloading
      if (downloadType == 'jd_tailored') {
        if (_jdTailoredMarkdown != null && _jdTailoredMarkdown!.trim().length > 50) {
          await resumeRepo.saveResumeContent(
            widget.resumeId,
            _jdTailoredMarkdown!,
            type: 'jd_tailored',
          );
        }
      } else {
        if (_improvedOriginalMarkdown != null && _improvedOriginalMarkdown!.trim().length > 50) {
          await resumeRepo.saveResumeContent(
            widget.resumeId,
            _improvedOriginalMarkdown!,
            type: 'diff_improved',
          );
        }
      }

      final token = await sl<SecureStorageService>().getAccessToken();
      final String downloadUrl = "${ApiClient.baseUrl}analysis/improve/${widget.resumeId}/download/?template=$templateKey&type=$downloadType${token != null ? '&token=$token' : ''}";

      final Uri uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(downloadType == 'jd_tailored'
              ? "✔ Downloading JD-Tailored Resume PDF (${templateKey.toUpperCase()} Template)!"
              : "✔ Downloading Improved Resume PDF (${templateKey.toUpperCase()} Template)!"),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download error: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _showTemplateSelectionModal({required String downloadType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    String selectedTemplate = 'modern';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final templates = [
            {
              "key": "classic",
              "name": "Classic Executive",
              "desc": "Traditional navy & slate layout with centered header. Ideal for traditional corporate & enterprise ATS.",
              "icon": Icons.article_outlined,
              "color": const Color(0xFF1E3A8A),
            },
            {
              "key": "modern",
              "name": "Modern Tech",
              "desc": "Emerald & slate styling with left-aligned sections and colored headers. Perfect for tech & startup roles.",
              "icon": Icons.auto_awesome,
              "color": const Color(0xFF0F766E),
            },
            {
              "key": "minimalist",
              "name": "Minimalist Crisp",
              "desc": "Compact charcoal & teal design maximizing readability and content density. Great for experienced devs.",
              "icon": Icons.space_dashboard_outlined,
              "color": const Color(0xFF0D9488),
            },
          ];

          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6366F1), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          downloadType == 'jd_tailored' ? "Download JD-Tailored Resume" : "Download Improved Resume",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          downloadType == 'jd_tailored' 
                              ? "Select a template for your JD-optimized resume"
                              : "Select a template with your accepted improvements",
                          style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...templates.map((tpl) {
                  final isSelected = selectedTemplate == tpl["key"];
                  final tplColor = tpl["color"] as Color;

                  return GestureDetector(
                    onTap: () {
                      setModalState(() {
                        selectedTemplate = tpl["key"] as String;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? tplColor.withValues(alpha: 0.1) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? tplColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tplColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(tpl["icon"] as IconData, color: tplColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tpl["name"] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? tplColor : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tpl["desc"] as String,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: tpl["key"] as String,
                            groupValue: selectedTemplate,
                            activeColor: tplColor,
                            onChanged: (val) {
                              setModalState(() {
                                selectedTemplate = val!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _downloadResumeWithTemplate(selectedTemplate, downloadType: downloadType);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      "Generate & Download (${templates.firstWhere((t) => t['key'] == selectedTemplate)['name']})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    try {
      final token = await sl<SecureStorageService>().getAccessToken();
      final String downloadUrl = "${ApiClient.baseUrl}analysis/export-ats-pdf/${widget.resumeId}/?format=$format${token != null ? '&token=$token' : ''}";

      final Uri uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading ATS Analysis Report ($format)..."),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: ${e.toString()}")),
      );
    }
  }

  void _applySuggestion(int index) {
    final oldText = (_diffSuggestions[index]["oldText"] ?? "").toString().trim();
    final newText = (_diffSuggestions[index]["newText"] ?? "").toString().trim();
    final section = (_diffSuggestions[index]["section"] ?? "").toString().toLowerCase();

    setState(() {
      _diffSuggestions[index]["status"] = "applied";

      if (_improvedOriginalMarkdown != null && _improvedOriginalMarkdown!.isNotEmpty) {
        String current = _improvedOriginalMarkdown!;
        bool replaced = false;

        // Strategy 1: Direct exact substring match
        if (oldText.isNotEmpty && current.contains(oldText)) {
          current = current.replaceFirst(oldText, newText);
          replaced = true;
        }

        // Strategy 2: Line-by-line normalized word overlap match
        if (!replaced && oldText.isNotEmpty) {
          final lines = current.split('\n');
          double bestRatio = 0.0;
          int bestLineIdx = -1;

          String norm(String s) => s.replaceAll(RegExp(r'^[*\-•\s]+|\*+|_+|#+|:+'), '').trim().toLowerCase();
          final normOld = norm(oldText);
          final oldWords = normOld.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

          for (int i = 0; i < lines.length; i++) {
            final lineNorm = norm(lines[i]);
            if (lineNorm.length < 8) continue;

            if (lineNorm.contains(normOld) || normOld.contains(lineNorm)) {
              bestLineIdx = i;
              replaced = true;
              break;
            }

            if (oldWords.isNotEmpty) {
              final lineWords = lineNorm.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
              final common = oldWords.intersection(lineWords).length;
              final ratio = common / oldWords.length;
              if (ratio > 0.40 && ratio > bestRatio) {
                bestRatio = ratio;
                bestLineIdx = i;
              }
            }
          }

          if (bestLineIdx != -1) {
            final prefix = lines[bestLineIdx].trim().startsWith('*') || lines[bestLineIdx].trim().startsWith('-') ? '* ' : '';
            lines[bestLineIdx] = '$prefix$newText';
            current = lines.join('\n');
            replaced = true;
          }
        }

        // Strategy 3: Professional summary section replacement
        if (!replaced && (section.contains('summary') || oldText.contains('summary'))) {
          final sumRegex = RegExp(r'(## PROFESSIONAL SUMMARY\s*\n+)([\s\S]*?)(\n+## )', caseSensitive: false);
          if (sumRegex.hasMatch(current)) {
            current = current.replaceFirstMapped(sumRegex, (m) => '${m[1]}$newText${m[3]}');
            replaced = true;
          }
        }

        // Strategy 4: Fallback - insert under professional experience
        if (!replaced && newText.isNotEmpty) {
          if (current.contains('## PROFESSIONAL EXPERIENCE')) {
            current = current.replaceFirst('## PROFESSIONAL EXPERIENCE', '## PROFESSIONAL EXPERIENCE\n\n* $newText');
          } else {
            current = '$current\n* $newText';
          }
        }

        _improvedOriginalMarkdown = current;
      }
    });

    // Save updated markdown to backend with type=diff_improved so download endpoint outputs the exact accepted changes
    if (_improvedOriginalMarkdown != null) {
      try {
        sl<ApiClient>().put(
          'analysis/improve/${widget.resumeId}/content/',
          data: {'content': _improvedOriginalMarkdown, 'type': 'diff_improved'},
        );
      } catch (e) {
        debugPrint("Failed to sync suggestion: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✔ Suggestion accepted & applied to resume!"),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  void _rejectSuggestion(int index) {
    setState(() {
      _diffSuggestions[index]["status"] = "rejected";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✖ Suggestion dismissed."),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Opening link: $url")),
        );
      }
    }
  }

  Future<void> _applyToJob(dynamic job) async {
    final String? applyLink = (job is Map) ? (job['apply_link'] ?? job['url'] ?? job['apply_url']) : null;
    final String title = (job is Map ? (job['title'] ?? job['job_title'] ?? '') : '').toString();
    final String company = (job is Map ? (job['company_name'] ?? job['company'] ?? '') : '').toString().trim();
    final String location = (job is Map ? (job['location'] ?? '') : '').toString();
    final fallbackUrl = 'https://www.google.com/search?q=${Uri.encodeComponent('$company $title careers $location')}';
    final urlToOpen = (applyLink != null && applyLink.startsWith('http')) ? applyLink : fallbackUrl;
    _openUrl(urlToOpen);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final atsScore = (_atsData['ats_score'] as num?)?.toInt() ?? 85;
    final formattingScore = (_atsData['formatting_score'] as num?)?.toInt() ?? 90;
    final skillsScore = (_atsData['skills_score'] as num?)?.toInt() ?? 90;
    final experienceScore = (_atsData['experience_score'] as num?)?.toInt() ?? 80;
    final educationScore = (_atsData['education_score'] as num?)?.toInt() ?? 80;
    final keywordScore = (_atsData['keyword_score'] as num?)?.toInt() ?? 70;
    final completenessScore = (_atsData['completeness_score'] as num?)?.toInt() ?? 100;

    final suggestionsList = (_atsData['suggestions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [
      "Add quantifiable achievement metrics to your work experience section.",
      "Include key technical terms (Python, REST APIs, PostgreSQL) in your summary.",
      "Format dates and section headers consistently throughout your document.",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resumeTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Export Report",
            onSelected: _exportReport,
            itemBuilder: (context) => [
              const PopupMenuItem(value: "pdf", child: Text("Export as PDF Report")),
              const PopupMenuItem(value: "docx", child: Text("Export as Word Doc")),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Score Breakdown & JD Match"),
            Tab(text: "AI Suggestions & Diff Editor"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: TextStyle(color: textPrimary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalysisData,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                        child: const Text("Retry", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: OVERVIEW
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 750;
                              return isWide
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 2, child: _buildAtsGaugeCard(atsScore, cardBg, borderColor, textPrimary, isDark)),
                                        const SizedBox(width: 20),
                                        Expanded(flex: 3, child: _buildQuickScoreBreakdownCard(completenessScore, skillsScore, experienceScore, educationScore, formattingScore, keywordScore, cardBg, borderColor, textPrimary)),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildAtsGaugeCard(atsScore, cardBg, borderColor, textPrimary, isDark),
                                        const SizedBox(height: 16),
                                        _buildQuickScoreBreakdownCard(completenessScore, skillsScore, experienceScore, educationScore, formattingScore, keywordScore, cardBg, borderColor, textPrimary),
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 24),

                          // AI SUGGESTIONS CHECKLIST CARD
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI Suggestions Summary",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 16),
                                ...suggestionsList.map((sug) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.arrow_right_rounded, color: Color(0xFF6366F1), size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              sug,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: () => _tabController.animateTo(2),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF6366F1),
                                    side: const BorderSide(color: Color(0xFF6366F1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text("Open Live Diff Editor"),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // REAL-TIME MATCHING JOBS SECTION
                          _buildRealTimeJobsSection(cardBg, borderColor, textPrimary, textSecondary, isDark),
                        ],
                      ),
                    ),

                    // TAB 2: SCORE BREAKDOWN & JD MATCHER
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Detailed ATS Score Categories",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                const SizedBox(height: 16),
                                ProgressBarRow(label: "Contact Info & Completeness", percentage: completenessScore, barColor: const Color(0xFF22C55E)),
                                ProgressBarRow(label: "Technical Skills Alignment", percentage: skillsScore, barColor: const Color(0xFF22C55E)),
                                ProgressBarRow(label: "Experience Impact & Depth", percentage: experienceScore, barColor: const Color(0xFF22C55E)),
                                ProgressBarRow(label: "Education & Certifications", percentage: educationScore, barColor: const Color(0xFF22C55E)),
                                ProgressBarRow(label: "Document Formatting", percentage: formattingScore, barColor: const Color(0xFF22C55E)),
                                ProgressBarRow(label: "Keyword Density", percentage: keywordScore, barColor: const Color(0xFFF59E0B)),
                                ProgressBarRow(label: "Readability Index", percentage: 85, barColor: const Color(0xFF22C55E)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text("Job Description Semantic Matcher", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _jdController,
                            maxLines: 4,
                            style: TextStyle(color: textPrimary),
                            decoration: const InputDecoration(
                              hintText: "Paste target job description text here to measure fit score...",
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isJdLoading ? null : _calculateJdMatch,
                                icon: _isJdLoading 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.analytics_rounded, size: 18),
                                label: Text(_isJdLoading ? "Analyzing Match..." : "Run JD Match Analysis"),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _isTailorLoading ? null : _generateTailoredResume,
                                icon: _isTailorLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                                label: Text(_isTailorLoading ? "Tailoring..." : "Auto-Tailor Resume"),
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF14B8A6)),
                              ),
                            ],
                          ),
                          if (_isJdLoading) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(28),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(color: Color(0xFF6366F1)),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Deep comparing resume against job requirements...",
                                    style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_jdErrorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _jdErrorMessage!,
                                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _calculateJdMatch,
                                    child: const Text("Retry", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_jdMatchData != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircularScoreGauge(
                                        score: (_jdMatchData!['match_score'] as num?)?.toInt() ?? 75,
                                        size: 90,
                                        strokeWidth: 10,
                                        progressColor: const Color(0xFF22C55E),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Job Description Fit: ${(_jdMatchData!['match_score'] as num?)?.toInt() ?? 75}%",
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              ((_jdMatchData!['match_score'] as num?)?.toInt() ?? 75) >= 75
                                                  ? "Excellent alignment with this position's core requirements."
                                                  : "Moderate alignment. Review missing skills to maximize interview callback rates.",
                                              style: TextStyle(fontSize: 13, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  // Matched Skills
                                  Text("Matched Skills", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (((_jdMatchData!['matched_skills'] as List?) ?? []).isEmpty
                                            ? ["Core technical stack"]
                                            : ((_jdMatchData!['matched_skills'] as List).map((e) => e.toString()).toList()))
                                        .map((s) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                                                  const SizedBox(width: 5),
                                                  Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  // Missing Skills
                                  Text("Missing / Recommended Skills", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (((_jdMatchData!['missing_skills'] as List?) ?? []).isEmpty
                                            ? ["None detected - strong coverage"]
                                            : ((_jdMatchData!['missing_skills'] as List).map((e) => e.toString()).toList()))
                                        .map((s) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFF59E0B), size: 14),
                                                  const SizedBox(width: 5),
                                                  Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                  if (_jdMatchData!['recommendations'] != null && _jdMatchData!['recommendations'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF6366F1), size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Actionable Recommendations",
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _jdMatchData!['recommendations'].toString(),
                                                  style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (_jdTailoredMarkdown != null) ...[
                            const SizedBox(height: 24),

                            // ── CHANGES SUMMARY CARD ──
                            if (_tailorChanges.isNotEmpty || _tailorKeywordsAdded.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.auto_fix_high, color: Color(0xFF22C55E), size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "What Changed — Tailoring Summary",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_tailorKeywordsAdded.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        "Keywords Incorporated:",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: _tailorKeywordsAdded.map((kw) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            "+ $kw",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                    if (_tailorChanges.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        "Specific Changes Made:",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      ...List.generate(_tailorChanges.length, (i) {
                                        final change = _tailorChanges[i];
                                        final section = change is Map ? (change['section'] ?? '') : '';
                                        final desc = change is Map ? (change['description'] ?? '') : change.toString();
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${i + 1}. ",
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                              ),
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: section.isNotEmpty ? "[$section] " : "",
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                                      ),
                                                      TextSpan(
                                                        text: desc,
                                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),

                            // ── TAILORED RESUME OUTPUT ──
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Auto-Tailored Resume Output",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _jdTailoredMarkdown!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Copied tailored resume markdown to clipboard!")),
                                              );
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            label: const Text("Copy Text"),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _showTemplateSelectionModal(downloadType: 'jd_tailored'),
                                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                            label: const Text("Download PDF (Select Template)"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF6366F1),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  MarkdownBody(data: _jdTailoredMarkdown!),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // TAB 3: INTERACTIVE AI SUGGESTIONS & RED/GREEN DIFF EDITOR
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Interactive AI Suggestions",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Review red (content to remove) vs green (AI suggested bullet) and click ✔ Accept or ✖ Remove.",
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isDownloading ? null : () => _showTemplateSelectionModal(downloadType: 'diff_improved'),
                                icon: _isDownloading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.download_rounded, size: 18),
                                label: const Text("Download Improved Resume PDF"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // RENDERING INTERACTIVE DIFF CARDS
                          ..._diffSuggestions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final status = item['status'] as String;

                            if (status == 'rejected') return const SizedBox.shrink();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['section'] as String,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (status == 'applied')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                "Applied to Resume",
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF22C55E)),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // RED CARD: OLD / WEAK BULLET TO REMOVE
                                  if (status != 'applied')
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Original / Content to Remove",
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item['oldText'] as String,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFFEF4444),
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _rejectSuggestion(idx),
                                            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
                                            tooltip: "Dismiss / Remove Point",
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (status != 'applied') const SizedBox(height: 12),

                                  // GREEN CARD: NEW AI SUGGESTED BULLET TO ADD
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF14532D) : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF22C55E), size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "AI Suggested Bullet / Content to Add",
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF22C55E)),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['newText'] as String,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (status != 'applied')
                                          ElevatedButton.icon(
                                            onPressed: () => _applySuggestion(idx),
                                            icon: const Icon(Icons.check_rounded, size: 16),
                                            label: const Text("Accept"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF22C55E),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAtsGaugeCard(int atsScore, Color cardBg, Color borderColor, Color textPrimary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            "ATS Score",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 20),
          CircularScoreGauge(
            score: atsScore,
            size: 150,
            strokeWidth: 14,
            progressColor: atsScore >= 80 ? const Color(0xFF22C55E) : (atsScore >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
            statusText: atsScore >= 80 ? "Great Score!" : "Good Baseline",
            statusTextColor: const Color(0xFF22C55E),
          ),
          const SizedBox(height: 16),
          Text(
            "You're in the top 20% of candidates.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScoreBreakdownCard(int completeness, int skills, int experience, int education, int formatting, int keywords, Color cardBg, Color borderColor, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Score Breakdown",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 16),
          ProgressBarRow(label: "Contact Info & Structure", percentage: completeness, barColor: const Color(0xFF22C55E)),
          ProgressBarRow(label: "Technical Skills Fit", percentage: skills, barColor: const Color(0xFF22C55E)),
          ProgressBarRow(label: "Work Experience", percentage: experience, barColor: const Color(0xFF22C55E)),
          ProgressBarRow(label: "Education & Degrees", percentage: education, barColor: const Color(0xFF22C55E)),
          ProgressBarRow(label: "Formatting Quality", percentage: formatting, barColor: const Color(0xFF22C55E)),
          ProgressBarRow(label: "Keyword Density", percentage: keywords, barColor: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildRealTimeJobsSection(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.radar_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Real-Time Matching Jobs",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      "Live opportunities ranked by resume skills & location",
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                  SizedBox(width: 6),
                  Text(
                    "Live Match",
                    style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Location Search Input Bar & Quick Presets
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Enter location (e.g. Bengaluru, Kochi, London, Remote)...",
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF6366F1), size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        ),
                      ),
                      onSubmitted: (val) => _fetchJobsForLocation(val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isJobsLoading ? null : () => _fetchJobsForLocation(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isJobsLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("Search", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Preset chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickLocations.map((loc) {
                    final isSelected = _selectedLocation.toLowerCase() == loc.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(loc),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF6366F1),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF6366F1) : textSecondary,
                        ),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF6366F1) : borderColor,
                          ),
                        ),
                        onSelected: (selected) {
                          _locationController.text = loc;
                          _fetchJobsForLocation(loc);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Platform Search Header Bar
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Direct Search on Top Job Portals",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                        ),
                        Text(
                          "1-Tap search live openings for your role in $_selectedLocation",
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPlatformSearchChip(
                      label: "LinkedIn Jobs",
                      icon: Icons.business_center_rounded,
                      color: const Color(0xFF0A66C2),
                      onTap: () {
                        final role = _detectedRole.isNotEmpty ? _detectedRole : "Software Developer";
                        _openUrl("https://www.linkedin.com/jobs/search/?keywords=${Uri.encodeComponent(role)}&location=${Uri.encodeComponent(_selectedLocation)}");
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformSearchChip(
                      label: "Naukri.com",
                      icon: Icons.work_history_rounded,
                      color: const Color(0xFF2B5BE7),
                      onTap: () {
                        final role = _detectedRole.isNotEmpty ? _detectedRole : "Software Developer";
                        final locSlug = _selectedLocation.toLowerCase().replaceAll(' ', '-');
                        _openUrl("https://www.naukri.com/jobs-in-$locSlug?kwd=${Uri.encodeComponent(role)}");
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformSearchChip(
                      label: "Indeed",
                      icon: Icons.search_rounded,
                      color: const Color(0xFF2164F3),
                      onTap: () {
                        final role = _detectedRole.isNotEmpty ? _detectedRole : "Software Developer";
                        _openUrl("https://www.indeed.com/jobs?q=${Uri.encodeComponent(role)}&l=${Uri.encodeComponent(_selectedLocation)}");
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformSearchChip(
                      label: "Foundit",
                      icon: Icons.flash_on_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        final role = _detectedRole.isNotEmpty ? _detectedRole : "Software Developer";
                        _openUrl("https://www.foundit.in/srp/results?query=${Uri.encodeComponent(role)}&locations=${Uri.encodeComponent(_selectedLocation)}");
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformSearchChip(
                      label: "Google Jobs",
                      icon: Icons.travel_explore_rounded,
                      color: const Color(0xFFEA4335),
                      onTap: () {
                        final role = _detectedRole.isNotEmpty ? _detectedRole : "Software Developer";
                        _openUrl("https://www.google.com/search?q=${Uri.encodeComponent('$role jobs in $_selectedLocation')}&ibp=htl;jobs");
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Jobs Display
        if (_isJobsLoading) ...[
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                Text(
                  "Finding real-world matching roles in $_selectedLocation...",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ] else if (_matchingJobs.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Icon(Icons.work_off_rounded, color: Color(0xFF94A3B8), size: 40),
                const SizedBox(height: 12),
                Text(
                  "No matching jobs found in $_selectedLocation.",
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  "Try searching another city or switch back to Remote.",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _locationController.text = "Remote";
                    _fetchJobsForLocation("Remote");
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Show Remote Jobs"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ..._matchingJobs.map((jobItem) {
            final job = (jobItem is Map && jobItem.containsKey('job')) ? jobItem['job'] : jobItem;
            final int matchScore = (jobItem is Map && jobItem.containsKey('match_score'))
                ? (jobItem['match_score'] as num?)?.toInt() ?? 85
                : (job is Map && job.containsKey('match_score') ? (job['match_score'] as num?)?.toInt() ?? 85 : 85);

            final String title = (job is Map ? job['title'] : null) ?? 'Software Developer';
            final String company = (job is Map ? job['company_name'] : null) ?? 'TechCorp Solutions';
            final String location = (job is Map ? job['location'] : null) ?? _selectedLocation;
            final String description = (job is Map ? job['description'] : null) ?? 'Exciting opportunity for experienced developers.';

            List<String> tags = [];
            if (job is Map && job['raw_data'] is Map && job['raw_data']['required_skills'] is List) {
              tags = (job['raw_data']['required_skills'] as List).map((e) => e.toString()).toList();
            } else if (job is Map && job['raw_data'] is Map && job['raw_data']['tags'] is List) {
              tags = (job['raw_data']['tags'] as List).map((e) => e.toString()).toList();
            }
            if (tags.isEmpty) {
              tags = ["Python", "Django", "REST APIs", "PostgreSQL"];
            }

            final jobKey = '${company.toLowerCase().trim()}_${title.toLowerCase().trim()}';
            final jobIdStr = (job is Map ? job['id'] : null)?.toString();
            final currentStatus = _userJobStatuses[jobKey] ?? (jobIdStr != null ? _userJobStatuses[jobIdStr] : null);

            String sourcePlatform = "Official Career Portal";
            if (job is Map && job['raw_data'] is Map && job['raw_data']['source_platform'] != null) {
              sourcePlatform = job['raw_data']['source_platform'].toString();
            } else if (job is Map && job['source_platform'] != null) {
              sourcePlatform = job['source_platform'].toString();
            } else if (job is Map && job['source'] != null) {
              sourcePlatform = job['source'].toString();
            }

            Color platformColor = const Color(0xFF6366F1);
            IconData platformIcon = Icons.verified_user_rounded;
            final srcLower = sourcePlatform.toLowerCase();
            if (srcLower.contains("linkedin")) {
              platformColor = const Color(0xFF0A66C2);
              platformIcon = Icons.business_center_rounded;
            } else if (srcLower.contains("naukri")) {
              platformColor = const Color(0xFF2B5BE7);
              platformIcon = Icons.work_history_rounded;
            } else if (srcLower.contains("indeed")) {
              platformColor = const Color(0xFF2164F3);
              platformIcon = Icons.search_rounded;
            } else if (srcLower.contains("remotive")) {
              platformColor = const Color(0xFF10B981);
              platformIcon = Icons.public_rounded;
            } else if (srcLower.contains("jobicy")) {
              platformColor = const Color(0xFF8B5CF6);
              platformIcon = Icons.bolt_rounded;
            } else if (srcLower.contains("themuse") || srcLower.contains("muse")) {
              platformColor = const Color(0xFFEC4899);
              platformIcon = Icons.hub_rounded;
            } else if (srcLower.contains("arbeitnow")) {
              platformColor = const Color(0xFFF59E0B);
              platformIcon = Icons.domain_rounded;
            } else if (srcLower.contains("allianz")) {
              platformColor = const Color(0xFF003781);
              platformIcon = Icons.shield_rounded;
            } else if (srcLower.contains("ust")) {
              platformColor = const Color(0xFFE11931);
              platformIcon = Icons.corporate_fare_rounded;
            } else if (srcLower.contains("tcs") || srcLower.contains("ibegin")) {
              platformColor = const Color(0xFF0078D4);
              platformIcon = Icons.apartment_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(platformIcon, color: platformColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  company,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.location_on_outlined, size: 14, color: textSecondary),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                        ),
                        child: Text(
                          "$matchScore% Match",
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.take(5).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                          ),
                        )).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: platformColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(platformIcon, size: 13, color: platformColor),
                            const SizedBox(width: 6),
                            Text(
                              "Direct Opening • $sourcePlatform",
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: platformColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Direct Platform Quick Search Links for this specific role
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text("Search on:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                        const SizedBox(width: 8),
                        _buildMiniPlatformChip(
                          label: "LinkedIn",
                          color: const Color(0xFF0A66C2),
                          onTap: () => _openUrl("https://www.linkedin.com/jobs/search/?keywords=${Uri.encodeComponent('$company $title')}&location=${Uri.encodeComponent(location)}"),
                        ),
                        const SizedBox(width: 6),
                        _buildMiniPlatformChip(
                          label: "Naukri",
                          color: const Color(0xFF2B5BE7),
                          onTap: () => _openUrl("https://www.naukri.com/jobs-in-${Uri.encodeComponent(location.toLowerCase().replaceAll(' ', '-'))}?kwd=${Uri.encodeComponent('$company $title')}"),
                        ),
                        const SizedBox(width: 6),
                        _buildMiniPlatformChip(
                          label: "Indeed",
                          color: const Color(0xFF2164F3),
                          onTap: () => _openUrl("https://www.indeed.com/jobs?q=${Uri.encodeComponent('$company $title')}&l=${Uri.encodeComponent(location)}"),
                        ),
                        const SizedBox(width: 6),
                        _buildMiniPlatformChip(
                          label: "Google Jobs",
                          color: const Color(0xFFEA4335),
                          onTap: () => _openUrl("https://www.google.com/search?q=${Uri.encodeComponent('$company $title jobs in $location')}&ibp=htl;jobs"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Move to / Track Status Dropdown
                      PopupMenuButton<String>(
                        tooltip: "Save & Move to Your Jobs",
                        onSelected: (newSt) => _updateJobTrackerStatus(job, newSt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: currentStatus != null
                                ? (_statusColors[currentStatus] ?? const Color(0xFF6366F1)).withOpacity(0.12)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: currentStatus != null
                                  ? (_statusColors[currentStatus] ?? const Color(0xFF6366F1)).withOpacity(0.4)
                                  : borderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                currentStatus != null ? (_statusIcons[currentStatus] ?? Icons.bookmark_rounded) : Icons.bookmark_add_outlined,
                                size: 14,
                                color: currentStatus != null ? (_statusColors[currentStatus] ?? const Color(0xFF6366F1)) : textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                currentStatus != null ? (_statusTitles[currentStatus] ?? currentStatus) : "Track Job",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: currentStatus != null ? (_statusColors[currentStatus] ?? const Color(0xFF6366F1)) : textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down_rounded, size: 16, color: textSecondary),
                            ],
                          ),
                        ),
                        itemBuilder: (ctx) => [
                          ..._statusTitles.entries.map((entry) {
                            final st = entry.key;
                            final label = entry.value;
                            final color = _statusColors[st] ?? const Color(0xFF6366F1);
                            final icon = _statusIcons[st] ?? Icons.circle;
                            return PopupMenuItem(
                              value: st,
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 16),
                                  const SizedBox(width: 10),
                                  Text(label, style: TextStyle(fontWeight: currentStatus == st ? FontWeight.bold : FontWeight.normal)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _applyToJob(job),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text("Apply Now", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: platformColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          _tabController.animateTo(1);
                          _jdController.text = description.length > 30 ? description : title;
                          _calculateJdMatch();
                        },
                        icon: const Icon(Icons.analytics_rounded, size: 15),
                        label: const Text("View Job Match", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildPlatformSearchChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_outward_rounded, size: 13, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlatformChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(width: 3),
            Icon(Icons.open_in_new_rounded, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}

