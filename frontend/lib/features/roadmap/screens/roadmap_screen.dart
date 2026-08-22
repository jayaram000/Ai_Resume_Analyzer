import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/utils/file_downloader.dart';
import 'package:frontend/features/roadmap/data/roadmap_clean.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

class CareerRoadmapScreen extends StatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  State<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends State<CareerRoadmapScreen> {
  final _currentController = TextEditingController();
  final _targetController = TextEditingController(text: "Backend Architect");
  bool _showCurrentRoleField = false;
  bool _isLoading = false;
  Map<String, dynamic>? _roadmapData;
  String? _errorMessage;

  List<RoadmapEntity> _recentRoadmaps = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadRecentRoadmaps();
  }

  Future<void> _loadRecentRoadmaps() async {
    setState(() => _isLoadingHistory = true);
    final res = await sl<RoadmapRepository>().getRecentRoadmaps();
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (res.isSuccess && res.data != null) {
          _recentRoadmaps = res.data!;
        }
      });
    }
  }

  Future<void> _deleteRoadmap(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Roadmap", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this roadmap?", style: TextStyle(color: Color(0xFF94A3B8))),
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
      await sl<RoadmapRepository>().deleteRoadmap(id);
      if (_roadmapData != null && _roadmapData!['id'] == id) {
        setState(() => _roadmapData = null);
      }
      _loadRecentRoadmaps();
    }
  }

  Future<void> _downloadPdf() async {
    final roadmapId = _roadmapData?['id'];
    if (roadmapId == null) return;

    try {
      final target = (_roadmapData?['target_role'] ?? 'Roadmap').toString();
      final fileName = 'Career_Roadmap_${target.replaceAll(" ", "_")}.pdf';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating & downloading professional Roadmap PDF...')),
        );
      }

      final apiClient = sl<ApiClient>();
      final response = await apiClient.get(
        'analysis/roadmap/$roadmapId/pdf/',
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

  void _displayRoadmapEntity(RoadmapEntity r) {
    setState(() {
      _currentController.text = r.currentRole;
      _targetController.text = r.targetRole;
      _showCurrentRoleField = r.currentRole.isNotEmpty && r.currentRole != "Entry Level";
      _roadmapData = {
        'id': r.id,
        'target_role': r.targetRole,
        'current_role': r.currentRole,
        'technologies': r.technologies,
        'certifications': r.certifications,
        'learning_path': r.learningPath,
        'projects': r.projects,
        'youtube_videos': r.youtubeVideos,
        'youtube_channels': r.youtubeChannels,
        'documentation_sites': r.documentationSites,
        'popular_courses': r.popularCourses,
        'free_courses': r.freeCourses,
      };
    });
  }

  Future<void> _generateRoadmap() async {
    final target = _targetController.text.trim();
    final current = _showCurrentRoleField ? _currentController.text.trim() : "";
    if (target.isEmpty) return;

    setState(() {
      _isLoading = true;
      _roadmapData = null;
      _errorMessage = null;
    });

    try {
      final res = await sl<RoadmapRepository>().generateRoadmap(
        targetRole: target,
        currentRole: current.isNotEmpty ? current : null,
      );
      if (res.isSuccess && res.data != null) {
        _displayRoadmapEntity(res.data!);
        _loadRecentRoadmaps();
      } else {
        setState(() {
          _errorMessage = res.failure?.message ?? "Failed to generate roadmap.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network timeout. Recheck target role terms.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            Icon(Icons.alt_route_rounded, color: Color(0xFF14B8A6)),
            SizedBox(width: 10),
            Text("About Career Roadmap", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🗺️ What is Career Roadmap?",
              style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              "Career Roadmap is a high-level educational curriculum and milestone guide that charts a step-by-step career path. You can generate a full mastery blueprint for any target role, or calculate a transition path from your current position.",
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              "📚 What you get:",
              style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              "• Target Technology Stack & Top Certifications\n• Step-by-Step Transition Phases & Milestones\n• Production Portfolio Projects with tech stacks\n• Top YouTube Channels & Video Masterclasses\n• Official Documentation Portals (GeeksforGeeks, MDN, DevDocs)\n• Popular Online Courses (Udemy, Coursera, freeCodeCamp)\n• Executive Exportable PDF Report",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got It", style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCourseUrl(String? rawUrl, String platform, String courseName) async {
    final cleanUrl = rawUrl?.trim() ?? '';
    final p = platform.toLowerCase();
    final cLower = courseName.toLowerCase();
    final q = Uri.encodeComponent(courseName);

    String finalUrl = cleanUrl;

    // Check for MIT OpenCourseWare first to prevent 404
    if (p.contains('mit') || p.contains('ocw') || p.contains('opencourseware') || cLower.contains('mit') || cleanUrl.contains('ocw.mit.edu')) {
      final cleanQuery = courseName.replaceAll(RegExp(r'^(MIT OpenCourseWare:?|MIT OCW:?)\s*', caseSensitive: false), '').trim();
      finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent("site:ocw.mit.edu $cleanQuery")}';
    } else if (p.contains('roadmap') || cleanUrl.contains('roadmap.sh')) {
      finalUrl = cleanUrl.isNotEmpty && cleanUrl != 'https://roadmap.sh' ? cleanUrl : 'https://roadmap.sh';
    } else if (cleanUrl.isEmpty ||
        cleanUrl == 'https://www.udemy.com' ||
        cleanUrl == 'https://www.udemy.com/' ||
        cleanUrl == 'https://www.coursera.org' ||
        cleanUrl == 'https://www.coursera.org/' ||
        cleanUrl == 'https://www.pluralsight.com' ||
        cleanUrl == 'https://www.pluralsight.com/' ||
        cleanUrl == 'https://www.edx.org' ||
        cleanUrl == 'https://www.edx.org/' ||
        cleanUrl == 'https://www.freecodecamp.org' ||
        cleanUrl == 'https://www.freecodecamp.org/') {
      if (p.contains('udemy')) {
        finalUrl = 'https://www.udemy.com/courses/search/?q=$q';
      } else if (p.contains('coursera')) {
        finalUrl = 'https://www.coursera.org/search?query=$q';
      } else if (p.contains('pluralsight')) {
        finalUrl = 'https://www.pluralsight.com/search?q=$q';
      } else if (p.contains('edx')) {
        finalUrl = 'https://www.edx.org/search?q=$q';
      } else if (p.contains('freecodecamp')) {
        finalUrl = 'https://www.freecodecamp.org/news/search/?query=$q';
      } else if (p.contains('youtube')) {
        finalUrl = 'https://www.youtube.com/results?search_query=$q';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent("$courseName $platform course")}';
      }
    }

    final uri = Uri.tryParse(finalUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openDocUrl(String? rawUrl, String docName) async {
    final cleanUrl = rawUrl?.trim() ?? '';
    final n = docName.toLowerCase();
    final q = Uri.encodeComponent(docName);

    String finalUrl = cleanUrl;
    if (cleanUrl.isEmpty ||
        cleanUrl == 'https://www.geeksforgeeks.org' ||
        cleanUrl == 'https://www.geeksforgeeks.org/' ||
        cleanUrl == 'https://developer.mozilla.org' ||
        cleanUrl == 'https://developer.mozilla.org/') {
      if (n.contains('geek')) {
        finalUrl = 'https://www.geeksforgeeks.org/search/?q=$q';
      } else if (n.contains('mdn')) {
        finalUrl = 'https://developer.mozilla.org/en-US/search?q=$q';
      } else if (n.contains('devdocs')) {
        finalUrl = 'https://devdocs.io/#q=$q';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent("$docName official documentation")}';
      }
    }

    final uri = Uri.tryParse(finalUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final List techList = _roadmapData != null ? ((_roadmapData!['technologies'] as List?) ?? []) : [];
    final List certList = _roadmapData != null ? ((_roadmapData!['certifications'] as List?) ?? []) : [];
    final List pathList = _roadmapData != null ? ((_roadmapData!['learning_path'] as List?) ?? []) : [];
    final List projectList = _roadmapData != null ? ((_roadmapData!['projects'] as List?) ?? []) : [];
    final List videoList = _roadmapData != null ? ((_roadmapData!['youtube_videos'] as List?) ?? []) : [];
    final List channelList = _roadmapData != null ? ((_roadmapData!['youtube_channels'] as List?) ?? []) : [];
    final List docList = _roadmapData != null ? ((_roadmapData!['documentation_sites'] as List?) ?? []) : [];

    final currentRoleStr = _roadmapData?['current_role']?.toString() ?? '';
    final targetRoleStr = _roadmapData?['target_role']?.toString() ?? '';
    final displayTitle = (currentRoleStr.isNotEmpty && currentRoleStr != "Entry Level")
        ? "$currentRoleStr ➔ $targetRoleStr"
        : "Mastery Path: $targetRoleStr";

    final List popularCourseList = _roadmapData != null ? ((_roadmapData!['popular_courses'] as List?) ?? []) : [];
    final List freeCourseListRaw = _roadmapData != null ? ((_roadmapData!['free_courses'] as List?) ?? []) : [];
    final List freeCourseList = freeCourseListRaw.isNotEmpty
        ? freeCourseListRaw
        : (_roadmapData != null && targetRoleStr.isNotEmpty ? [
            {
              'platform': 'freeCodeCamp',
              'course_name': 'Learn $targetRoleStr - Full Tutorial for Beginners',
              'url': 'https://www.freecodecamp.org/news/search/?query=${Uri.encodeComponent(targetRoleStr)}',
            },
            {
              'platform': 'roadmap.sh',
              'course_name': 'Interactive $targetRoleStr Developer Roadmap',
              'url': 'https://roadmap.sh',
            },
            {
              'platform': 'edX (Free Audit)',
              'course_name': 'Introduction to $targetRoleStr',
              'url': 'https://www.edx.org/search?q=${Uri.encodeComponent(targetRoleStr)}',
            },
            {
              'platform': 'MIT OpenCourseWare',
              'course_name': 'Software Engineering & $targetRoleStr Systems',
              'url': 'https://www.google.com/search?q=site:ocw.mit.edu+${Uri.encodeComponent(targetRoleStr)}',
            },
          ] : []);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP TARGET ROLE & TRANSITION INPUT CARD
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
                        "AI Career Transition & Mastery Roadmap",
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _showInfoDialog,
                        icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF14B8A6), size: 20),
                        tooltip: "What is Career Roadmap?",
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Generate a complete learning curriculum, project blueprints, YouTube tutorials, documentation portals, and certification guides for any target tech position.",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Mode Toggle Button (Single Target Role vs Transition Pivot)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("🎯 Target Role Mastery"),
                        selected: !_showCurrentRoleField,
                        onSelected: (val) {
                          if (val) setState(() => _showCurrentRoleField = false);
                        },
                        selectedColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: !_showCurrentRoleField ? const Color(0xFF14B8A6) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text("🔄 Transition from Current Role"),
                        selected: _showCurrentRoleField,
                        onSelected: (val) {
                          if (val) setState(() => _showCurrentRoleField = true);
                        },
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _showCurrentRoleField ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      if (_showCurrentRoleField) ...[
                        Expanded(
                          child: TextFormField(
                            controller: _currentController,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              labelText: "Current Role",
                              hintText: "e.g. Junior Developer, Student",
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6366F1)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: TextFormField(
                          controller: _targetController,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: "Target Role *",
                            hintText: "e.g. Backend Architect, DevOps Engineer, Data Scientist",
                            prefixIcon: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF14B8A6)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator(color: Color(0xFF14B8A6))
                      : Container(
                          height: 46,
                          width: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF6366F1)]),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _generateRoadmap,
                            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                            label: const Text("Generate Roadmap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SAVED / RECENT ROADMAPS
            if (_recentRoadmaps.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Color(0xFF14B8A6), size: 18),
                      const SizedBox(width: 8),
                      Text("Recent Saved Roadmaps (${_recentRoadmaps.length})", style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_isLoadingHistory)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14B8A6))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentRoadmaps.length,
                  itemBuilder: (context, idx) {
                    final item = _recentRoadmaps[idx];
                    final isSelected = _roadmapData?['id'] == item.id;
                    final title = (item.currentRole.isNotEmpty && item.currentRole != "Entry Level")
                        ? "${item.currentRole} ➔ ${item.targetRole}"
                        : item.targetRole;
                    return Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => _displayRoadmapEntity(item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF14B8A6).withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF14B8A6) : borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, color: Color(0xFF14B8A6), size: 16),
                              const SizedBox(width: 8),
                              Text(
                                title,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  if (item.id != null) _deleteRoadmap(item.id!);
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

            if (_roadmapData != null) ...[
              // Header Card with Export PDF
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.map_rounded, color: Color(0xFF14B8A6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayTitle, style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text("Comprehensive Career Transition & Mastery Blueprint", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _downloadPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                      label: const Text("Export PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Tech stack & Certifications
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (techList.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.terminal_rounded, color: Color(0xFF14B8A6), size: 20),
                                SizedBox(width: 8),
                                Text("Target Tech Stack", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: techList.map<Widget>((tech) {
                                return Chip(
                                  label: Text(tech.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                                  side: const BorderSide(color: Color(0xFF14B8A6)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (techList.isNotEmpty && certList.isNotEmpty) const SizedBox(width: 16),
                  if (certList.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 20),
                                SizedBox(width: 8),
                                Text("Recommended Certifications", style: TextStyle(color: Color(0xFFF59E0B), fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: certList.map<Widget>((cert) {
                                return Chip(
                                  label: Text(cert.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.8),
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

              // Step by step phases
              Row(
                children: [
                  const Icon(Icons.route_rounded, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 8),
                  Text("Step-by-Step Transition Phases", style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pathList.length,
                itemBuilder: (context, index) {
                  final phase = pathList[index];
                  final phaseTitle = phase is Map ? (phase['phase'] ?? 'Phase ${index + 1}') : phase.toString();
                  final guidance = phase is Map ? phase['guidance']?.toString() : null;
                  final milestones = phase is Map && phase['milestones'] != null
                      ? (phase['milestones'] as List)
                      : [];

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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text("${index + 1}", style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(phaseTitle.toString(), style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (guidance != null && guidance.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text("Guidance: $guidance", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontStyle: FontStyle.italic)),
                        ],
                        if (milestones.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...milestones.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Icon(Icons.circle, color: Color(0xFF14B8A6), size: 6),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(m.toString(), style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569), fontSize: 13)),
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

              // Production Portfolio Projects
              if (projectList.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.code_rounded, color: Color(0xFF14B8A6), size: 20),
                    const SizedBox(width: 8),
                    Text("Hands-On Production Portfolio Projects", style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ...projectList.map((p) {
                  final pTitle = p['title'] ?? 'Portfolio Project';
                  final pDesc = p['description'] ?? '';
                  final pStack = (p['tech_stack'] is List) ? (p['tech_stack'] as List).join(', ') : (p['tech_stack'] ?? '');
                  final pOutcome = p['outcome'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.rocket_launch_rounded, color: Color(0xFF14B8A6), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(pTitle.toString(), style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(pDesc.toString(), style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontSize: 13)),
                        if (pStack.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text("Tech Stack: $pStack", style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                        if (pOutcome.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text("Proof of Competence: $pOutcome", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Video Tutorials & Channels Row
              if (videoList.isNotEmpty || channelList.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (videoList.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE11D48), size: 20),
                                  SizedBox(width: 8),
                                  Text("Curated Video Masterclasses", style: TextStyle(color: Color(0xFFE11D48), fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...videoList.map((v) {
                                final vTitle = v['title'] ?? 'Tutorial';
                                final vChan = v['channel'] ?? 'YouTube';
                                final vUrl = v['url'] ?? '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vTitle.toString(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text("Channel: $vChan", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _openCourseUrl(vUrl.toString(), "YouTube", vTitle.toString()),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFE11D48)),
                                            SizedBox(width: 4),
                                            Text("Watch Tutorial", style: TextStyle(color: Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    if (videoList.isNotEmpty && channelList.isNotEmpty) const SizedBox(width: 16),
                    if (channelList.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tv_rounded, color: Color(0xFFE11D48), size: 20),
                                  SizedBox(width: 8),
                                  Text("Top YouTube Channels", style: TextStyle(color: Color(0xFFE11D48), fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...channelList.map((ch) {
                                final chName = ch['channel_name'] ?? 'Channel';
                                final chFocus = ch['focus'] ?? '';
                                final chUrl = ch['url'] ?? '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(chName.toString(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                      if (chFocus.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(chFocus.toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                      ],
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _openCourseUrl(chUrl.toString(), "YouTube", chName.toString()),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFE11D48)),
                                            SizedBox(width: 4),
                                            Text("Visit Channel", style: TextStyle(color: Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Documentation Sites & Online Courses Row
              if (docList.isNotEmpty || popularCourseList.isNotEmpty || freeCourseList.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (docList.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.menu_book_rounded, color: Color(0xFF14B8A6), size: 20),
                                  SizedBox(width: 8),
                                  Text("Documentation & Technical Portals", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...docList.map((d) {
                                final dName = d['name'] ?? 'Documentation';
                                final dCategory = d['category'] ?? '';
                                final dDesc = d['description'] ?? '';
                                final dUrl = d['url'] ?? '';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dName.toString(),
                                              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (dCategory.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(dCategory.toString(), style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (dDesc.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(dDesc.toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                      ],
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _openDocUrl(dUrl.toString(), dName.toString()),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF14B8A6)),
                                            SizedBox(width: 4),
                                            Text("Open Documentation", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    if (docList.isNotEmpty && (popularCourseList.isNotEmpty || freeCourseList.isNotEmpty)) const SizedBox(width: 16),
                    if (popularCourseList.isNotEmpty || freeCourseList.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (popularCourseList.isNotEmpty) ...[
                                const Row(
                                  children: [
                                    Icon(Icons.school_rounded, color: Color(0xFF6366F1), size: 20),
                                    SizedBox(width: 8),
                                    Text("Popular Online Courses", style: TextStyle(color: Color(0xFF6366F1), fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ...popularCourseList.map((c) {
                                  final cPlat = c['platform'] ?? 'Course';
                                  final cName = c['course_name'] ?? '';
                                  final cUrl = c['url'] ?? '';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(cPlat.toString(), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(cName.toString(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _openCourseUrl(cUrl.toString(), cPlat.toString(), cName.toString()),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF6366F1)),
                                              SizedBox(width: 4),
                                              Text("View Direct Course", style: TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (freeCourseList.isNotEmpty) ...[
                                if (popularCourseList.isNotEmpty) const Divider(height: 28),
                                const Row(
                                  children: [
                                    Text("🌱", style: TextStyle(fontSize: 16)),
                                    SizedBox(width: 8),
                                    Text("Free Learning Platforms", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...freeCourseList.map((fc) {
                                  final fcPlat = fc['platform'] ?? 'Platform';
                                  final fcName = fc['course_name'] ?? '';
                                  final fcUrl = fc['url'] ?? '';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2.0),
                                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF14B8A6), size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "$fcPlat: $fcName",
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () => _openCourseUrl(fcUrl.toString(), fcPlat.toString(), fcName.toString()),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF14B8A6)),
                                                    SizedBox(width: 4),
                                                    Text("Open Free Course", style: TextStyle(color: Color(0xFF14B8A6), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                      ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.alt_route_rounded, size: 64, color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "Enter your target role or select a transition mode above to generate your customized roadmap.",
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
