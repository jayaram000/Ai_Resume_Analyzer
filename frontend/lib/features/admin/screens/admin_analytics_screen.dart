import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/theme/app_colors.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _adminData = {};

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await sl<ApiClient>().get('dashboard/admin/analytics/');
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _adminData = response.data['data'];
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? "Permission denied or failed to load stats.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Access Denied. Locked behind Django staff permission levels.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final brick = AppColors.resolveBrick(isDark);
    final ochre = AppColors.resolveOchre(isDark);

    return Scaffold(
      backgroundColor: paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cobalt))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: brick, size: 44),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: TextStyle(color: inkSoft), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ADMIN PERFORMANCE CONSOLE",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "System-wide intelligence monitoring users, document generation, and platform metrics.",
                        style: TextStyle(fontSize: 12, color: inkSoft),
                      ),
                      const SizedBox(height: 24),

                      // Users Stats
                      Text("USER PROFILE METRICS", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard("TOTAL USERS", _adminData['users']['total_users'], cobalt, paperAlt, rule, inkSoft)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard("ACTIVE (30D)", _adminData['users']['active_users'], forest, paperAlt, rule, inkSoft)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard("PREMIUM TIERS", _adminData['users']['premium_users'], ochre, paperAlt, rule, inkSoft)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Resumes and Jobs Stats
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Resumes stats card
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: paperAlt,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: rule),
                              ),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("RESUME AUDITS & SCORES", style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                  const SizedBox(height: 14),
                                  Text("Uploaded Resumes: ${_adminData['resumes']['total_resumes']}", style: TextStyle(color: inkSoft, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text("Average ATS Score: ${_adminData['resumes']['average_score']}", style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  Text("ATS SCORE DISTRIBUTION:", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                  const SizedBox(height: 10),
                                  _buildDistributionIndicator("Excellent (>=85):", _adminData['resumes']['score_distribution']['excellent'], forest, inkSoft),
                                  _buildDistributionIndicator("Good (70-85):", _adminData['resumes']['score_distribution']['good'], cobalt, inkSoft),
                                  _buildDistributionIndicator("Average (50-70):", _adminData['resumes']['score_distribution']['average'], ochre, inkSoft),
                                  _buildDistributionIndicator("Need Help (<50):", _adminData['resumes']['score_distribution']['needs_improvement'], brick, inkSoft),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Jobs stats card
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: paperAlt,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: rule),
                              ),
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("FIELD INTERACTIONS", style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                  const SizedBox(height: 14),
                                  Text("Bookmarked Jobs: ${_adminData['jobs']['saved_jobs']}", style: TextStyle(color: inkSoft, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text("Apply Dispatches: ${_adminData['jobs']['applied_jobs']}", style: TextStyle(color: inkSoft, fontSize: 13)),
                                  const SizedBox(height: 18),
                                  Text("SUBSCRIPTIONS BREAKDOWN:", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                  const SizedBox(height: 10),
                                  Text("Active Subscriptions: ${_adminData['subscriptions']['active']}", style: TextStyle(color: inkSoft, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text("Expired Subscriptions: ${_adminData['subscriptions']['expired']}", style: TextStyle(color: inkSoft, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text("Pending Orders: ${_adminData['subscriptions']['pending']}", style: TextStyle(color: inkSoft, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Platform Revenue Indicators
                      Text("PLATFORM REVENUES (MRR / ARR)", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRevenueCard(
                              "MONTHLY RECURRING REVENUE",
                              "\$${_adminData['revenue']['monthly_recurring_revenue']}",
                              forest,
                              paperAlt,
                              rule,
                              inkSoft,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildRevenueCard(
                              "ANNUAL RUN RATE",
                              "\$${_adminData['revenue']['annual_run_rate']}",
                              cobalt,
                              paperAlt,
                              rule,
                              inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard(String title, dynamic value, Color accentColor, Color cardBg, Color rule, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard(String title, String value, Color accentColor, Color cardBg, Color rule, Color textMuted) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: rule),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: accentColor, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionIndicator(String label, dynamic count, Color color, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMuted, fontSize: 12)),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
