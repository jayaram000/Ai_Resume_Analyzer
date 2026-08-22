import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';

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
      setState(() {
        _errorMessage = "Failed to perform comparison. Verify database record.";
      });
    } finally {
      setState(() {
        _isComparing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Resume Version Intelligence", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoadingResumes
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection Header
                    Card(
                      color: const Color(0xCC1E293B),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Text(
                              "Select Resume Versions to Compare",
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedResumeId1,
                                    dropdownColor: const Color(0xFF1E293B),
                                    decoration: const InputDecoration(labelText: "Old version"),
                                    items: _resumes.map<DropdownMenuItem<String>>((res) {
                                      return DropdownMenuItem<String>(
                                        value: res['id'],
                                        child: Text("${res['title']} (v${res['version']})", overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() { _selectedResumeId1 = val; }),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedResumeId2,
                                    dropdownColor: const Color(0xFF1E293B),
                                    decoration: const InputDecoration(labelText: "New version"),
                                    items: _resumes.map<DropdownMenuItem<String>>((res) {
                                      return DropdownMenuItem<String>(
                                        value: res['id'],
                                        child: Text("${res['title']} (v${res['version']})", overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() { _selectedResumeId2 = val; }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _isComparing
                                ? const CircularProgressIndicator(color: Color(0xFF14B8A6))
                                : ElevatedButton.icon(
                                    onPressed: _selectedResumeId1 != null && _selectedResumeId2 != null ? _compareResumes : null,
                                    icon: const Icon(Icons.analytics_rounded),
                                    label: const Text("Compare Versions"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF14B8A6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Error block
                    if (_errorMessage != null)
                      Center(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      ),

                    // Results block
                    if (_comparisonData != null)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Score Compare Card
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildScoreDisplayCard("ATS Before", _comparisonData!['before_resume']['analysis_snapshot']['ats_score'], const Color(0xFFEF4444)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildScoreDisplayCard("ATS After", _comparisonData!['after_resume']['analysis_snapshot']['ats_score'], const Color(0xFF14B8A6)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildScoreDisplayCard("Health Before", _comparisonData!['before_resume']['analysis_snapshot']['health_score'], const Color(0xFFF59E0B)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildScoreDisplayCard("Health After", _comparisonData!['after_resume']['analysis_snapshot']['health_score'], const Color(0xFF3B82F6)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Score delta block
                              Card(
                                color: const Color(0xFF1E293B),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("ATS Score Progression Delta:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                      Text(
                                        "${_comparisonData!['ats_difference'] >= 0 ? '+' : ''}${_comparisonData!['ats_difference']} pts",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _comparisonData!['ats_difference'] >= 0 ? const Color(0xFF14B8A6) : Colors.redAccent,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Added & Removed Skills
                              const Text("Skill Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildSkillsProgressCard("Added Skills", _comparisonData!['added_skills'], const Color(0xFF14B8A6)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSkillsProgressCard("Removed Skills", _comparisonData!['removed_skills'], const Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Added & Removed Keywords
                              const Text("Keyword Additions", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildSkillsProgressCard("Added Keywords", _comparisonData!['added_keywords'], const Color(0xFF3B82F6)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildSkillsProgressCard("Removed Keywords", _comparisonData!['removed_keywords'], const Color(0xFFF59E0B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Visual Summary
                              const Text("AI Summary of Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Card(
                                color: const Color(0x661E293B),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    _comparisonData!['ai_summary'] ?? "No summary provided.",
                                    style: const TextStyle(color: Color(0xFFE2E8F0), height: 1.5, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (!_isComparing)
                      const Expanded(
                        child: Center(
                          child: Text(
                            "Select two versions and click Compare to see score changes and skill tracking.",
                            style: TextStyle(color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildScoreDisplayCard(String title, int score, Color scoreColor) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              "$score",
              style: TextStyle(color: scoreColor, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsProgressCard(String title, List<dynamic> skills, Color badgeColor) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            if (skills.isEmpty)
              const Text("None", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.map<Widget>((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      s.toString(),
                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              )
          ],
        ),
      ),
    );
  }
}
