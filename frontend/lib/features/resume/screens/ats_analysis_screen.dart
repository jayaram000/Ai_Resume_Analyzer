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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jdController.dispose();
    super.dispose();
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

      // 5. Matching jobs
      final jobsRes = await resumeRepo.getMatchingJobs(widget.resumeId);
      if (jobsRes.isSuccess && jobsRes.data != null) {
        _matchingJobs = jobsRes.data!;
      }
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

  void _showJobDetailModal(Map<String, dynamic> job) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.work_rounded, color: Color(0xFF6366F1), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? "Software Engineer",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          job['company_name'] ?? "TechCorp Solutions",
                          style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${job['match_score'] ?? 85}% Match",
                      style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text("Job Description & Requirements", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 8),
              Text(
                job['description'] ?? "We are seeking a software engineer with strong experience in Python, REST APIs, and modern frontend frameworks.",
                style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _tabController.animateTo(1);
                    _jdController.text = job['description'] ?? job['title'] ?? "";
                    _calculateJdMatch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Run Interactive Match Breakdown", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

                          // MATCHING JOB CARD PREVIEW
                          Text(
                            "Top Matching Role",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.business_center_rounded, color: Color(0xFF6366F1), size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _matchingJobs.isNotEmpty ? (_matchingJobs[0]['title'] ?? "Software Developer") : "Senior Full Stack Engineer",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                      ),
                                      Text(
                                        _matchingJobs.isNotEmpty ? (_matchingJobs[0]['company_name'] ?? "TechCorp Solutions") : "InnovateX Labs",
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        children: ["Python", "Django", "PostgreSQL", "REST APIs"]
                                            .map((tag) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(tag, style: const TextStyle(fontSize: 11)),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${_matchingJobs.isNotEmpty ? (_matchingJobs[0]['match_score'] ?? 85) : 85}% Match",
                                        style: const TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (_matchingJobs.isNotEmpty) {
                                          _showJobDetailModal(_matchingJobs[0]);
                                        } else {
                                          _showJobDetailModal({
                                            "title": "Senior Full Stack Engineer",
                                            "company_name": "InnovateX Labs",
                                            "description": "Designing high-throughput microservices, REST APIs, and modern Flutter & Django web apps.",
                                            "match_score": 85
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text("View Job Match", style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                                icon: const Icon(Icons.analytics_rounded, size: 18),
                                label: const Text("Run JD Match Analysis"),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _isTailorLoading ? null : _generateTailoredResume,
                                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                                label: const Text("Auto-Tailor Resume"),
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF14B8A6)),
                              ),
                            ],
                          ),
                          if (_jdErrorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(_jdErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                          ],
                          if (_jdMatchData != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  CircularScoreGauge(
                                    score: (_jdMatchData!['match_score'] as num?)?.toInt() ?? 75,
                                    size: 90,
                                    strokeWidth: 10,
                                    progressColor: const Color(0xFF22C55E),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Job Fit Score: ${(_jdMatchData!['match_score'] as num?)?.toInt() ?? 75}%",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                        ),
                                        Text(
                                          "Matched Skills: ${((_jdMatchData!['matched_skills'] as List?) ?? []).join(', ')}",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF22C55E)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Missing Skills: ${((_jdMatchData!['missing_skills'] as List?) ?? []).join(', ')}",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                                        ),
                                      ],
                                    ),
                                  ),
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
}
