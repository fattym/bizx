import 'register_page.dart';
import 'admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/colors.dart';
import '../../database/database_service.dart';
import '../../admin/admin_dashboard_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../admin/admin_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/bas_dashboard_page.dart';
import '../../../core/constants/agent_dashboard_page.dart';
import '../../profile/profile_page.dart';

class DeHeusLogin extends StatefulWidget {
  const DeHeusLogin({super.key});

  @override
  State<DeHeusLogin> createState() => _DeHeusLoginState();
}

class _DeHeusLoginState extends State<DeHeusLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  final DatabaseService _dbService = DatabaseService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    try {
      final supabase = Supabase.instance.client;
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = authResponse.user;
      if (user != null) {
        // Fetch the role directly from the public.users table to avoid model parsing errors
        final userData =
            await supabase
                .from('users')
                .select('role')
                .eq('id', user.id)
                .maybeSingle();

        final metadataRole = user.userMetadata?['role']?.toString();
        final dbRole = userData?['role'] as int?;

        if (!mounted) return;
        final resolvedRole =
            dbRole ??
            int.tryParse(metadataRole ?? '') ??
            (metadataRole?.toLowerCase() == 'admin' ? 1 : null) ??
            5;

        // DEBUG: Check what values are being read upon login
        print('--- LOGIN DEBUG ---');
        print('Auth Metadata Role: $metadataRole');
        print('Public DB Role: $dbRole');
        print('Final Resolved Role: $resolvedRole');
        print('-------------------');

        Widget destination;
        switch (resolvedRole) {
          case 1:
            destination = const AdminDashboardPage();
            break;
          case 2:
            destination = const AdminDashboardScreen();
            break;
          case 3:
            destination = const BasDashboardPage();
            break;
          case 4:
            destination = const AgentDashboardPage();
            break;
          case 5:
            destination =
                const SalesDashboard(); // SalesDashboard serves as the Grounds Operation dashboard
            break;
          default:
            destination = const SalesDashboard();
            break;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destination),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final message = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAdminLogin() async {
    if (kIsWeb) {
      final adminUrl = Uri.base.replace(path: '/admin-login');
      final launched = await launchUrl(adminUrl, webOnlyWindowName: '_blank');
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the admin login page.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primaryGreen],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.85),
                AppColors.textDark.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // App Branding
                  const Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Agents Portal",
                    style: TextStyle(
                      color: AppColors.surfaceWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    "Log in to manage school accounts and publication workflows",
                    style: TextStyle(
                      color: AppColors.primaryPale,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Login Card
                  _buildLoginCard(),

                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () {
                      // Navigate to Register
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeHeusRegister(),
                        ),
                      );
                    }, // Navigate to Register

                    child: const Text(
                      "Don't have an account? Register here",
                      style: TextStyle(
                        color: AppColors.primaryPale,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openAdminLogin,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Login as Admin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPale,
                        side: const BorderSide(
                          color: AppColors.primaryLight,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.primaryGreen,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.primaryGreen,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed:
                    () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGrey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Forgot Password?",
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // The Login Button
          ElevatedButton(
            onPressed: _loginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: AppColors.surfaceWhite,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "SIGN IN",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
