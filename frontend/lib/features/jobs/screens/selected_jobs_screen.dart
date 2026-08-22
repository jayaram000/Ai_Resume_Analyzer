import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:url_launcher/url_launcher.dart';

class SelectedJobsScreen extends StatefulWidget {
  const SelectedJobsScreen({super.key});

  @override
  State<SelectedJobsScreen> createState() => _SelectedJobsScreenState();
}

class _SelectedJobsScreenState extends State<SelectedJobsScreen> {
  bool _isLoading = true;
  List<dynamic> _jobs = [];
  String? _errorMessage;

  final List<String> _kanbanColumns = [
    'SAVED',
    'APPLIED',
    'INTERVIEW_CALL_RECEIVED',
    'OFFER_RECEIVED',
    'REJECTED'
  ];

  final Map<String, String> _columnTitles = {
    'SAVED': 'Saved',
    'NOT_APPLIED': 'Not Applied',
    'APPLIED': 'Applied',
    'INTERVIEW_CALL_RECEIVED': 'Interviewing',
    'OFFER_RECEIVED': 'Offered',
    'REJECTED': 'Rejected'
  };

  @override
  void initState() {
    super.initState();
    _loadSelectedJobs();
  }

  Future<void> _loadSelectedJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await sl<ApiClient>().get('jobs/selected/');
      if (response.statusCode == 200) {
        setState(() {
          if (response.data is List) {
            _jobs = response.data;
          } else if (response.data is Map && response.data.containsKey('data')) {
            _jobs = response.data['data'];
          } else if (response.data is Map && response.data.containsKey('results')) {
            _jobs = response.data['results'];
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to load selected jobs.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateJobStatus(String id, String newStatus) async {
    try {
      final response = await sl<ApiClient>().patch('jobs/selected/$id/', data: {'status': newStatus});
      if (response.statusCode == 200) {
        _loadSelectedJobs();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status.")));
    }
  }

  Future<void> _deleteJob(String id) async {
    try {
      final response = await sl<ApiClient>().delete('jobs/selected/$id/');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _loadSelectedJobs();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete job.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Job Applications Kanban"),
        backgroundColor: const Color(0xFF0F172A),
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _kanbanColumns.map((col) => _buildKanbanColumn(col)).toList(),
                  ),
                ),
    );
  }

  Widget _buildKanbanColumn(String status) {
    final columnJobs = _jobs.where((j) => j['status'] == status || (status == 'SAVED' && j['status'] == 'NOT_APPLIED')).toList();

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _columnTitles[status] ?? status,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(12)),
                  child: Text("${columnJobs.length}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: columnJobs.length,
              itemBuilder: (context, index) {
                final job = columnJobs[index];
                return _buildJobCard(job);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(dynamic job) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job['job_title'] ?? 'Role', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(job['company_name'] ?? 'Company', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6366F1), size: 18),
                  color: const Color(0xFF1E293B),
                  tooltip: "Move to",
                  onSelected: (val) {
                    _updateJobStatus(job['id'].toString(), val);
                  },
                  itemBuilder: (context) {
                    return _kanbanColumns.map((col) {
                      return PopupMenuItem<String>(
                        value: col,
                        child: Text("Move to ${_columnTitles[col]}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }).toList();
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Color(0xFF14B8A6), size: 16),
                      onPressed: () async {
                        final applyUrl = job['apply_link'];
                        if (applyUrl != null && applyUrl.isNotEmpty) {
                          final Uri url = Uri.parse(applyUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                      onPressed: () => _deleteJob(job['id'].toString()),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
