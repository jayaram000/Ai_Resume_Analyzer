import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';

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

      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _successMessage = "Profile updated successfully!";
        });
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? "Failed to save profile.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error occurred saving profile. Try again.";
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _triggerUpgrade() async {
    // Standard mock checkout checkout trigger for subscription plan
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Upgrade to Premium Tier", style: TextStyle(color: Colors.white)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Get unlimited resume uploads, advanced JSearch skill gap analytics, custom PDF exports, and simulated interview preps.",
                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                "Price: \$29 / month",
                style: TextStyle(color: Color(0xFF14B8A6), fontSize: 16, fontWeight: FontWeight.bold),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() { _isLoading = true; });
                try {
                  // 1. Fetch available plans
                  final plansRes = await sl<ApiClient>().get('subscriptions/plans/');
                  if (plansRes.statusCode == 200 && plansRes.data['success'] == true) {
                    final plans = plansRes.data['data'] as List;
                    if (plans.isEmpty) {
                      throw Exception("No active subscription plans found.");
                    }
                    final planId = plans.first['id'];
                    
                    // 2. Create checkout session
                    final checkoutRes = await sl<ApiClient>().post('subscriptions/checkout/', data: {
                      'plan_id': planId
                    });
                    
                    if (checkoutRes.statusCode == 200 && checkoutRes.data['success'] == true) {
                      final orderId = checkoutRes.data['order_id'];
                      
                      // 3. Verify payment to activate subscription
                      final verifyRes = await sl<ApiClient>().post('subscriptions/verify/', data: {
                        'razorpay_payment_id': 'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
                        'razorpay_order_id': orderId,
                        'plan_id': planId
                      });
                      
                      if (verifyRes.statusCode == 200 && verifyRes.data['success'] == true) {
                        _loadProfileData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Successfully upgraded to Premium!"), backgroundColor: Colors.green),
                        );
                        return;
                      }
                    }
                  }
                  throw Exception("Subscription checkout failed.");
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Checkout error: $e"), backgroundColor: Colors.redAccent),
                  );
                  _loadProfileData();
                }
              },
              child: const Text("Subscribe"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Edit Card
                    Card(
                      color: const Color(0xCC1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "User Profile Details",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _roleController,
                              decoration: const InputDecoration(
                                labelText: "Target/Current Role Title",
                                prefixIcon: Icon(Icons.badge_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Years of Experience",
                                prefixIcon: Icon(Icons.timeline_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: "Phone Contact Number",
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: "Location / Country",
                                prefixIcon: Icon(Icons.location_on_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _linkedinController,
                              decoration: const InputDecoration(
                                labelText: "LinkedIn Profile URL",
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _githubController,
                              decoration: const InputDecoration(
                                labelText: "GitHub Profile URL",
                                prefixIcon: Icon(Icons.code_rounded),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            if (_successMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Text(_successMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                              ),
                            _isSaving
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                                : Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF14B8A6)]),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text("Save Settings Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Subscription Upgrade Card
                    Card(
                      color: const Color(0xCC1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Membership Subscription Plan", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _activePlan,
                                    style: TextStyle(
                                      color: _isPremium ? const Color(0xFF14B8A6) : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isPremium ? "Unlocked full premium access" : "Upgrade to unlock advanced roadmaps and interview simulators",
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isPremium)
                              ElevatedButton(
                                onPressed: _triggerUpgrade,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Upgrade"),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
