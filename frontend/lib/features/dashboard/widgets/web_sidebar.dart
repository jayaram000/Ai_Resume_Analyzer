import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';
import 'package:frontend/core/widgets/folder_tab_nav_item.dart';
import 'package:frontend/core/widgets/usage_quota_badge.dart';

// Casefile Navigation Sidebar

class WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onUpgradePressed;
  final VoidCallback? onLogoutPressed;
  final bool isPremium;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onUpgradePressed,
    this.onLogoutPressed,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final ochre = AppColors.resolveOchre(isDark);
    final forest = AppColors.resolveForest(isDark);
    final brick = AppColors.resolveBrick(isDark);

    final navItems = [
      {'label': 'Dashboard', 'isPro': false, 'icon': Icons.space_dashboard_outlined},
      {'label': 'My Resumes', 'isPro': false, 'icon': Icons.folder_open_rounded},
      {'label': 'Tracked Jobs', 'isPro': false, 'icon': Icons.view_kanban_outlined},
      {'label': 'AI Analysis & Tools', 'isPro': false, 'icon': Icons.document_scanner_outlined},
      {'label': 'Skill Gap Intelligence', 'isPro': true, 'icon': Icons.analytics_outlined},
      {'label': 'Career Roadmap', 'isPro': true, 'icon': Icons.alt_route_rounded},
      {'label': 'Settings', 'isPro': false, 'icon': Icons.tune_rounded},
    ];

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: paper,
        border: Border(right: BorderSide(color: rule, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BRAND HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cobalt.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Center(
                    child: Icon(Icons.description_outlined, color: cobalt, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ResumeAI',
                      style: AppTypography.displayHeading(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Career Copilot',
                      style: AppTypography.monoLabel(
                        color: inkSoft,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Hairline separator
          Divider(color: rule, height: 1, thickness: 1),
          const SizedBox(height: 8),

          // NAVIGATION SECTION HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              "NAVIGATION",
              style: AppTypography.monoLabel(
                color: inkSoft,
                fontSize: 10,
              ).copyWith(letterSpacing: 0.8),
            ),
          ),

          // NAV ITEMS LIST CONSUMING FolderTabNavItem
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;

                return FolderTabNavItem(
                  label: item['label'] as String,
                  isSelected: isSelected,
                  isPro: item['isPro'] as bool,
                  isPremiumUser: isPremium,
                  icon: item['icon'] as IconData?,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),

          // FREEMIUM USAGE INDICATOR
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: UsageQuotaBadge(compact: true, showUpgradeAction: false),
          ),

          // PRO TIER SUMMARY CARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: paperAlt,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: rule, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPremium ? Icons.verified_outlined : Icons.star_border_rounded,
                        color: isPremium ? forest : ochre,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPremium ? 'Pro Member' : 'Free Plan',
                        style: AppTypography.bodyRegular(
                          color: ink,
                          fontSize: 12.5,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPremium
                        ? 'Unlimited access to resume scans, skill blueprints & PDF exports.'
                        : 'Unlock unlimited AI scans, skill gap analysis & job tailoring.',
                    style: AppTypography.bodyRegular(
                      color: inkSoft,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  if (!isPremium) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onUpgradePressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cobalt,
                          side: BorderSide(color: cobalt, width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Upgrade to Pro',
                          style: AppTypography.buttonText(
                            color: cobalt,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // LOGOUT ACTION
          if (onLogoutPressed != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: InkWell(
                onTap: onLogoutPressed,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: brick.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: brick.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: brick, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        'Log Out',
                        style: AppTypography.bodyRegular(
                          color: brick,
                          fontSize: 12.5,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
