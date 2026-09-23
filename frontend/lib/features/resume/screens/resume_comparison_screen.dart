import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/theme/app_colors.dart';

class ResumeComparisonScreen extends StatefulWidget {
  const ResumeComparisonScreen({super.key});

  @override
  State<ResumeComparisonScreen> createState() => _ResumeComparisonScreenState();
}

class _ResumeComparisonScreenState extends State<ResumeComparisonScreen> {
  List<dynamic> _resumes = [];
  String? _selectedResumeId1;
  String? _selectedResumeId2;
  bool _isLoadingResumes = true;
  bool _isComparing = false;
  Map<String, dynamic>? _comparisonData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  Future<void> _loadResumes() async {
    try {
      final response = await sl<ApiClient>().get('resumes/');
      List<dynamic> resumesList = [];
      if (response.statusCode == 200) {
        if (response.data is List) {
          resumesList = response.data;
        } else if (response.data is Map && response.data.containsKey('data')) {
          resumesList = response.data['data'];
        } else if (response.data is Map && response.data.containsKey('results')) {
          resumesList = response.data['results'];
        }
      }
      setState(() {
        _resumes = resumesList;
        if (_resumes.length >= 2) {
          _selectedResumeId1 = _resumes[0]['id'];
          _selectedResumeId2 = _resumes[1]['id'];
        }
        _isLoadingResumes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load resumes for selection.";
        _isLoadingResumes = false;
      });
    }
  }

  Future<void> _compareResumes() async {
    if (_selectedResumeId1 == null || _selectedResumeId2 == null) return;
    setState(() {
      _isComparing = true;
      _comparisonData = null;
      _errorMessage = null;
    });

    try {
      final response = await sl<ApiClient>().post('resumes/compare/', data: {
        'before_resume_id': _selectedResumeId1,
        'after_resume_id': _selectedResumeId2,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _comparisonData = response.data['data'];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? "Comparison failed.";
        });
      }
    } catch (e) {
      String msg = "Failed to perform comparison. Verify database record.";
      try {
        final dynamic err = e;
        if (err?.response?.data != null) {
          final data = err.response.data;
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        }
      } catch (_) {}
      setState(() {
        _errorMessage = msg;
      });
    } finally {
      setState(() {
        _isComparing = false;
      });
    }
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
    final brick = AppColors.resolveBrick(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        title: Text(
          "VERSION INTELLIGENCE // DIFF AUDIT",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: ink,
          ),
        ),
        backgroundColor: paperAlt,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: rule)),
        iconTheme: IconThemeData(color: ink),
      ),
      body: _isLoadingResumes
          ? Center(child: CircularProgressIndicator(color: cobalt))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection Header
                  Container(
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
                          children: [
                            Icon(Icons.compare_arrows_rounded, size: 18, color: cobalt),
                            const SizedBox(width: 8),
                            Text(
                              "SELECT RESUME DOSSIERS FOR COMPARATIVE AUDIT",
                              style: TextStyle(
                                color: ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedResumeId1,
                                dropdownColor: paperAlt,
                                style: TextStyle(color: ink, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "ORIGINAL / BASE VERSION",
                                  labelStyle: TextStyle(color: inkSoft, fontSize: 11),
                                ),
                                items: _resumes.map<DropdownMenuItem<String>>((res) {
                                  return DropdownMenuItem<String>(
                                    value: res['id'].toString(),
                                    child: Text(
                                      "${res['title']} (v${res['version']})",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: ink),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() { _selectedResumeId1 = val; }),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedResumeId2,
                                dropdownColor: paperAlt,
                                style: TextStyle(color: ink, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: "REVISED / TARGET VERSION",
                                  labelStyle: TextStyle(color: inkSoft, fontSize: 11),
                                ),
                                items: _resumes.map<DropdownMenuItem<String>>((res) {
                                  return DropdownMenuItem<String>(
                                    value: res['id'].toString(),
                                    child: Text(
                                      "${res['title']} (v${res['version']})",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: ink),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() { _selectedResumeId2 = val; }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isComparing
                            ? Center(child: CircularProgressIndicator(color: cobalt))
                            : SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton.icon(
                                  onPressed: _selectedResumeId1 != null && _selectedResumeId2 != null ? _compareResumes : null,
                                  icon: const Icon(Icons.analytics_outlined, size: 18),
                                  label: const Text(
                                    "EXECUTE COMPARISON AUDIT",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cobalt,
                                    foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error block
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brick.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: brick.withValues(alpha: 0.3)),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: brick, fontSize: 13)),
                    ),

                  // Results block
                  if (_comparisonData != null) ...[
                    // Score Compare Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildScoreDisplayCard("ATS SCORE (BEFORE)", _comparisonData!['before_resume']['analysis_snapshot']['ats_score'], brick, paperAlt, rule, inkSoft),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildScoreDisplayCard("ATS SCORE (AFTER)", _comparisonData!['after_resume']['analysis_snapshot']['ats_score'], forest, paperAlt, rule, inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildScoreDisplayCard("HEALTH (BEFORE)", _comparisonData!['before_resume']['analysis_snapshot']['health_score'], ochre, paperAlt, rule, inkSoft),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildScoreDisplayCard("HEALTH (AFTER)", _comparisonData!['after_resume']['analysis_snapshot']['health_score'], cobalt, paperAlt, rule, inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Score delta block
                    Container(
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ATS SCORE PROGRESSION DELTA",
                            style: TextStyle(color: inkSoft, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          Text(
                            "${_comparisonData!['ats_difference'] >= 0 ? '+' : ''}${_comparisonData!['ats_difference']} PTS",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _comparisonData!['ats_difference'] >= 0 ? forest : brick,
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Added & Removed Skills
                    Text("SKILL DELTAS", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSkillsProgressCard("ADDED SKILLS", _comparisonData!['added_skills'], forest, paperAlt, rule, inkSoft),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSkillsProgressCard("REMOVED SKILLS", _comparisonData!['removed_skills'], brick, paperAlt, rule, inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Added & Removed Keywords
                    Text("KEYWORD DELTAS", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSkillsProgressCard("ADDED KEYWORDS", _comparisonData!['added_keywords'], cobalt, paperAlt, rule, inkSoft),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSkillsProgressCard("REMOVED KEYWORDS", _comparisonData!['removed_keywords'], ochre, paperAlt, rule, inkSoft),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Visual Summary
                    Text("AI ANALYSIS & PROGRESSION AUDIT", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      padding: const EdgeInsets.all(18.0),
                      child: Text(
                        _comparisonData!['ai_summary'] ?? "No summary provided.",
                        style: TextStyle(color: ink, height: 1.5, fontSize: 13),
                      ),
                    ),
                  ] else if (!_isComparing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      child: Center(
                        child: Text(
                          "Select two versions and execute comparison to audit score diffs and keyword adjustments.",
                          style: TextStyle(color: inkSoft, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildScoreDisplayCard(String title, dynamic score, Color scoreColor, Color cardBg, Color rule, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(
            "$score",
            style: TextStyle(color: scoreColor, fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsProgressCard(String title, List<dynamic> skills, Color badgeColor, Color cardBg, Color rule, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            Text("None recorded", style: TextStyle(color: textMuted, fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills.map<Widget>((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    s.toString(),
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            )
        ],
      ),
    );
  }
}
