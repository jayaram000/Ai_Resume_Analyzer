import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:url_launcher/url_launcher.dart';

class SelectedJobsScreen extends StatefulWidget {
  const SelectedJobsScreen({super.key});

  @override
  State<SelectedJobsScreen> createState() => _SelectedJobsScreenState();
}

class _SelectedJobsScreenState extends State<SelectedJobsScreen> with SingleTickerProviderStateMixin {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _jobs = [];
  String? _errorMessage;
  String _searchQuery = "";
  bool _isKanbanView = true;
  late TabController _tabController;
  final ScrollController _kanbanScrollController = ScrollController();
  Timer? _autoScrollTimer;

  final List<String> _kanbanColumns = [
    'SAVED',
    'SHORTLISTED',
    'APPLIED',
    'INTERVIEWING',
    'OFFER_RECEIVED',
    'REJECTED',
  ];

  final Map<String, String> _columnTitles = {
    'SAVED': 'Saved',
    'SHORTLISTED': 'Shortlisted',
    'APPLIED': 'Applied',
    'INTERVIEWING': 'Interviewing',
    'OFFER_RECEIVED': 'Offered',
    'REJECTED': 'Rejected',
  };

  final Map<String, IconData> _columnIcons = {
    'SAVED': Icons.bookmark_rounded,
    'SHORTLISTED': Icons.star_rounded,
    'APPLIED': Icons.send_rounded,
    'INTERVIEWING': Icons.forum_rounded,
    'OFFER_RECEIVED': Icons.emoji_events_rounded,
    'REJECTED': Icons.cancel_rounded,
  };

