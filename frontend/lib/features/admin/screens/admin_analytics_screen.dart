import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Admin Performance Console",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Aggregate dashboard metrics monitoring users, document generation, and platform revenues.",
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 24),

                      // Users Stats
                      const Text("Users Statistics", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard("Total Users", _adminData['users']['total_users'], const Color(0xFF6366F1))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard("Active (30d)", _adminData['users']['active_users'], const Color(0xFF14B8A6))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard("Premium Subs", _adminData['users']['premium_users'], const Color(0xFFEC4899))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Resumes and Jobs Stats
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Resumes stats card
                          Expanded(
                            child: Card(
                              color: const Color(0xFF1E293B).withOpacity(0.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Resume & Scores", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Text("Uploaded Resumes: ${_adminData['resumes']['total_resumes']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Text("Average ATS Score: ${_adminData['resumes']['average_score']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 16),
                                    const Text("ATS Score Distribution:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    _buildDistributionIndicator("Excellent (>=85):", _adminData['resumes']['score_distribution']['excellent'], const Color(0xFF14B8A6)),
                                    _buildDistributionIndicator("Good (70-85):", _adminData['resumes']['score_distribution']['good'], const Color(0xFF6366F1)),
                                    _buildDistributionIndicator("Average (50-70):", _adminData['resumes']['score_distribution']['average'], const Color(0xFFF59E0B)),
                                    _buildDistributionIndicator("Need Help (<50):", _adminData['resumes']['score_distribution']['needs_improvement'], Colors.redAccent),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Jobs stats card
                          Expanded(
                            child: Card(
                              color: const Color(0xFF1E293B).withOpacity(0.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Job Interactions", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Text("Total Bookmarked Jobs: ${_adminData['jobs']['saved_jobs']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Text("Apply Link Clicks tracked: ${_adminData['jobs']['applied_jobs']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 24),
                                    const Text("Subscriptions Breakdown:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    Text("Active Plans: ${_adminData['subscriptions']['active']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("Expired Plans: ${_adminData['subscriptions']['expired']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text("Pending Tiers: ${_adminData['subscriptions']['pending']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Platform Revenue Indicators
                      const Text("Platform Revenues (SaaS MRR)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRevenueCard(
                              "Monthly Recurring Revenue",
                              "\$${_adminData['revenue']['monthly_recurring_revenue']}",
                              const Color(0xFF14B8A6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRevenueCard(
                              "Annual Run Rate",
                              "\$${_adminData['revenue']['annual_run_rate']}",
                              const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard(String title, dynamic value, Color accentColor) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, String value, Color accentColor) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: accentColor, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionIndicator(String label, dynamic count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
