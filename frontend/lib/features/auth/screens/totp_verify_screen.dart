import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';

class TOTPVerifyScreen extends StatefulWidget {
  final String email;

  const TOTPVerifyScreen({super.key, required this.email});

  @override
  State<TOTPVerifyScreen> createState() => _TOTPVerifyScreenState();
}

class _TOTPVerifyScreenState extends State<TOTPVerifyScreen> {
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final cardBg = AppColors.resolvePaperAlt(isDark);
    final borderColor = AppColors.resolveRule(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        title: const Text("Two-Factor Authentication"),
        backgroundColor: paper,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.resolveInk(isDark)),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 48, color: Colors.blueGrey),
                const SizedBox(height: 16),
                const Text(
                  "Authentication Required",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the 6-digit code from your authenticator app for ${widget.email}.",
                  style: TextStyle(color: AppColors.resolveInkMuted(isDark)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "000000",
                    counterText: "",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is Authenticated) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  builder: (context, state) {
                    if (state is AuthFailure) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          state.message,
                          style: TextStyle(color: AppColors.resolveBrick(isDark), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (state is AuthLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_codeController.text.length == 6) {
                            context.read<AuthBloc>().add(
                              TOTPVerifyRequested(email: widget.email, code: _codeController.text)
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cobalt,
                          foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text("VERIFY CODE"),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
