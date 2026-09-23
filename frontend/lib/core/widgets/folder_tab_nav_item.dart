import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';

/// "Casefile" Folder Tab Sidebar Nav Item.
///
/// Pattern:
/// - Text-led with a small indicator dot (`.dot`).
/// - Active state features a 3px solid right-border accent in `cobalt` (no filled rounded pill).
/// - Clean paper-and-ink styling with subtle hover/active tone.
class FolderTabNavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPro;
  final bool isPremiumUser;
  final IconData? icon;

  const FolderTabNavItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPro = false,
    this.isPremiumUser = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cobalt = AppColors.resolveCobalt(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    // Active state: paper_alt background tone, right border 3px in cobalt
    final activeBg = isDark
        ? const Color(0xFF221E17)
        : const Color(0xFFE8E1CE);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: cobalt.withValues(alpha: 0.08),
        highlightColor: cobalt.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            border: Border(
              right: BorderSide(
                color: isSelected ? cobalt : Colors.transparent,
                width: 3.0,
              ),
              bottom: BorderSide(
                color: isDark ? const Color(0x1F3A3527) : const Color(0x2FCFC6AE),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Indicator dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? cobalt
                      : (isDark ? const Color(0xFF4A4435) : const Color(0xFFAFA794)),
                ),
              ),
              const SizedBox(width: 12),

              // Optional subtle icon (compact, text-led focus)
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? cobalt : inkSoft,
                ),
                const SizedBox(width: 10),
              ],

              // Label
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyRegular(
                    color: isSelected ? ink : inkSoft,
                    fontSize: 13.5,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ),

              // PRO badge if feature is premium
              if (isPro && !isPremiumUser)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ochre.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    "PRO",
                    style: AppTypography.monoLabel(
                      color: ochre,
                      fontSize: 9.5,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
