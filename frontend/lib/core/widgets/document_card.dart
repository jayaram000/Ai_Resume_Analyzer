import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';

/// "Casefile" Document Card widget.
///
/// Replaces generic rounded cards with a tactile working dossier card:
/// - `paper_alt` background surface with 1px hairline `rule` border.
/// - Colored tab flag pinned at top-left (no drop shadow).
/// - ATS/Review score rendered in JetBrains Mono at top-right.
/// - Document title, metadata labels, and actions.
class DocumentCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? score;
  final int? completeness;
  final String? dateLabel;
  final Color? tabFlagColor;
  final VoidCallback? onTap;
  final VoidCallback? onViewPdf;
  final VoidCallback? onViewAnalysis;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.title,
    this.subtitle,
    this.score,
    this.completeness,
    this.dateLabel,
    this.tabFlagColor,
    this.onTap,
    this.onViewPdf,
    this.onViewAnalysis,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final brick = AppColors.resolveBrick(isDark);
    final forest = AppColors.resolveForest(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    final flagColor = tabFlagColor ??
        (score != null
            ? (score! >= 70 ? forest : (score! >= 50 ? ochre : brick))
            : cobalt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: paperAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Colored dossier tab flag at top-left
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 32,
                height: 4,
                color: flagColor,
              ),
            ),

            // Card body
            InkWell(
              onTap: onTap ?? onViewAnalysis,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document type emblem
                    Container(
                      width: 38,
                      height: 44,
                      decoration: BoxDecoration(
                        color: rule.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: rule, width: 0.8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: flagColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title and dossier metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.displayHeading(
                              color: ink,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (score != null) ...[
                                Text(
                                  "ATS: ",
                                  style: AppTypography.monoLabel(color: inkSoft, fontSize: 11),
                                ),
                                Text(
                                  score! > 0 ? "$score/100" : "Unscored",
                                  style: AppTypography.monoLabel(
                                    color: flagColor,
                                    fontSize: 11.5,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                              if (completeness != null) ...[
                                Text(" • ", style: TextStyle(color: inkSoft, fontSize: 11)),
                                Text(
                                  "Complete: $completeness%",
                                  style: AppTypography.monoLabel(color: inkSoft, fontSize: 11),
                                ),
                              ],
                              if (dateLabel != null) ...[
                                Text(" • ", style: TextStyle(color: inkSoft, fontSize: 11)),
                                Text(
                                  dateLabel!,
                                  style: AppTypography.monoLabel(color: inkSoft, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: AppTypography.bodyRegular(color: inkSoft, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Top-right Score in JetBrains Mono
                    if (score != null && score! > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: flagColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: flagColor.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Text(
                          "$score",
                          style: AppTypography.monoScore(
                            color: flagColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    // Context Menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: inkSoft, size: 18),
                      color: paperAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: rule, width: 1),
                      ),
                      onSelected: (val) {
                        if (val == 'view_pdf') onViewPdf?.call();
                        if (val == 'view_analysis') onViewAnalysis?.call();
                        if (val == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onViewAnalysis != null)
                          PopupMenuItem(
                            value: 'view_analysis',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 15, color: ink),
                                const SizedBox(width: 8),
                                Text("View Dossier", style: AppTypography.bodyRegular(color: ink, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        if (onViewPdf != null)
                          PopupMenuItem(
                            value: 'view_pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, size: 15, color: ink),
                                const SizedBox(width: 8),
                                Text("Open PDF", style: AppTypography.bodyRegular(color: ink, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 15, color: brick),
                                const SizedBox(width: 8),
                                Text("Discard File", style: AppTypography.bodyRegular(color: brick, fontSize: 12.5)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
