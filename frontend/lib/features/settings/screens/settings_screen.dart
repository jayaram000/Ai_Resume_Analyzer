import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _roleController = TextEditingController();
  final _experienceController = TextEditingController();
  
  String _activePlan = "Free Tier";
  bool _isPremium = false;
  String _userEmail = "";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await sl<ApiClient>().get('auth/profile/');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final profile = data['profile'] ?? {};
        
        _phoneController.text = profile['phone'] ?? '';
        _locationController.text = profile['location'] ?? '';
        _linkedinController.text = profile['linkedin_url'] ?? '';
        _githubController.text = profile['github_url'] ?? '';
        _roleController.text = profile['current_role'] ?? '';
        _experienceController.text = (profile['years_of_experience'] ?? 0).toString();

        // Check active subscriptions from /api/subscriptions/active/
        final subRes = await sl<ApiClient>().get('subscriptions/active/');
        if (subRes.statusCode == 200 && subRes.data['success'] == true) {
          final data = subRes.data['data'];
          setState(() {
            _isPremium = data != null && data['status'] == 'active';
            _activePlan = data != null ? data['plan_name'] : "Free Tier";
          });
        }
        setState(() {
          _userEmail = data['email'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load user profile. Re-trying.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkMuted(isDark);
    final brick = AppColors.resolveBrick(isDark);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: paperAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: rule),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: brick, size: 20),
            const SizedBox(width: 8),
            Text(
              "CONFIRM SIGN OUT",
              style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to sign out of your account? You will need to authenticate again to access your dossiers.",
          style: TextStyle(color: inkSoft, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: inkSoft,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<AuthBloc>().add(LogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brick,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await sl<ApiClient>().put('auth/profile/', data: {
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'github_url': _githubController.text.trim(),
        'current_role': _roleController.text.trim(),
        'years_of_experience': int.tryParse(_experienceController.text) ?? 0,
      });

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = "Profile updated successfully!";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to update profile. Please try again.";
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _triggerUpgrade() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final rule = AppColors.resolveRule(isDark);
    final ink = AppColors.resolveInk(isDark);
    final inkSoft = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final brick = AppColors.resolveBrick(isDark);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: paperAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: rule),
          ),
          title: Text(
            "UPGRADE TO PREMIUM TIER",
            style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Unlock unlimited resume audits, advanced live market gap tracking, custom PDF dossier exports, and AI career path simulations.",
                style: TextStyle(color: inkSoft, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: forest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: forest.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("SUBSCRIPTION FEE:", style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text("\$29 / MONTH", style: TextStyle(color: forest, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: inkSoft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() { _isLoading = true; });
                try {
                  final plansRes = await sl<ApiClient>().get('subscriptions/plans/');
                  if (plansRes.statusCode == 200 && plansRes.data['success'] == true) {
                    final plans = plansRes.data['data'] as List;
                    if (plans.isEmpty) {
                      throw Exception("No active subscription plans found.");
                    }
                    final planId = plans.first['id'];
                    
                    final checkoutRes = await sl<ApiClient>().post('subscriptions/checkout/', data: {
                      'plan_id': planId
                    });
                    
                    if (checkoutRes.statusCode == 200 && checkoutRes.data['success'] == true) {
                      final orderId = checkoutRes.data['order_id'];
                      
                      final verifyRes = await sl<ApiClient>().post('subscriptions/verify/', data: {
                        'razorpay_payment_id': 'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
                        'razorpay_order_id': orderId,
                        'plan_id': planId
                      });
                      
                      if (verifyRes.statusCode == 200 && verifyRes.data['success'] == true) {
                        _loadProfileData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text("Successfully upgraded to Premium!"), backgroundColor: forest),
                        );
                        return;
                      }
                    }
                  }
                  throw Exception("Subscription checkout failed.");
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Checkout error: $e"), backgroundColor: brick),
                  );
                  _loadProfileData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cobalt,
                foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text("ACTIVATE TIER", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
            ),
          ],
        );
      },
    );
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

    return Scaffold(
      backgroundColor: paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cobalt))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Edit Card
                    Container(
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 18, color: cobalt),
                              const SizedBox(width: 8),
                              Text(
                                "DOSSIER PROFILE CONFIGURATION",
                                style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _roleController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "Target/Current Role Title",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.badge_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _experienceController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "Years of Experience",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.timeline_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "Phone Contact Number",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.phone_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "Location / Country",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.location_on_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _linkedinController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "LinkedIn Profile URL",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.link_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _githubController,
                            style: TextStyle(color: ink),
                            decoration: InputDecoration(
                              labelText: "GitHub Profile URL",
                              labelStyle: TextStyle(color: inkSoft),
                              prefixIcon: Icon(Icons.code_rounded, color: inkSoft, size: 20),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: brick.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: brick.withValues(alpha: 0.3)),
                              ),
                              child: Text(_errorMessage!, style: TextStyle(color: brick, fontSize: 12)),
                            ),
                          if (_successMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: forest.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: forest.withValues(alpha: 0.3)),
                              ),
                              child: Text(_successMessage!, style: TextStyle(color: forest, fontSize: 12)),
                            ),
                          _isSaving
                              ? Center(child: CircularProgressIndicator(color: cobalt))
                              : SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cobalt,
                                      foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Text(
                                      "SAVE DOSSIER PROFILE",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subscription Upgrade Card
                    Container(
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MEMBERSHIP SUBSCRIPTION TIER",
                                  style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _activePlan,
                                  style: TextStyle(
                                    color: _isPremium ? forest : ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isPremium
                                      ? "Unlocked full premium tier dossier access"
                                      : "Upgrade to unlock advanced roadmaps and interview simulators",
                                  style: TextStyle(color: inkSoft, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (!_isPremium)
                            ElevatedButton(
                              onPressed: _triggerUpgrade,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cobalt,
                                foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: const Text(
                                "UPGRADE",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account & Security / Logout Card
                    Container(
                      decoration: BoxDecoration(
                        color: paperAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: rule),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SESSION & SECURITY CREDENTIALS",
                            style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _userEmail.isNotEmpty
                                ? "Authenticated as $_userEmail"
                                : "Manage your active session and authentication.",
                            style: TextStyle(color: inkSoft, fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmLogout(context),
                              icon: Icon(Icons.logout_rounded, color: brick, size: 16),
                              label: Text(
                                "SIGN OUT OF DOSSIER",
                                style: TextStyle(
                                  color: brick,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: brick.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                backgroundColor: brick.withValues(alpha: 0.08),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
