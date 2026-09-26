import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/widgets/premium_plan_paywall.dart';
import 'package:frontend/features/dashboard/cubit/usage_cubit.dart';

class UsageQuotaBadge extends StatefulWidget {
  final bool showUpgradeAction;
  final bool compact;

  const UsageQuotaBadge({
    super.key,
    this.showUpgradeAction = true,
    this.compact = false,
  });

  @override
  State<UsageQuotaBadge> createState() => _UsageQuotaBadgeState();
}

class _UsageQuotaBadgeState extends State<UsageQuotaBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Ticks every second to keep live countdown in sync
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(DateTime resetAt) {
    final diff = resetAt.difference(DateTime.now());
    if (diff.isNegative) return "Ready to reset";
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    final s = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final m = minutes.toString().padLeft(2, '0');
      return "Resets in ${hours}h ${m}m ${s}s";
    } else if (minutes > 0) {
      return "Resets in ${minutes}m ${s}s";
    } else {
      return "Resets in ${seconds}s";
    }
  }

  Color _resolveBadgeColor(int remaining, bool isDark) {
    if (remaining >= 2) return AppColors.resolveForest(isDark);
    if (remaining == 1) return AppColors.resolveOchre(isDark);
    return AppColors.resolveBrick(isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);

    return BlocBuilder<UsageCubit, UsageState>(
      builder: (context, state) {
        if (state.isUnlimited) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: paperAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: forest.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.all_inclusive_rounded, size: 14, color: forest),
                const SizedBox(width: 6),
                Text(
                  "PRO // UNLIMITED ACCESS",
                  style: GoogleFonts.jetBrainsMono(
                    color: forest,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }

        final statusColor = _resolveBadgeColor(state.usageRemaining, isDark);
        final isExhausted = state.usageRemaining == 0;

        if (widget.compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: paperAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${state.usageRemaining} / 3 FREE SCANS LEFT",
                      style: GoogleFonts.jetBrainsMono(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                if (isExhausted && state.resetAt != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 11, color: inkSoft),
                      const SizedBox(width: 4),
                      Text(
                        _formatCountdown(state.resetAt!),
                        style: GoogleFonts.jetBrainsMono(
                          color: inkSoft,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: paperAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: rule),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${state.usageRemaining} / 3 FREE SCANS REMAINING",
                style: GoogleFonts.jetBrainsMono(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (isExhausted && state.resetAt != null) ...[
                const SizedBox(width: 8),
                Text("•", style: TextStyle(color: inkSoft, fontSize: 11)),
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 12, color: inkSoft),
                const SizedBox(width: 4),
                Text(
                  _formatCountdown(state.resetAt!),
                  style: GoogleFonts.jetBrainsMono(
                    color: inkSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (widget.showUpgradeAction) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => PremiumPlanPaywall.showAsDialog(
                    context,
                    featureTitle: "Unlimited Resume Scans",
                    featureDescription: "Remove the 3-scan limit and unlock instant, rolling-free access across all AI auditing tools.",
                  ),
                  child: Text(
                    "UPGRADE",
                    style: TextStyle(
                      color: cobalt,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
