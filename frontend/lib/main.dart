import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/auth/screens/forgot_password_screen.dart';

import 'package:frontend/features/dashboard/cubit/usage_cubit.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencyInjection();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => sl<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider<UsageCubit>(
          create: (context) {
            if (!sl.isRegistered<UsageCubit>()) {
              sl.registerLazySingleton<UsageCubit>(() => UsageCubit());
            }
            return sl<UsageCubit>()..fetchUsageStatus();
          },
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.themeModeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'ResumeAI & Career Copilot',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading) {
          return Scaffold(
            backgroundColor: AppColors.resolvePaper(isDark),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.resolveCobalt(isDark),
              ),
            ),
          );
        } else if (state is Authenticated) {
          return DashboardScreen(email: state.email, userData: state.userData);
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = AppColors.resolvePaper(isDark);
    final cardBg = AppColors.resolvePaperAlt(isDark);
    final borderColor = AppColors.resolveRule(isDark);
    final textPrimary = AppColors.resolveInk(isDark);
    final textSecondary = AppColors.resolveInkMuted(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);

    return Scaffold(
      backgroundColor: paper,
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
                  // DOSSIER BADGE
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: cobalt.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: cobalt),
                          const SizedBox(width: 6),
                          Text(
                            "WELCOME BACK // SIGN IN",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: cobalt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Sign In to ResumeAI",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Enter your credentials to access your resumes and analysis.",
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email Form
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "EMAIL ADDRESS",
                      labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                      hintText: "user@domain.com",
                      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.email_outlined, color: textSecondary, size: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Form
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: "PASSWORD",
                      labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                      hintText: "••••••••",
                      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.lock_outline, color: textSecondary, size: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: cobalt,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Error display block
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthFailure) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.resolveBrick(isDark).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.resolveBrick(isDark).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            state.message,
                            style: TextStyle(color: AppColors.resolveBrick(isDark), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthBloc>().add(LoginRequested(
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                              ));
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
                      child: const Text(
                        "AUTHENTICATE & ENTER",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Need an account? ", style: TextStyle(color: textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: Text(
                          "Register File",
                          style: TextStyle(
                            color: cobalt,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(LoginRequested(
                            email: "dev@career.ai",
                            password: "password123",
                          ));
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text(
                      "Quick Dev Login Bypass",
                      style: TextStyle(fontSize: 12),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Registration successful! Please sign in."),
                backgroundColor: AppColors.resolveForest(isDark),
              ),
            );
            Navigator.pop(context);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.resolveBrick(isDark),
              ),
            );
          }
        },
        child: Center(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cobalt.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cobalt.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_outlined, size: 14, color: cobalt),
                            const SizedBox(width: 6),
                            Text(
                              "CREATE ACCOUNT // GET STARTED",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: cobalt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Create Free Account",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Register a new account to analyze resumes and track career goals.",
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _usernameController,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "USERNAME",
                        labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                        hintText: "johndoe",
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.person_outline, color: textSecondary, size: 18),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "EMAIL ADDRESS",
                        labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                        hintText: "user@domain.com",
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.email_outlined, color: textSecondary, size: 18),
                      ),
                      validator: (value) => value == null || !value.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "PASSWORD (MIN 8 CHARS)",
                        labelStyle: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5),
                        hintText: "••••••••",
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.lock_outline, color: textSecondary, size: 18),
                      ),
                      validator: (value) => value == null || value.length < 8 ? 'Password must be 8+ chars' : null,
                    ),
                    const SizedBox(height: 24),

                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state is AuthLoading) {
                          return Center(
                            child: CircularProgressIndicator(color: cobalt),
                          );
                        }

                        return SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                context.read<AuthBloc>().add(RegisterRequested(
                                      username: _usernameController.text.trim(),
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text,
                                    ));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cobalt,
                              foregroundColor: isDark ? AppColors.darkPaper : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text(
                              "CREATE ACCOUNT",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ", style: TextStyle(color: textSecondary, fontSize: 13)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            "Sign In",
                            style: TextStyle(
                              color: cobalt,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

