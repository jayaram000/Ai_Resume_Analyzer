import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/widgets/document_card.dart';
import 'package:frontend/features/resume/domain/entities/resume_entities.dart';
import 'package:frontend/features/resume/domain/repositories/resume_repository.dart';
import 'package:frontend/features/resume/screens/ats_analysis_screen.dart';
import 'package:frontend/features/resume/screens/resume_comparison_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MyResumesScreen extends StatefulWidget {
  final VoidCallback? onResumesChanged;

  const MyResumesScreen({super.key, this.onResumesChanged});

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

  Future<void> _deleteResume(String id, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.resolvePaperAlt(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.resolveRule(isDark)),
        ),
        title: Text(
          "Delete Resume",
          style: AppTypography.displayHeading(color: AppColors.resolveInk(isDark), fontSize: 16),
        ),
        content: Text(
          _resumes.length == 1
              ? "Are you sure you want to delete '$title'?\n\nSince this is your only resume, deleting it will also completely clear all associated AI analysis, ATS audits, and career scores."
              : "Are you sure you want to delete '$title'?",
          style: AppTypography.bodyRegular(color: AppColors.resolveInkSoft(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: AppColors.resolveInkSoft(isDark))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.resolveBrick(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await sl<ResumeRepository>().deleteResume(id);
      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Resume deleted successfully.")),
          );
        }
        await _loadResumes();
        widget.onResumesChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete resume.")),
        );
      }
    }
  }

  Future<void> _deleteAllResumes() async {
    if (_resumes.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.resolvePaperAlt(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.resolveRule(isDark)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.resolveBrick(isDark), size: 20),
            const SizedBox(width: 8),
            Text(
              "Delete All Resumes?",
              style: AppTypography.displayHeading(color: AppColors.resolveInk(isDark), fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete all ${_resumes.length} resumes?\n\nThis will permanently delete all uploaded files and completely erase all associated AI analysis, ATS audit history, skill gap reports, and career scores.",
          style: AppTypography.bodyRegular(color: AppColors.resolveInkSoft(isDark), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: AppColors.resolveInkSoft(isDark))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.resolveBrick(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await sl<ResumeRepository>().deleteAllResumes();
      if (result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("All resumes and analysis data deleted successfully.")),
          );
        }
        await _loadResumes();
        widget.onResumesChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete all resumes.")),
        );
      }
    }
  }

  Future<void> _openAnalysis(ResumeEntity res) async {
    final targetIndex = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ATSAnalysisScreen(
          resumeId: res.id,
          resumeTitle: res.title,
          fileUrl: res.fileUrl,
        ),
      ),
    );
    if (targetIndex is int && mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(targetIndex);
      }
    }
  }

  Future<void> _openPdf(String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) return;
    final Uri url = Uri.parse(fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final rule = AppColors.resolveRule(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final brick = AppColors.resolveBrick(isDark);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: cobalt),
      );
    }

    return Container(
      color: paper,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MY RESUMES",
                    style: AppTypography.monoLabel(color: inkSoft, fontSize: 10.5).copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "My Resumes",
                        style: AppTypography.displayHero(color: ink, fontSize: 24),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: rule.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: rule, width: 0.8),
                        ),
                        child: Text(
                          "${_resumes.length} TOTAL",
                          style: AppTypography.monoLabel(color: inkSoft, fontSize: 10).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_resumes.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: _deleteAllResumes,
                      icon: Icon(Icons.delete_sweep_outlined, size: 16, color: brick),
                      label: Text("Delete All", style: TextStyle(color: brick)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brick,
                        side: BorderSide(color: brick.withValues(alpha: 0.6), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ResumeComparisonScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                    label: const Text("Compare Resumes"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cobalt,
                      side: BorderSide(color: cobalt, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: rule, height: 1, thickness: 1),
          const SizedBox(height: 20),

          // Resume List
          if (_resumes.isEmpty)
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: paperAlt,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: rule, width: 1.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_outlined, color: inkSoft, size: 44),
                      const SizedBox(height: 14),
                      Text(
                        "NO RESUMES UPLOADED",
                        style: AppTypography.monoLabel(color: ink, fontSize: 13).copyWith(letterSpacing: 0.6, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Upload your first resume to get ATS scores and AI improvements.",
                        style: AppTypography.bodyRegular(color: inkSoft, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _resumes.length,
                itemBuilder: (context, index) {
                  final res = _resumes[index];
                  return DocumentCard(
                    title: res.title,
                    score: res.atsScore,
                    completeness: res.completenessScore,
                    onTap: () => _openAnalysis(res),
                    onViewAnalysis: () => _openAnalysis(res),
                    onViewPdf: res.fileUrl != null ? () => _openPdf(res.fileUrl) : null,
                    onDelete: () => _deleteResume(res.id, res.title),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
