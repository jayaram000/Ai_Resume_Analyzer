import 'package:flutter/material.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_colors.dart';

class PremiumPlanPaywall extends StatefulWidget {
  final String featureTitle;
  final String featureDescription;
  final VoidCallback? onSubscribed;
  final VoidCallback? onDismiss;
  final bool isDialog;

  const PremiumPlanPaywall({
    super.key,
    this.featureTitle = "ResumeAI Pro Features",
    this.featureDescription = "Unlock unlimited AI roadmaps, skill gap intelligence, mock interview prep, and executive PDF reports.",
    this.onSubscribed,
    this.onDismiss,
    this.isDialog = false,
  });

  static Future<void> showAsDialog(
    BuildContext context, {
    String featureTitle = "ResumeAI Pro Features",
    String featureDescription = "Unlock unlimited AI roadmaps, skill gap intelligence, mock interview prep, and executive PDF reports.",
    VoidCallback? onSubscribed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: PremiumPlanPaywall(
            featureTitle: featureTitle,
            featureDescription: featureDescription,
            onSubscribed: () {
              Navigator.of(ctx).pop();
              onSubscribed?.call();
            },
            onDismiss: () => Navigator.of(ctx).pop(),
            isDialog: true,
          ),
        ),
      ),
    );
  }

  @override
  State<PremiumPlanPaywall> createState() => _PremiumPlanPaywallState();
}

class _PremiumPlanPaywallState extends State<PremiumPlanPaywall> {
  bool _isLoadingPlans = true;
  bool _isCheckingOut = false;
  String? _errorMessage;
  List<dynamic> _plans = [];
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _errorMessage = null;
    });

    try {
      final res = await sl<ApiClient>().get('subscriptions/plans/');
      if (res.statusCode == 200 && res.data['success'] == true) {
        final data = res.data['data'] as List;
        // Filter for paid plans
        final paidPlans = data.where((p) {
          final price = (p['price'] is num)
              ? (p['price'] as num).toDouble()
              : double.tryParse(p['price'].toString()) ?? 0.0;
          return price > 0;
        }).toList();

        setState(() {
          _plans = paidPlans;
          if (_plans.isNotEmpty) {
            _selectedPlanId = _plans.first['id'].toString();
          }
        });
      }
    } catch (e) {
      setState(() {
        // Fallback demo plans if offline/network hiccup
        _plans = [
          {
            'id': 'monthly_premium',
            'name': 'Monthly Pro',
            'price': '499.00',
            'duration_days': 30,
            'features': [
              'Unlimited AI Career Roadmaps',
              'Skill Gap Analysis & Blueprints',
              'Interview Prep & Q&A Simulator',
              'AI Tailored Cover Letters',
              'Executive PDF Downloads',
            ]
          },
          {
            'id': 'yearly_premium',
            'name': 'Annual Pro (Best Value)',
            'price': '3999.00',
            'duration_days': 365,
            'features': [
              'All Monthly Pro Features',
              'Save 33% over monthly billing',
              'Priority AI Generation Speed',
              'Unlimited ATS Resumes & Tracking',
              'Dedicated Career Coach Support',
            ]
          },
        ];
        _selectedPlanId = _plans.first['id'].toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
        });
      }
    }
  }

  Future<void> _upgrade() async {
    if (_selectedPlanId == null) return;

    setState(() {
      _isCheckingOut = true;
      _errorMessage = null;
    });

    try {
      // 1. Create Checkout Session
      final checkoutRes = await sl<ApiClient>().post('subscriptions/checkout/', data: {
        'plan_id': _selectedPlanId,
      });

      if (checkoutRes.statusCode == 200 && checkoutRes.data['success'] == true) {
        final orderId = checkoutRes.data['order_id'];

        // 2. Verify Payment (Mock or Live)
        final verifyRes = await sl<ApiClient>().post('subscriptions/verify/', data: {
          'razorpay_payment_id': 'pay_mock_${DateTime.now().millisecondsSinceEpoch}',
          'razorpay_order_id': orderId,
          'plan_id': _selectedPlanId,
        });

        if (verifyRes.statusCode == 200 && verifyRes.data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("🎉 Welcome to ResumeAI Pro! Your subscription is now active."),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
            widget.onSubscribed?.call();
          }
          return;
        }
      }
      throw Exception("Payment confirmation could not be finalized. Please try again.");
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains("Exception:")
              ? e.toString().replaceAll("Exception:", "").trim()
              : "Checkout error occurred. Please verify your connection.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final paperAlt = AppColors.resolvePaperAlt(isDark);
    final textPrimary = AppColors.resolveInk(isDark);
    final textSecondary = AppColors.resolveInkSoft(isDark);
    final rule = AppColors.resolveRule(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final forest = AppColors.resolveForest(isDark);
    final ochre = AppColors.resolveOchre(isDark);
    final brick = AppColors.resolveBrick(isDark);

    return Container(
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(widget.isDialog ? 4 : 0),
        border: widget.isDialog ? Border.all(color: rule) : null,
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Dismiss button if in dialog
                if (widget.isDialog && widget.onDismiss != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: widget.onDismiss,
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                    ),
                  ),

                // Premium Badge Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: ochre.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: ochre.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: ochre, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        "PRO FEATURE EXCLUSIVE",
                        style: TextStyle(
                          color: ochre,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Main Headline
                Text(
                  widget.featureTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Description Subtitle
                Text(
                  widget.featureDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message if checkout fails
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: brick.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: brick.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: brick, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: brick, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Plans Cards Grid
                if (_isLoadingPlans)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: cobalt),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 580;
                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _plans.map((plan) {
                          final planId = plan['id'].toString();
                          final isSelected = _selectedPlanId == planId;
                          final planName = plan['name'] ?? 'Pro Plan';
                          final price = plan['price']?.toString() ?? '499.00';
                          final isAnnual = planName.toLowerCase().contains('year') || (plan['duration_days'] ?? 0) > 100;
                          final features = (plan['features'] is List)
                              ? (plan['features'] as List).map((f) => f.toString()).toList()
                              : [
                                  'Unlimited AI Career Roadmaps',
                                  'Comprehensive Skill Gap Reports',
                                  'AI Tailored Interview Simulation',
                                  'Executive PDF Downloads',
                                ];

                          final cardWidget = GestureDetector(
                            onTap: () => setState(() => _selectedPlanId = planId),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: isSelected ? paperAlt : paper,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected ? cobalt : rule,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        planName,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isAnnual)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: forest.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: forest.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            "SAVE 33%",
                                            style: TextStyle(
                                              color: forest,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'JetBrains Mono',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        "₹${price.replaceAll('.00', '')}",
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'JetBrains Mono',
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isAnnual ? "/ year" : "/ month",
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Divider(height: 1, color: rule),
                                  const SizedBox(height: 16),
                                  ...features.take(5).map((feat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: forest, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              feat,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 12,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );

                          if (isWide) {
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: cardWidget,
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: cardWidget,
                            );
                          }
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCheckingOut ? null : _upgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cobalt,
                        foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: _isCheckingOut
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: isDark ? AppColors.darkPaper : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Upgrade Now & Unlock Access",
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        "Secure 256-Bit Razorpay Checkout • Cancel Anytime",
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