  final Map<String, Color> _columnColors = {
    'SAVED': const Color(0xFF6366F1),
    'SHORTLISTED': const Color(0xFFF59E0B),
    'APPLIED': const Color(0xFF3B82F6),
    'INTERVIEWING': const Color(0xFF8B5CF6),
    'OFFER_RECEIVED': const Color(0xFF22C55E),
    'REJECTED': const Color(0xFFEF4444),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kanbanColumns.length + 1, vsync: this);
    _initViewMode();
    _loadSelectedJobs();
  }

  Future<void> _initViewMode() async {
    try {
      final savedMode = await _secureStorage.read(key: 'jobs_view_mode');
      if (savedMode != null && mounted) {
        setState(() {
          _isKanbanView = (savedMode != 'list');
        });
      }
    } catch (_) {}
  }

  Future<void> _changeViewMode(bool isKanban) async {
    setState(() => _isKanbanView = isKanban);
    final modeStr = isKanban ? 'kanban' : 'list';
    
    // Save to local storage immediately
    try {
      await _secureStorage.write(key: 'jobs_view_mode', value: modeStr);
    } catch (_) {}

    // Persist to database
    try {
      await sl<ApiClient>().post('jobs/preferences/', data: {'view_mode': modeStr});
    } catch (e) {
      debugPrint("Failed to sync view preference to DB: $e");
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _kanbanScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(double globalX) {
    if (!_kanbanScrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Left boundary trigger (sidebar is ~250px)
    if (globalX < 360) {
      final double intensity = ((360 - globalX) / 160).clamp(0.3, 2.5);
      _startAutoScroll(-16.0 * intensity);
    } else if (globalX > screenWidth - 140) {
      final double intensity = ((globalX - (screenWidth - 140)) / 140).clamp(0.3, 2.5);
      _startAutoScroll(16.0 * intensity);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double step) {
    if (_autoScrollTimer != null && _autoScrollTimer!.isActive) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_kanbanScrollController.hasClients) return;
      final newOffset = (_kanbanScrollController.offset + step).clamp(
        0.0,
        _kanbanScrollController.position.maxScrollExtent,
      );
      _kanbanScrollController.jumpTo(newOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
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

      // Fetch persisted preference from database
      final prefRes = await sl<ApiClient>().get('jobs/preferences/');
      if (prefRes.statusCode == 200 && prefRes.data != null) {
        final mode = (prefRes.data['view_mode'] ?? '').toString();
        if (mode.isNotEmpty && mounted) {
          final isKanban = (mode != 'list');
          if (_isKanbanView != isKanban) {
            setState(() => _isKanbanView = isKanban);
          }
          await _secureStorage.write(key: 'jobs_view_mode', value: mode);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to load tracked jobs.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateJobStatus(String id, String newStatus) async {
    final oldJob = _jobs.firstWhere((j) => j['id'].toString() == id, orElse: () => null);
    final oldStatus = oldJob != null ? oldJob['status'] : null;

    // Optimistic UI update
    setState(() {
      for (var j in _jobs) {
        if (j['id'].toString() == id) {
          j['status'] = newStatus;
        }
      }
    });

    try {
      final response = await sl<ApiClient>().patch('jobs/selected/$id/', data: {'status': newStatus});
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Moved to ${_columnTitles[newStatus] ?? newStatus}"),
              backgroundColor: _columnColors[newStatus] ?? const Color(0xFF6366F1),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Revert on failure
        if (oldStatus != null) {
          setState(() {
            for (var j in _jobs) {
              if (j['id'].toString() == id) j['status'] = oldStatus;
            }
          });
        }
      }
    } catch (e) {
      if (oldStatus != null) {
        setState(() {
          for (var j in _jobs) {
            if (j['id'].toString() == id) j['status'] = oldStatus;
          }
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteJob(String id) async {
    try {
      final response = await sl<ApiClient>().delete('jobs/selected/$id/');
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _jobs.removeWhere((j) => j['id'].toString() == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job removed from tracker."), backgroundColor: Color(0xFF6366F1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete job entry."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _openDirectUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Opening link: $url")),
        );
      }
    }
  }

  Future<void> _openApplyLink(String? rawUrl, String company, String title, String location) async {
    final fallbackUrl = 'https://www.google.com/search?q=${Uri.encodeComponent('$company $title careers $location')}';
    final urlToOpen = (rawUrl != null && rawUrl.startsWith('http')) ? rawUrl : fallbackUrl;
    _openDirectUrl(urlToOpen);
  }

  List<dynamic> _getFilteredJobs() {
    if (_searchQuery.trim().isEmpty) return _jobs;
    final q = _searchQuery.toLowerCase().trim();
    return _jobs.where((j) {
      final t = (j['job_title'] ?? j['title'] ?? '').toString().toLowerCase();
      final c = (j['company_name'] ?? j['company'] ?? '').toString().toLowerCase();
      final l = (j['location'] ?? '').toString().toLowerCase();
      return t.contains(q) || c.contains(q) || l.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final filteredJobs = _getFilteredJobs();

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadSelectedJobs,
              color: const Color(0xFF6366F1),
              child: Column(
                children: [
                  // HEADER SECTION
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.view_kanban_rounded, color: Color(0xFF6366F1), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Your Jobs & Applications Tracker",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    "Drag and drop cards across pipeline stages to track your application progress",
                                    style: TextStyle(fontSize: 13, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quick Board Navigation Arrows
                            if (_isKanbanView) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                      color: textPrimary,
                                      tooltip: "Scroll Left",
                                      onPressed: () {
                                        if (_kanbanScrollController.hasClients) {
                                          _kanbanScrollController.animateTo(
                                            (_kanbanScrollController.offset - 350).clamp(0.0, _kanbanScrollController.position.maxScrollExtent),
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                      color: textPrimary,
                                      tooltip: "Scroll Right",
                                      onPressed: () {
                                        if (_kanbanScrollController.hasClients) {
                                          _kanbanScrollController.animateTo(
                                            (_kanbanScrollController.offset + 350).clamp(0.0, _kanbanScrollController.position.maxScrollExtent),
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            // View Switcher (Kanban vs List)
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.view_kanban_rounded, size: 20),
                                    color: _isKanbanView ? const Color(0xFF6366F1) : textSecondary,
                                    tooltip: "Kanban Board",
                                    onPressed: () => _changeViewMode(true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                                    color: !_isKanbanView ? const Color(0xFF6366F1) : textSecondary,
                                    tooltip: "List / Tab View",
                                    onPressed: () => _changeViewMode(false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Search bar & status counters
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                style: TextStyle(color: textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: "Search your tracked jobs by role, company, location...",
                                  hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Quick stats pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF14B8A6), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${filteredJobs.length} Total Tracked",
                                    style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // BODY: KANBAN OR TAB VIEW
                  Expanded(
                    child: _isKanbanView
                        ? _buildKanbanBoard(filteredJobs, cardBg, borderColor, textPrimary, textSecondary, isDark)
                        : _buildTabListView(filteredJobs, cardBg, borderColor, textPrimary, textSecondary, isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKanbanBoard(List<dynamic> jobs, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Scrollbar(
        controller: _kanbanScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _kanbanScrollController,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _kanbanColumns.map((colStatus) {
              final colJobs = jobs.where((j) {
                final st = (j['status'] ?? 'SAVED').toString();
                if (colStatus == 'SAVED') return st == 'SAVED' || st == 'NOT_APPLIED';
                if (colStatus == 'INTERVIEWING') return st == 'INTERVIEWING' || st == 'INTERVIEW_CALL_RECEIVED';
                return st == colStatus;
              }).toList();

              return _buildKanbanColumn(colStatus, colJobs, cardBg, borderColor, textPrimary, textSecondary, isDark);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(String status, List<dynamic> colJobs, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    final colTitle = _columnTitles[status] ?? status;
    final colColor = _columnColors[status] ?? const Color(0xFF6366F1);
    final colIcon = _columnIcons[status] ?? Icons.folder_rounded;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _stopAutoScroll();
        final job = details.data;
        final currentStatus = job['status'];
        if (currentStatus != status) {
          _updateJobStatus(job['id'].toString(), status);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 320,
          margin: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(
            color: isHighlighted
                ? colColor.withOpacity(0.12)
                : (isDark ? const Color(0xFF1E293B).withOpacity(0.7) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted ? colColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(colIcon, color: colColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        colTitle,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${colJobs.length}",
                        style: TextStyle(color: colColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Column Body Cards List
              Expanded(
                child: colJobs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.drag_indicator_rounded, color: textSecondary.withOpacity(0.4), size: 32),
                              const SizedBox(height: 8),
                              Text(
                                "Drag jobs here",
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: colJobs.length,
                        itemBuilder: (context, idx) {
                          final job = colJobs[idx] as Map<String, dynamic>;
                          return _buildDraggableJobCard(job, status, cardBg, borderColor, textPrimary, textSecondary, isDark);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableJobCard(Map<String, dynamic> job, String colStatus, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Draggable<Map<String, dynamic>>(
      data: job,
      onDragUpdate: (details) => _handleDragUpdate(details.globalPosition.dx),
      onDragEnd: (details) => _stopAutoScroll(),
      onDraggableCanceled: (velocity, offset) => _stopAutoScroll(),
      feedback: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF6366F1), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (job['job_title'] ?? job['title'] ?? 'Software Developer').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                (job['company_name'] ?? job['company'] ?? 'Tech Company').toString(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildJobCardContent(job, colStatus, cardBg, borderColor, textPrimary, textSecondary, isDark),
      ),
      child: _buildJobCardContent(job, colStatus, cardBg, borderColor, textPrimary, textSecondary, isDark),
    );
  }

  Widget _buildJobCardContent(Map<String, dynamic> job, String colStatus, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    final title = (job['job_title'] ?? job['title'] ?? 'Software Developer').toString();
    final company = (job['company_name'] ?? job['company'] ?? 'Tech Company').toString();
    final location = (job['location'] ?? 'Remote').toString();
    final applyUrl = (job['apply_link'] ?? job['url'] ?? '').toString();
    final jobId = job['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
              // Move Status Popup Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: textSecondary),
                tooltip: "Move to Stage",
                onSelected: (newSt) {
                  if (newSt == 'DELETE') {
                    _deleteJob(jobId);
                  } else {
                    _updateJobStatus(jobId, newSt);
                  }
                },
                itemBuilder: (ctx) => [
                  ..._kanbanColumns.map((st) => PopupMenuItem(
                        value: st,
                        child: Row(
                          children: [
                            Icon(_columnIcons[st], color: _columnColors[st], size: 16),
                            const SizedBox(width: 8),
                            Text(_columnTitles[st] ?? st),
                          ],
                        ),
                      )),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'DELETE',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Text("Remove", style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF14B8A6)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _openApplyLink(applyUrl, company, title, location),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.open_in_new_rounded, color: Color(0xFF6366F1), size: 12),
                      SizedBox(width: 4),
                      Text("Apply", style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Icon(Icons.drag_indicator_rounded, size: 16, color: textSecondary.withOpacity(0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabListView(List<dynamic> jobs, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      children: [
        Container(
          color: cardBg,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: textSecondary,
            indicatorColor: const Color(0xFF6366F1),
            tabs: [
              Tab(text: "All (${jobs.length})"),
              ..._kanbanColumns.map((st) {
                final count = jobs.where((j) => (j['status'] ?? 'SAVED') == st).length;
                return Tab(text: "${_columnTitles[st]} ($count)");
              }),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSimpleJobList(jobs, cardBg, borderColor, textPrimary, textSecondary, isDark),
              ..._kanbanColumns.map((st) {
                final list = jobs.where((j) => (j['status'] ?? 'SAVED') == st).toList();
                return _buildSimpleJobList(list, cardBg, borderColor, textPrimary, textSecondary, isDark);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleJobList(List<dynamic> jobs, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: textSecondary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text("No jobs found in this tab.", style: TextStyle(color: textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: jobs.length,
      itemBuilder: (context, idx) {
        final job = jobs[idx];
        final title = (job['job_title'] ?? job['title'] ?? 'Software Developer').toString();
        final company = (job['company_name'] ?? job['company'] ?? 'Tech Company').toString();
        final location = (job['location'] ?? 'Remote').toString();
        final status = (job['status'] ?? 'SAVED').toString();
        final applyUrl = (job['apply_link'] ?? job['url'] ?? '').toString();
        final jobId = job['id']?.toString() ?? '';

        final colColor = _columnColors[status] ?? const Color(0xFF6366F1);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_columnIcons[status] ?? Icons.work_rounded, color: colColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text("$company • $location", style: TextStyle(fontSize: 13, color: textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colColor.withOpacity(0.3)),
                ),
                child: Text(
                  _columnTitles[status] ?? status,
                  style: TextStyle(color: colColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              // Quick action buttons
              OutlinedButton.icon(
                onPressed: () => _openApplyLink(applyUrl, company, title, location),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text("Apply", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteJob(jobId),
                tooltip: "Delete",
              ),
            ],
          ),
        );
      },
    );
  }
}
