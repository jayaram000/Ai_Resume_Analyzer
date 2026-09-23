import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';

/// "Casefile" Pipeline Funnel Bar widget.
///
/// A horizontal segmented bar displaying job conversion stages:
/// - Wishlist/Saved: `ink_soft`
/// - Applied: `cobalt`
/// - Interviewing: `ochre`
/// - Offer: `forest`
///
/// Directly consumes funnel data from `application_tracker_service.py`:
/// ```json
/// {
///   "stages": [
///     {"stage": "Saved", "count": 12, "conversion_rate": 100.0},
///     {"stage": "Applied", "count": 8, "conversion_rate": 66.7},
///     {"stage": "Interviewing", "count": 3, "conversion_rate": 37.5},
///     {"stage": "Offer", "count": 1, "conversion_rate": 33.3}
///   ],
///   "total_tracked": 12,
///   "overall_offer_rate": 12.5
/// }
/// ```
class PipelineFunnelBar extends StatelessWidget {
  final Map<String, dynamic>? funnelData;
  final Map<String, dynamic>? fallbackCounts;
  final String title;
  final bool showHeader;

  const PipelineFunnelBar({
    super.key,
    this.funnelData,
    this.fallbackCounts,
    this.title = "Application Funnel & Pipeline Velocity",
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);

    // Exact stage colors per spec:
    // Wishlist: ink_soft, Applied: cobalt, Interviewing: ochre, Offer: forest
    final colorWishlist = inkSoft;
    final colorApplied = AppColors.resolveCobalt(isDark);
    final colorInterviewing = AppColors.resolveOchre(isDark);
    final colorOffer = AppColors.resolveForest(isDark);

    // Parse counts from funnelData or fallbackCounts
    int countSaved = 0;
    int countApplied = 0;
    int countInterviewing = 0;
    int countOffer = 0;
    double offerRate = 0.0;

    if (funnelData != null && funnelData!['stages'] is List) {
      final stages = funnelData!['stages'] as List;
      for (var s in stages) {
        if (s is Map) {
          final name = (s['stage'] ?? '').toString().toLowerCase();
          final count = (s['count'] as num?)?.toInt() ?? 0;
          if (name.contains('save') || name.contains('wish') || name.contains('shortlist')) {
            countSaved += count;
          } else if (name.contains('applied')) {
            countApplied += count;
          } else if (name.contains('interview')) {
            countInterviewing += count;
          } else if (name.contains('offer')) {
            countOffer += count;
          }
        }
      }
      offerRate = (funnelData!['overall_offer_rate'] as num?)?.toDouble() ?? 0.0;
    } else if (fallbackCounts != null) {
      countSaved = (fallbackCounts!['SAVED'] as num?)?.toInt() ??
          (fallbackCounts!['SHORTLISTED'] as num?)?.toInt() ?? 0;
      countApplied = (fallbackCounts!['APPLIED'] as num?)?.toInt() ?? 0;
      countInterviewing = (fallbackCounts!['INTERVIEWING'] as num?)?.toInt() ??
          (fallbackCounts!['INTERVIEW_CALL_RECEIVED'] as num?)?.toInt() ?? 0;
      countOffer = (fallbackCounts!['OFFER_RECEIVED'] as num?)?.toInt() ?? 0;
      if (countApplied > 0) {
        offerRate = ((countOffer / countApplied) * 100.0);
      }
    }

    final int total = countSaved + countApplied + countInterviewing + countOffer;

    final stagesMeta = [
      {'label': 'Wishlist', 'count': countSaved, 'color': colorWishlist},
      {'label': 'Applied', 'count': countApplied, 'color': colorApplied},
      {'label': 'Interviewing', 'count': countInterviewing, 'color': colorInterviewing},
      {'label': 'Offer', 'count': countOffer, 'color': colorOffer},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: paperAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorApplied,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: AppTypography.displayHeading(
                        color: ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (total > 0)
                  Text(
                    "Offer Rate: ${offerRate.toStringAsFixed(1)}%",
                    style: AppTypography.monoLabel(
                      color: colorOffer,
                      fontSize: 12,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Horizontal Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: rule.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: total == 0
                  ? Center(
                      child: Text(
                        "no applications tracked yet",
                        style: AppTypography.monoLabel(color: inkSoft, fontSize: 10),
                      ),
                    )
                  : Row(
                      children: stagesMeta.map((s) {
                        final count = s['count'] as int;
                        if (count == 0) return const SizedBox.shrink();
                        return Expanded(
                          flex: count,
                          child: Tooltip(
                            message: "${s['label']}: $count (${((count / total) * 100).toStringAsFixed(0)}%)",
                            child: Container(
                              color: s['color'] as Color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Legend below showing counts and stages
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stagesMeta.map((s) {
              final color = s['color'] as Color;
              final count = s['count'] as int;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s['label'] as String,
                    style: AppTypography.bodyRegular(color: inkSoft, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$count",
                    style: AppTypography.monoLabel(
                      color: ink,
                      fontSize: 12,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
