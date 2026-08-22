import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:frontend/features/resume/domain/entities/resume_entities.dart';
import 'package:frontend/features/resume/screens/ats_analysis_screen.dart';
import 'package:frontend/features/resume/screens/resume_comparison_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MyResumesScreen extends StatefulWidget {
  const MyResumesScreen({super.key});

  @override
  State<MyResumesScreen> createState() => _MyResumesScreenState();
}

class _MyResumesScreenState extends State<MyResumesScreen> {
  List<ResumeEntity> _resumes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  Future<void> _loadResumes() async {
    setState(() => _isLoading = true);
    try {
      final result = await sl<ResumeRepository>().getMyResumes();
      if (result.isSuccess && result.data != null) {
        setState(() {
          _resumes = result.data!;
        });
      }
    } catch (e) {
      debugPrint("Failed to load resumes: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteResume(String id) async {
    try {
      final result = await sl<ResumeRepository>().deleteResume(id);
      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resume deleted.")));
        }
        _loadResumes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete resume.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          )
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Resumes",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ResumeComparisonScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: const Text("Compare"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14B8A6),
                        side: const BorderSide(color: Color(0xFF14B8A6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_resumes.isEmpty)
                  const Center(
                    child: Text(
                      "No resumes uploaded.",
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _resumes.length,
                      itemBuilder: (context, index) {
                        final res = _resumes[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.redAccent,
                                  size: 40,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        res.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "ATS Score: ${res.atsScore > 0 ? res.atsScore : 'N/A'} • Completeness: ${res.completenessScore}%",
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                  ),
                                  color: const Color(0xFF0F172A),
                                  onSelected: (val) async {
                                    if (val == 'view_pdf') {
                                      final fileUrl = res.fileUrl;
                                      if (fileUrl != null) {
                                        final Uri url = Uri.parse(fileUrl);
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url);
                                        }
                                      }
                                    } else if (val == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ATSAnalysisScreen(
                                                resumeId: res.id,
                                                resumeTitle: res.title,
                                                fileUrl: res.fileUrl,
                                              ),
                                        ),
                                      );
                                    } else if (val == 'delete') {
                                      _deleteResume(res.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view_pdf',
                                      child: Text(
                                        "View PDF",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Text(
                                        "View Analysis",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        "Delete",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
  }
}
