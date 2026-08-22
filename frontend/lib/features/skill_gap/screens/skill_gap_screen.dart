import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/utils/file_downloader.dart';
import 'package:frontend/features/skill_gap/domain/entities/skill_gap_entities.dart';
import 'package:frontend/features/skill_gap/domain/repositories/skill_gap_repository.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

class SkillGapScreen extends StatefulWidget {
  const SkillGapScreen({super.key});

  @override
  State<SkillGapScreen> createState() => _SkillGapScreenState();
}

class _SkillGapScreenState extends State<SkillGapScreen> {
  final _roleController = TextEditingController(text: "Java Developer");
  String _experienceLevel = "Architect";
  final List<String> _experienceOptions = ["Fresher", "Junior", "Mid-Level", "Senior", "Lead", "Architect"];

  bool _isLoading = false;
  SkillGapEntity? _gapData;
  String? _errorMessage;

  List<SkillGapEntity> _recentGaps = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadRecentHistory();
  }

  Future<void> _loadRecentHistory() async {
    setState(() => _isLoadingHistory = true);
    final res = await sl<SkillGapRepository>().getRecentSkillGaps();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (res.isSuccess && res.data != null) {
          _recentGaps = res.data!;
        }
      });
    }
  }

  Future<void> _deleteHistoryItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Report", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this skill gap report?", style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await sl<SkillGapRepository>().deleteSkillGap(id);
      if (_gapData != null && _gapData!.id == id) {
        setState(() => _gapData = null);
      }
      _loadRecentHistory();
    }
  }

  Future<void> _analyzeSkillGap() async {
    final role = _roleController.text.trim();
    if (role.isEmpty) return;

    try {
      final res = await sl<ResumeRepository>().getMyResumes();
      if (res.isSuccess && res.data != null) {
        final resumes = res.data!;
        if (resumes.isEmpty) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text("Upload Resume Required", style: TextStyle(color: Colors.white)),
                content: const Text("Please upload a resume first to compare and find skill gaps.", style: TextStyle(color: Color(0xFF94A3B8))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK", style: TextStyle(color: Color(0xFF6366F1))),
                  ),
                ],
              ),
            );
          }
          return;
        } else if (resumes.length == 1) {
          _performAnalysis(resumes[0].id);
        } else {
          String selectedResumeId = resumes[0].id;
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) {
                return StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text("Select Resume for Comparison", style: TextStyle(color: Colors.white)),
                      content: DropdownButton<String>(
                        value: selectedResumeId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: resumes.map<DropdownMenuItem<String>>((r) {
                          return DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(r.title),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedResumeId = val);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel", style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _performAnalysis(selectedResumeId);
                          },
                          child: const Text("Analyze", style: TextStyle(color: Color(0xFF6366F1))),
                        ),
                      ],
                    );
                  }
                );
              },
            );
          }
        }
      }
    } catch (e) {
      _performAnalysis(null);
    }
  }

  Future<void> _performAnalysis(String? resumeId) async {
    final role = _roleController.text.trim();
    if (role.isEmpty) return;

    setState(() {
      _isLoading = true;
      _gapData = null;
      _errorMessage = null;
    });

    try {
      final res = await sl<SkillGapRepository>().analyzeSkillGap(
        targetRole: role,
        experience: _experienceLevel,
        resumeId: resumeId,
      );
      if (res.isSuccess && res.data != null) {
        setState(() {
          _gapData = res.data!;
        });
        _loadRecentHistory();
      } else {
        setState(() {
          _errorMessage = res.failure?.message ?? "Failed to perform Skill Gap analysis.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network or timeout issue. Please retry analysis.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_gapData == null || _gapData!.id == null) return;
    
    try {
      final fileName = 'Career_Roadmap_${_gapData!.targetRole.replaceAll(" ", "_")}.pdf';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating & downloading professional PDF...')),
        );
      }

      final apiClient = sl<ApiClient>();
      final response = await apiClient.get(
        'analysis/skill-gap/${_gapData!.id}/pdf/',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = (response.data is List<int>) ? (response.data as List<int>) : List<int>.from(response.data);
      final success = await FileDownloader.download(bytes, fileName);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✔ $fileName downloaded successfully!'), backgroundColor: const Color(0xFF22C55E)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save PDF file.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text("About Career Copilot", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🎯 What is Career Copilot?",
              style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              "Career Copilot performs a personalized diagnostic comparison between your actual uploaded resume and live market requirements for any target role and seniority level.",
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              "📊 What you get:",
              style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              "• Exact Match Score % (e.g. 72% Ready)\n• Matched Skills you already possess\n• Critical Missing Skills scraped from live job posts\n• Actionable Transition Roadmap & Milestones\n• Production Portfolio Projects to build\n• Exportable Executive PDF Report",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got It", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP TARGET ROLE INPUT CARD
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Advanced Skill Gap & Career Transition Intelligence",
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _showInfoDialog,
                        icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 20),
                        tooltip: "What is Career Copilot?",
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Compare your uploaded resume against real-world market demands for your target position & seniority level.",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _roleController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: "Enter target role (e.g. Java Developer, Backend Architect)",
                            prefixIcon: const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _experienceLevel,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
                            onChanged: (String? newValue) {
                              if (newValue != null) setState(() => _experienceLevel = newValue);
                            },
                            items: _experienceOptions.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF14B8A6)]),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _analyzeSkillGap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Analyze Match", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. SAVED / RECENT ANALYSES CAROUSEL / CHIPS
            if (_recentGaps.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Color(0xFF6366F1), size: 18),
                      const SizedBox(width: 8),
                      Text("Recent Skill Gap Reports (${_recentGaps.length})", style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_isLoadingHistory)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentGaps.length,
                  itemBuilder: (context, idx) {
                    final item = _recentGaps[idx];
                    final isSelected = _gapData?.id == item.id;
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _gapData = item;
                            _roleController.text = item.targetRole;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF6366F1) : borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${item.readinessScore}%",
                                  style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.targetRole,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  if (item.id != null) _deleteHistoryItem(item.id!);
                                },
                                child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ),

            // 3. MAIN RESULTS DISPLAY
            if (_gapData != null) ...[
              // A. EXECUTIVE READINESS & NARRATIVE SUMMARY CARD
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Match Score Circular Indicator
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF14B8A6)]),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${_gapData!.readinessScore}%",
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                                const Text("Match", style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Target: ${_gapData!.targetRole}",
                                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF6366F1)),
                                    ),
                                    child: Text(
                                      _experienceLevel,
                                      style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _gapData!.readinessLevel,
                                style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _gapData!.readinessSummary.isNotEmpty
                                    ? _gapData!.readinessSummary
                                    : "Comprehensive evaluation comparing your resume skills against industry requirements for ${_gapData!.targetRole}.",
                                style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                          label: const Text("Export PDF", style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // B. SKILLS COMPARISON: MATCHED VS MISSING
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Matched Skills (Green)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                              SizedBox(width: 8),
                              Text("Matched Skills from Your Resume", style: TextStyle(color: Color(0xFF22C55E), fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_gapData!.matchingSkills.isEmpty)
                            const Text("No direct keyword matches found. Upskilling recommended.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _gapData!.matchingSkills.map<Widget>((s) {
                                return Chip(
                                  avatar: const Icon(Icons.check, color: Color(0xFF22C55E), size: 14),
                                  label: Text(s, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.12),
                                  side: BorderSide(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Missing Skills (Red/Amber)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              SizedBox(width: 8),
                              Text("Missing & Required Skills to Target", style: TextStyle(color: Color(0xFFEF4444), fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_gapData!.missingSkills.isEmpty)
                            const Text("All key skills already match!", style: TextStyle(color: Color(0xFF22C55E), fontSize: 12))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _gapData!.missingSkills.map<Widget>((s) {
                                return Chip(
                                  avatar: const Icon(Icons.add, color: Color(0xFFEF4444), size: 14),
                                  label: Text(s, style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                  side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // C. CATEGORIZED GAP BREAKDOWN
              if (_gapData!.categorizedGaps.isNotEmpty) ...[
                Text(
                  "Categorized Competency Breakdown",
                  style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 160,
                  ),
                  itemCount: _gapData!.categorizedGaps.length,
                  itemBuilder: (context, idx) {
                    final key = _gapData!.categorizedGaps.keys.elementAt(idx);
                    final skills = _gapData!.categorizedGaps[key] ?? [];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.layers_rounded, color: Color(0xFF6366F1), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  key,
                                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: skills.map<Widget>((sk) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(sk, style: TextStyle(color: textPrimary, fontSize: 11)),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],

              // D. PHASED TRANSITION ROADMAP
              if (_gapData!.roadmap.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.route_rounded, color: Color(0xFF14B8A6), size: 22),
                    const SizedBox(width: 8),
                    Text("Actionable Step-by-Step Transition Phases", style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _gapData!.roadmap.length,
                  itemBuilder: (context, index) {
                    final phase = _gapData!.roadmap[index];
                    final phaseTitle = phase['phase']?.toString() ?? 'Phase ${index + 1}';
                    final guidance = phase['guidance']?.toString() ?? '';
                    final milestones = (phase['milestones'] as List<dynamic>?) ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text("Phase ${index + 1}", style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(phaseTitle, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          if (guidance.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(guidance, style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontSize: 13, height: 1.4)),
                          ],
                          if (milestones.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text("Key Milestones & Deliverables:", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...milestones.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.check_circle_outline_rounded, color: Color(0xFF14B8A6), size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(m.toString(), style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4)),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // E. RECOMMENDED PRODUCTION PROJECTS TO BUILD
              if (_gapData!.recommendedProjects.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.code_rounded, color: Color(0xFF6366F1), size: 22),
                    const SizedBox(width: 8),
                    Text("Recommended Portfolio Projects (To Prove Competence)", style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _gapData!.recommendedProjects.length,
                  itemBuilder: (context, idx) {
                    final proj = _gapData!.recommendedProjects[idx];
                    final title = proj['title']?.toString() ?? "Portfolio Project";
                    final desc = proj['description']?.toString() ?? "";
                    final stack = (proj['tech_stack'] as List<dynamic>?) ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(desc, style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontSize: 13, height: 1.4)),
                          if (stack.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: stack.map<Widget>((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(t.toString(), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // F. RECOMMENDED CERTIFICATIONS & RESUME TIPS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_gapData!.recommendedCertifications.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 20),
                                SizedBox(width: 8),
                                Text("Target Certifications", style: TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ..._gapData!.recommendedCertifications.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.verified, color: Color(0xFFF59E0B), size: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(c, style: TextStyle(color: textPrimary, fontSize: 13))),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  if (_gapData!.recommendedCertifications.isNotEmpty && _gapData!.resumeTransitionTips.isNotEmpty)
                    const SizedBox(width: 16),
                  if (_gapData!.resumeTransitionTips.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 22),
                                SizedBox(width: 8),
                                Text("Resume Positioning Tips", style: TextStyle(color: Color(0xFF6366F1), fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ..._gapData!.resumeTransitionTips.map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4.0),
                                    child: Icon(Icons.arrow_right, color: Color(0xFF6366F1), size: 18),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(tip, style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4))),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.psychology_alt_rounded, size: 64, color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "Enter a target role and click Analyze Match or choose a saved report above.",
                        style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
