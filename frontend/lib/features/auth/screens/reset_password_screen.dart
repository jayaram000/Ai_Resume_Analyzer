import 'package:flutter/material.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/theme/app_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialToken;
  const ResetPasswordScreen({super.key, this.initialToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await sl<ApiClient>().post('auth/reset-password/', data: {
        'token': widget.initialToken ?? "",
        'new_password': _newPasswordController.text,
      });

      if (mounted) {
        if (response.statusCode == 200 && response.data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Password reset successfully! You can now log in."),
              backgroundColor: AppColors.resolveForest(Theme.of(context).brightness == Brightness.dark),
            ),
          );
          Navigator.pop(context); // Go back to login
        } else {
          setState(() {
            _errorMessage = response.data['message'] ?? "Failed to reset password.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred. Check if the token is valid.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final cardBg = AppColors.resolvePaperAlt(isDark);
    final borderColor = AppColors.resolveRule(isDark);
    final textPrimary = AppColors.resolveInk(isDark);
    final textSecondary = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final brick = AppColors.resolveBrick(isDark);

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: paper,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.password, size: 48, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text(
                    "Set New Password",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter the secure reset token from your email and choose a new password.",
                    style: TextStyle(color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "NEW PASSWORD",
                      labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "CONFIRM NEW PASSWORD",
                      labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
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
                      child: Text(_errorMessage!, style: TextStyle(color: brick, fontSize: 12), textAlign: TextAlign.center),
                    ),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _resetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cobalt,
                              foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              "RESET PASSWORD",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
