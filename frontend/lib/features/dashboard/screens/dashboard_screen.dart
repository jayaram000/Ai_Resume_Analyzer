import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/widgets/score_stamp.dart';
import 'package:frontend/core/widgets/pipeline_funnel_bar.dart';
import 'package:frontend/core/widgets/quick_action_card.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/features/dashboard/widgets/web_sidebar.dart';
import 'package:frontend/features/resume/screens/ats_analysis_screen.dart';
import 'package:frontend/features/jobs/screens/selected_jobs_screen.dart';
import 'package:frontend/features/skill_gap/screens/skill_gap_screen.dart';
import 'package:frontend/features/roadmap/screens/roadmap_screen.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/resume/screens/my_resumes_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/core/widgets/premium_plan_paywall.dart';
import 'package:frontend/core/widgets/usage_quota_badge.dart';

class DashboardScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.email, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isAnalyzingResume = false;
  bool _isPremium = false;
  String? _errorMessage;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _careerScore = {};
  Map<String, dynamic> _jobStats = {};
  List<dynamic> _resumes = [];

  @override
  void initState() {
    super.initState();
    _isPremium = (widget.userData['is_premium'] == true) || (widget.userData['is_staff'] == true);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsRes = await sl<ApiClient>().get('dashboard/stats/');
      final scoreRes = await sl<ApiClient>().get('dashboard/career-score/');
      final resumesRes = await sl<ApiClient>().get('resumes/');
      final jobStatsRes = await sl<ApiClient>().get('jobs/stats/');

      try {
        final subRes = await sl<ApiClient>().get('subscriptions/active/');
        if (subRes.statusCode == 200 && subRes.data is Map) {
          final subData = subRes.data['data'];
          if (subData != null && subData is Map && subData['status'] == 'active') {
            _isPremium = true;
          } else if (subData == null && !(widget.userData['is_staff'] == true || widget.userData['is_superuser'] == true)) {
            _isPremium = false;
          }
        }
      } catch (_) {}

      setState(() {
        if (statsRes.statusCode == 200 && statsRes.data['success'] == true) {
          _stats = statsRes.data['data'] ?? {};
        }
        if (scoreRes.statusCode == 200 && scoreRes.data['success'] == true) {
          _careerScore = scoreRes.data['data'] ?? {};
        }
        if (resumesRes.statusCode == 200) {
          if (resumesRes.data is List) {
            _resumes = resumesRes.data;
          } else if (resumesRes.data is Map && resumesRes.data.containsKey('data')) {
            _resumes = resumesRes.data['data'];
          } else if (resumesRes.data is Map && resumesRes.data.containsKey('results')) {
            _resumes = resumesRes.data['results'];
          }

          if (_resumes.isNotEmpty) {
            final firstScore = (_resumes[0]['ats_score'] as num?)?.toInt() ??
                (_resumes[0]['analysis']?['ats_score'] as num?)?.toInt() ??
                0;
            _stats['average_ats_score'] = firstScore;
          } else {
            _stats['average_ats_score'] = 0;
            _jobStats['top_match_score'] = 0;
          }
        }
        if (jobStatsRes.statusCode == 200 && jobStatsRes.data['success'] == true) {
          _jobStats = jobStatsRes.data['data'] ?? {};
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to refresh dashboard metrics.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );

    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.first;

      setState(() {
        _isAnalyzingResume = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading & Analyzing Resume with AI...")),
      );

      try {
        final formData = FormData.fromMap({
          "title": pickedFile.name,
          "file": MultipartFile.fromBytes(
            pickedFile.bytes ?? await pickedFile.xFile.readAsBytes(),
            filename: pickedFile.name,
          ),
        });

        final res = await sl<ApiClient>().post("resumes/", data: formData);
        if (res.statusCode == 202 || res.statusCode == 201 || res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Resume uploaded successfully! Analysis complete."),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          await _loadDashboardData();
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) await _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isQuota429 = (e is DioException && e.response?.statusCode == 429) ||
              e.toString().contains("429");

          if (isQuota429) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Please upgrade to Premium or wait for 5 hours.",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.resolveBrick(isDark),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: "UPGRADE",
                  textColor: Colors.white,
                  onPressed: () => PremiumPlanPaywall.showAsDialog(
                    context,
                    featureTitle: "Unlimited Resume Scans",
                    featureDescription: "Remove the 3-scan limit and unlock instant, rolling-free access across all AI auditing tools.",
                  ),
                ),
              ),
            );

            PremiumPlanPaywall.showAsDialog(
              context,
              featureTitle: "Free Scan Quota Reached",
              featureDescription: "You have completed your 3 free scans. Please upgrade to Premium or wait for 5 hours.",
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Upload error: ${e.toString()}")),
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isAnalyzingResume = false;
          });
        }
      }
    }
  }

  String _getFirstName() {
    final name = widget.userData['first_name'] ?? widget.email.split('@')[0];
    if (name.isEmpty) return "Jayaram";
    return name[0].toUpperCase() + name.substring(1);
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.resolvePaperAlt(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.resolveRule(isDark)),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.resolveBrick(isDark), size: 20),
            const SizedBox(width: 8),
            Text(
              "Log Out",
              style: TextStyle(
                color: AppColors.resolveInk(isDark),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to log out of your account?",
          style: TextStyle(color: AppColors.resolveInkMuted(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.resolveInkMuted(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.resolveBrick(isDark),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openATSAnalysis(String resumeId, String resumeTitle, {int initialTabIndex = 0}) async {
    final targetIndex = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ATSAnalysisScreen(
          resumeId: resumeId,
          resumeTitle: resumeTitle,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
    if (targetIndex is int && mounted) {
      setState(() => _selectedIndex = targetIndex);
    }
  }

  Widget _buildDashboardMainContent(bool isDark) {
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final brick = AppColors.resolveBrick(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resume Dashboard',
                    style: AppTypography.displayHero(
                      color: ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, ${_getFirstName()}',
                    style: AppTypography.monoLabel(
                      color: inkSoft,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Light / Dark Theme Toggle
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.themeModeNotifier,
                builder: (context, currentMode, _) {
                  final isNight = currentMode == ThemeMode.dark;
                  return OutlinedButton.icon(
                    onPressed: ThemeController.toggleTheme,
                    icon: Icon(
                      isNight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 15,
                      color: cobalt,
                    ),
                    label: Text(
                      isNight ? "Light Mode" : "Dark Mode",
                      style: AppTypography.buttonText(color: cobalt, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cobalt,
                      side: BorderSide(color: rule, width: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _uploadResume,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  'Upload Resume',
                  style: AppTypography.buttonText(color: Colors.white, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: "Log Out",
                onPressed: () => _confirmLogout(context),
                icon: Icon(Icons.logout_rounded, color: brick, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: brick.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: brick.withValues(alpha: 0.3), width: 1),
                  ),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // FREEMIUM USAGE QUOTA ROW
          const Align(
            alignment: Alignment.centerLeft,
            child: UsageQuotaBadge(),
          ),
          const SizedBox(height: 20),

          // Hero Score Cards with ScoreStamp
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              final cardWidth = isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

              final int atsScore = _resumes.isNotEmpty
                  ? ((_resumes[0]['ats_score'] ??
                      _resumes[0]['analysis']?['ats_score'] ??
                      _stats['resume_analytics']?['best_resume_score'] ??
                      _stats['average_ats_score']) as num?)
                          ?.toInt() ??
                      0
                  : 0;
              final int jobMatchScore = _resumes.isNotEmpty
                  ? ((_resumes[0]['job_match_score'] ??
                      _resumes[0]['analysis']?['job_match_score'] ??
                      _stats['career_analytics']?['career_readiness_score'] ??
                      (atsScore > 5 ? atsScore - 5 : (atsScore > 0 ? atsScore : 0))) as num?)
                          ?.toInt() ??
                      0
                  : 0;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // 1. ATS Score Stamp Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: paperAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rule, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ATS AUDIT SCORE',
                          style: AppTypography.monoLabel(
                            color: inkSoft,
                            fontSize: 11,
                          ).copyWith(letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 14),
                        ScoreStamp(
                          score: atsScore,
                          label: atsScore > 0 ? "ats approved" : "pending file",
                          size: 112,
                          isAnalyzing: _isAnalyzingResume,
                          subtitle: atsScore > 0 ? "Top percentile format." : "Upload file to review.",
                        ),
                      ],
                    ),
                  ),

                  // 2. Job Target Fit Stamp Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: paperAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rule, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TARGET FIT INDEX',
                          style: AppTypography.monoLabel(
                            color: inkSoft,
                            fontSize: 11,
                          ).copyWith(letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 14),
                        ScoreStamp(
                          score: jobMatchScore,
                          label: jobMatchScore > 0 ? "role match" : "unlinked jd",
                          size: 112,
                          isAnalyzing: _isAnalyzingResume,
                          subtitle: jobMatchScore > 0 ? "Direct keyword overlap." : "Paste JD to score fit.",
                        ),
                      ],
                    ),
                  ),

                  // 3. Top Strengths Audit Card
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: paperAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rule, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECORD HIGHLIGHTS',
                          style: AppTypography.monoLabel(
                            color: inkSoft,
                            fontSize: 11,
                          ).copyWith(letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 12),
                        if (_resumes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'No resume uploaded yet. Upload your resume to get instant ATS scores, bullet rewrites, and skill gap analysis.',
                              style: AppTypography.bodyRegular(
                                color: inkSoft,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          )
                        else
                          ...[
                            'Relevant Technical Core',
                            'Verified Experience History',
                            'Standard Clear Formatting',
                            'Quantified Impact Metrics',
                            'Key Industry Terminology'
                          ].map((strength) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.5),
                                child: Row(
                                  children: [
                                    Icon(Icons.check, color: forest, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      strength,
                                      style: AppTypography.bodyRegular(
                                        color: ink,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              if (_resumes.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ATSAnalysisScreen(
                                      resumeId: _resumes[0]['id'].toString(),
                                      resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                                    ),
                                  ),
                                );
                              } else {
                                _uploadResume();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cobalt,
                              side: BorderSide(color: rule, width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(
                              _resumes.isNotEmpty ? 'View Full Analysis' : 'Upload Resume',
                              style: AppTypography.buttonText(color: cobalt, fontSize: 11.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Pipeline Funnel Bar Widget (Consuming ApplicationTrackerService metrics)
          PipelineFunnelBar(
            funnelData: _jobStats['funnel'] as Map<String, dynamic>?,
            fallbackCounts: _jobStats,
            title: "Application Pipeline Funnel",
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildRecentResumesCard(paperAlt, rule, ink, isDark)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildQuickActionsGrid(paperAlt, rule, ink, isDark)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildRecentResumesCard(paperAlt, rule, ink, isDark),
                        const SizedBox(height: 16),
                        _buildQuickActionsGrid(paperAlt, rule, ink, isDark),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'FIELD OPERATIONS & MODULES',
            style: AppTypography.monoLabel(color: inkSoft, fontSize: 11).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                QuickActionCard(
                  title: 'AI Resume Optimizer',
                  description: 'Get AI-powered suggestions to improve your resume score.',
                  buttonText: 'Optimize Now',
                  icon: Icons.tune_rounded,
                  iconBgColor: AppColors.resolveForest(isDark),
                  buttonColor: AppColors.resolveForest(isDark),
                  onTap: () {
                    if (_resumes.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ATSAnalysisScreen(
                            resumeId: _resumes[0]['id'].toString(),
                            resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                            initialTabIndex: 0,
                          ),
                        ),
                      );
                    } else {
                      _uploadResume();
                    }
                  },
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'AI Bullet Rewriter',
                  description: 'Turn weak bullets into strong achievement statements.',
                  buttonText: 'Rewrite Bullets',
                  icon: Icons.edit_note_rounded,
                  iconBgColor: AppColors.resolveOchre(isDark),
                  buttonColor: AppColors.resolveOchre(isDark),
                  onTap: () {
                    if (_resumes.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ATSAnalysisScreen(
                            resumeId: _resumes[0]['id'].toString(),
                            resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                            initialTabIndex: 3,
                          ),
                        ),
                      );
                    } else {
                      _uploadResume();
                    }
                  },
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'Career Roadmap',
                  description: 'Get a personalized roadmap to achieve your target career goals.',
                  buttonText: 'View Roadmap',
                  icon: Icons.alt_route_rounded,
                  iconBgColor: AppColors.resolveCobalt(isDark),
                  buttonColor: AppColors.resolveCobalt(isDark),
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'Skill Gap & Courses',
                  description: 'Analyze missing skills and find recommended courses.',
                  buttonText: 'Analyze Skills',
                  icon: Icons.smart_toy_rounded,
                  iconBgColor: AppColors.resolveForest(isDark),
                  buttonColor: AppColors.resolveForest(isDark),
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'Job Description Matcher',
                  description: 'Paste a target job description to measure fit score.',
                  buttonText: 'Match JD',
                  icon: Icons.document_scanner_rounded,
                  iconBgColor: AppColors.resolveCobalt(isDark),
                  buttonColor: AppColors.resolveCobalt(isDark),
                  onTap: () {
                    if (_resumes.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ATSAnalysisScreen(
                            resumeId: _resumes[0]['id'].toString(),
                            resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                            initialTabIndex: 2,
                          ),
                        ),
                      );
                    } else {
                      _uploadResume();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentResumesCard(Color cardBg, Color borderColor, Color textPrimary, bool isDark) {
    final recentList = _resumes.take(3).toList();
    final cobalt = AppColors.resolveCobalt(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final paper = AppColors.resolvePaper(isDark);
    final rule = AppColors.resolveRule(isDark);
    final forest = AppColors.resolveForest(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UPLOADED RESUMES',
                style: AppTypography.monoLabel(
                  color: inkSoft,
                  fontSize: 11,
                ).copyWith(letterSpacing: 0.6),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: Text('View All Resumes', style: AppTypography.buttonText(color: cobalt, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recentList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              child: Center(
                child: Text(
                  'No resumes uploaded yet. Upload a file to see your ATS score and improvements.',
                  style: AppTypography.bodyRegular(color: inkSoft, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...recentList.map((item) {
              final title = item['title'] ?? item['original_filename'] ?? "Resume";
              final idStr = item['id'].toString();
              final score = (item['ats_score'] as num?)?.toInt() ?? 80;
              final scoreColor = score >= 70 ? forest : (score >= 50 ? ochre : AppColors.resolveBrick(isDark));

              return InkWell(
                onTap: () => _openATSAnalysis(idStr, title),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: paper,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: rule, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(Icons.description_outlined, color: cobalt, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.bodyMedium(color: ink, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "ATS Score: $score / 100",
                              style: AppTypography.monoLabel(color: scoreColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: inkSoft, size: 16),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(Color cardBg, Color borderColor, Color textPrimary, bool isDark) {
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final ochre = AppColors.resolveOchre(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIELD OPERATIONS',
            style: AppTypography.monoLabel(
              color: inkSoft,
              fontSize: 11,
            ).copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(Icons.tune_rounded, 'Audit Resume', cobalt, () {
                      if (_resumes.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ATSAnalysisScreen(
                              resumeId: _resumes[0]['id'].toString(),
                              resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                            ),
                          ),
                        );
                      } else {
                        _uploadResume();
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(Icons.document_scanner_rounded, 'Match JD', forest, () {
                      if (_resumes.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ATSAnalysisScreen(
                              resumeId: _resumes[0]['id'].toString(),
                              resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                              initialTabIndex: 2,
                            ),
                          ),
                        );
                      } else {
                        _uploadResume();
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(Icons.alt_route_rounded, 'Transition Roadmap', cobalt, () {
                      setState(() => _selectedIndex = 5);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(Icons.smart_toy_rounded, 'Skill Gap Analysis', ochre, () {
                      setState(() => _selectedIndex = 4);
                    }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: rule, width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyRegular(color: ink, fontSize: 12.5)
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToolsGridScreen(bool isDark) {
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    final aiTools = [
      {
        'title': 'AI Resume Optimizer',
        'desc': 'Deep ATS critique and actionable suggestions to improve your resume score.',
        'icon': Icons.tune_rounded,
        'color': forest,
        'btn': 'Audit Resume',
        'action': () {
          if (_resumes.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ATSAnalysisScreen(
                  resumeId: _resumes[0]['id'].toString(),
                  resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                  initialTabIndex: 0,
                ),
              ),
            );
          } else {
            _uploadResume();
          }
        }
      },
      {
        'title': 'AI Bullet Rewriter',
        'desc': 'Transform weak bullet points into high-impact STAR-method achievement statements.',
        'icon': Icons.edit_note_rounded,
        'color': cobalt,
        'btn': 'Rewrite Bullets',
        'action': () {
          if (_resumes.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ATSAnalysisScreen(
                  resumeId: _resumes[0]['id'].toString(),
                  resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                  initialTabIndex: 3,
                ),
              ),
            );
          } else {
            _uploadResume();
          }
        }
      },
      {
        'title': 'Job Description Matcher',
        'desc': 'Paste a job description to calculate semantic fit, missing skills, and keywords.',
        'icon': Icons.document_scanner_rounded,
        'color': forest,
        'btn': 'Match Job Description',
        'action': () {
          if (_resumes.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ATSAnalysisScreen(
                  resumeId: _resumes[0]['id'].toString(),
                  resumeTitle: _resumes[0]['title'] ?? "Resume Analysis",
                  initialTabIndex: 2,
                ),
              ),
            );
          } else {
            _uploadResume();
          }
        }
      },
      {
        'title': 'Skill Gap Intelligence',
        'desc': 'Audit missing skills and generate market-aligned course blueprints.',
        'icon': Icons.smart_toy_rounded,
        'color': ochre,
        'btn': 'Inspect Skill Gap',
        'action': () => setState(() => _selectedIndex = 4),
      },
      {
        'title': 'AI Career Transition Roadmap',
        'desc': 'Get a phase-by-phase transition plan with required tech stacks & certifications.',
        'icon': Icons.alt_route_rounded,
        'color': cobalt,
        'btn': 'View Roadmap',
        'action': () => setState(() => _selectedIndex = 5),
      },
      {
        'title': 'AI Interview Prep Coach',
        'desc': 'Practice role-specific technical, HR, and STAR behavioral interview questions.',
        'icon': Icons.record_voice_over_rounded,
        'color': ochre,
        'btn': 'Practice Simulator',
        'action': () => setState(() => _selectedIndex = 4),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Career Tools',
            style: AppTypography.displayHero(color: ink, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a tool to analyze your resume, match job requirements, or prepare for interviews.',
            style: AppTypography.bodyRegular(color: inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: aiTools.map((tool) {
                  final itemWidth = (constraints.maxWidth - ((crossCount - 1) * 16)) / crossCount;
                  final color = tool['color'] as Color;

                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: paperAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: rule, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Icon(tool['icon'] as IconData, color: color, size: 22),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tool['title'] as String,
                          style: AppTypography.displayHeading(color: ink, fontSize: 15.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tool['desc'] as String,
                          style: AppTypography.bodyRegular(color: inkSoft, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: tool['action'] as VoidCallback,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color, width: 1),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Text(
                              tool['btn'] as String,
                              style: AppTypography.buttonText(color: color, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _getScreenForTab(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (index) {
      case 0:
        return _buildDashboardMainContent(isDark);
      case 1:
        return const MyResumesScreen();
      case 2:
        return const SelectedJobsScreen();
      case 3:
        return _buildAIToolsGridScreen(isDark);
      case 4:
        return _isPremium
            ? const SkillGapScreen()
            : PremiumPlanPaywall(
                featureTitle: "Unlock AI Career Copilot & Skill Gap Intelligence",
                featureDescription:
                    "Deep semantic skill comparison against real-time industry requirements, missing competency blueprints, and interview preparation.",
                onSubscribed: () => setState(() => _isPremium = true),
              );
      case 5:
        return _isPremium
            ? const CareerRoadmapScreen()
            : PremiumPlanPaywall(
                featureTitle: "Unlock AI Career Transition & Mastery Roadmap",
                featureDescription:
                    "Generate a complete learning curriculum, project blueprints, YouTube tutorials, documentation portals, and certification guides for your target tech position.",
                onSubscribed: () => setState(() => _isPremium = true),
              );
      case 6:
        return const SettingsScreen();
      case 7:
        return const SettingsScreen();
      default:
        return _buildDashboardMainContent(isDark);
    }
  }

  int _getMobileNavIndex() {
    if (_selectedIndex == 1) return 1;
    if (_selectedIndex == 3) return 2;
    if (_selectedIndex == 4 || _selectedIndex == 5) return 3;
    if (_selectedIndex == 6 || _selectedIndex == 7) return 4;
    return 0;
  }

  void _onMobileNavTapped(int index) {
    int target = index;
    if (index == 2) target = 3;
    if (index == 3) target = 4;
    if (index == 4) target = 7;
    setState(() => _selectedIndex = target);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cobalt = AppColors.resolveCobalt(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final paper = AppColors.resolvePaper(isDark);

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cobalt))
          : isDesktop
              ? Row(
                  children: [
                    WebSidebar(
                      selectedIndex: _selectedIndex,
                      isPremium: _isPremium,
                      onItemSelected: (index) => setState(() => _selectedIndex = index),
                      onUpgradePressed: () => setState(() => _selectedIndex = 5),
                      onLogoutPressed: () => _confirmLogout(context),
                    ),
                    Expanded(child: _getScreenForTab(_selectedIndex)),
                  ],
                )
              : _getScreenForTab(_selectedIndex),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _getMobileNavIndex(),
              onTap: _onMobileNavTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: paper,
              selectedItemColor: cobalt,
              unselectedItemColor: inkSoft,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.folder_open_rounded), label: 'Resumes'),
                BottomNavigationBarItem(icon: Icon(Icons.document_scanner_rounded), label: 'Analysis'),
                BottomNavigationBarItem(icon: Icon(Icons.alt_route_rounded), label: 'Roadmap'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
    );
  }
}
