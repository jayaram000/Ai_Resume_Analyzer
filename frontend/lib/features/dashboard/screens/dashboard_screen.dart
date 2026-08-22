import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/widgets/circular_score_gauge.dart';
import 'package:frontend/core/widgets/quick_action_card.dart';
import 'package:frontend/features/dashboard/widgets/web_sidebar.dart';
import 'package:frontend/features/resume/screens/ats_analysis_screen.dart';
import 'package:frontend/features/jobs/screens/job_finder_screen.dart';
import 'package:frontend/features/skill_gap/screens/skill_gap_screen.dart';
import 'package:frontend/features/roadmap/screens/roadmap_screen.dart';
import 'package:frontend/features/settings/screens/settings_screen.dart';
import 'package:frontend/features/resume/screens/my_resumes_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';

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
  String? _errorMessage;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _careerScore = {};
  Map<String, dynamic> _jobStats = {};
  List<dynamic> _resumes = [];

  @override
  void initState() {
    super.initState();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: ${e.toString()}")),
        );
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

  Widget _buildDashboardMainContent(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, ${_getFirstName()} 👋',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _uploadResume,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload New Resume'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your ATS Score',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 16),
                        CircularScoreGauge(
                          score: atsScore,
                          size: 130,
                          strokeWidth: 12,
                          isAnalyzing: _isAnalyzingResume,
                          progressColor: atsScore >= 80
                              ? const Color(0xFF22C55E)
                              : (atsScore >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                          statusText: atsScore > 0 ? (atsScore >= 80 ? 'Great Score!' : 'Good Match') : 'No Resume',
                          statusTextColor: atsScore > 0 ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                          label: atsScore > 0 ? "Top percentile format." : "Upload resume to score.",
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Job Match Score',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 16),
                        CircularScoreGauge(
                          score: jobMatchScore,
                          size: 130,
                          strokeWidth: 12,
                          isAnalyzing: _isAnalyzingResume,
                          progressColor: const Color(0xFF22C55E),
                          statusText: jobMatchScore > 0 ? 'Target Fit' : 'No Target JD',
                          statusTextColor: jobMatchScore > 0 ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                          label: jobMatchScore > 0 ? 'Match against JD.' : 'Paste JD to score fit.',
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: cardWidth,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Strengths',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 12),
                        if (_resumes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'No resume analysis available yet. Upload a resume to automatically extract your top strengths and metrics.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          )
                        else
                          ...[
                            'Relevant Technical Skills',
                            'Verified Experience',
                            'Structured Education',
                            'Clean Standard Formatting',
                            'Quantified Achievements'
                          ].map((strength) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      strength,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
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
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(_resumes.isNotEmpty ? 'View Full Analysis' : 'Upload Resume', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildRecentResumesCard(cardBg, borderColor, textPrimary, isDark)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildQuickActionsGrid(cardBg, borderColor, textPrimary, isDark)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildRecentResumesCard(cardBg, borderColor, textPrimary, isDark),
                        const SizedBox(height: 16),
                        _buildQuickActionsGrid(cardBg, borderColor, textPrimary, isDark),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'AI Tools & Feature Hub',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
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
                  iconBgColor: const Color(0xFF22C55E),
                  buttonColor: const Color(0xFF22C55E),
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
                  iconBgColor: const Color(0xFF8B5CF6),
                  buttonColor: const Color(0xFF8B5CF6),
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
                  iconBgColor: const Color(0xFF14B8A6),
                  buttonColor: const Color(0xFF14B8A6),
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'Skill Gap & Courses',
                  description: 'Analyze missing skills and find recommended courses.',
                  buttonText: 'Analyze Skills',
                  icon: Icons.smart_toy_rounded,
                  iconBgColor: const Color(0xFF3B82F6),
                  buttonColor: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                const SizedBox(width: 12),
                QuickActionCard(
                  title: 'Job Description Matcher',
                  description: 'Paste a target job description to measure fit score.',
                  buttonText: 'Match JD',
                  icon: Icons.document_scanner_rounded,
                  iconBgColor: const Color(0xFF6366F1),
                  buttonColor: const Color(0xFF6366F1),
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

    return Container(
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
                'Recent Resumes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('View All', style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              child: const Center(
                child: Text(
                  'No resumes uploaded yet. Click Upload to get started.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...recentList.map((item) {
              final title = item['title'] ?? item['original_filename'] ?? "Resume";
              final idStr = item['id'].toString();
              final score = (item['ats_score'] as num?)?.toInt() ?? 80;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ATSAnalysisScreen(
                        resumeId: idStr,
                        resumeTitle: title,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description_rounded, color: Color(0xFF6366F1), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "ATS Score: $score / 100",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(Icons.tune_rounded, 'Optimize Resume', const Color(0xFF6366F1), () {
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
                    child: _buildActionTile(Icons.document_scanner_rounded, 'Scan JD', const Color(0xFF14B8A6), () {
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
                    child: _buildActionTile(Icons.alt_route_rounded, 'Career Roadmap', const Color(0xFF8B5CF6), () {
                      setState(() => _selectedIndex = 5);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionTile(Icons.smart_toy_rounded, 'Skill Gap & Courses', const Color(0xFFF59E0B), () {
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final aiTools = [
      {
        'title': 'AI Resume Optimizer',
        'desc': 'Deep ATS critique and actionable suggestions to improve your resume score.',
        'icon': Icons.tune_rounded,
        'color': const Color(0xFF22C55E),
        'btn': 'Optimize Resume',
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
        'color': const Color(0xFF8B5CF6),
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
        'title': 'AI Cover Letter Generator',
        'desc': 'Generate tailored, persuasive cover letters matching any job description.',
        'icon': Icons.email_rounded,
        'color': const Color(0xFF3B82F6),
        'btn': 'Generate Letter',
        'action': () => setState(() => _selectedIndex = 4),
      },
      {
        'title': 'AI Interview Prep Coach',
        'desc': 'Practice role-specific technical, HR, and STAR behavioral interview questions.',
        'icon': Icons.record_voice_over_rounded,
        'color': const Color(0xFFF59E0B),
        'btn': 'Start Practice',
        'action': () => setState(() => _selectedIndex = 4),
      },
      {
        'title': 'AI Career Roadmap',
        'desc': 'Get a phase-by-phase transition plan with required tech stacks & certifications.',
        'icon': Icons.alt_route_rounded,
        'color': const Color(0xFF14B8A6),
        'btn': 'View Roadmap',
        'action': () => setState(() => _selectedIndex = 5),
      },
      {
        'title': 'Job Description Matcher',
        'desc': 'Paste a job description to calculate semantic fit, missing skills, and keywords.',
        'icon': Icons.document_scanner_rounded,
        'color': const Color(0xFF6366F1),
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
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Tools & Feature Hub',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select an AI feature to analyze, rewrite, or accelerate your career.',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(tool['icon'] as IconData, color: color, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tool['title'] as String,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tool['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: tool['action'] as VoidCallback,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              tool['btn'] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        return const JobFinderScreen();
      case 3:
        return _buildAIToolsGridScreen(isDark);
      case 4:
        return const SkillGapScreen();
      case 5:
        return const CareerRoadmapScreen();
      case 6:
        return const SettingsScreen();
      case 7:
        return const SettingsScreen();
      default:
        return _buildDashboardMainContent(isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : isDesktop
              ? Row(
                  children: [
                    WebSidebar(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) => setState(() => _selectedIndex = index),
                      onUpgradePressed: () {},
                    ),
                    Expanded(child: _getScreenForTab(_selectedIndex)),
                  ],
                )
              : _getScreenForTab(_selectedIndex),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF6366F1),
              unselectedItemColor: const Color(0xFF94A3B8),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.description_rounded), label: 'Resumes'),
                BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'AI Tools'),
                BottomNavigationBarItem(icon: Icon(Icons.smart_toy_rounded), label: 'Copilot'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
    );
  }
}
