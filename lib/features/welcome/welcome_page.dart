import 'auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/colors.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://www.longhornpublishers.com/wp-content/uploads/2024/01/schoolgirl-hero-1-1536x950.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(color: AppColors.primaryGreen);
              },
            ),
          ),
          Positioned.fill(
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
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  const Text(
                    'Welcome to',
                    style: TextStyle(
                      color: AppColors.surfaceWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/icons/download-removebg-preview.png',
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Your complete publisher portal for managing school accounts, tasks, and workflows.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryPale,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeHeusLogin(),
                        ),
                      );
                    },
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
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Longhorn Publishers PLC',
                        applicationVersion: _version,
                        applicationIcon: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: Image.asset(
                            'assets/images/icons/download-removebg-preview.png',
                            height: 50,
                          ),
                        ),
                        children: [
                          const Text(
                            'This portal allows you to manage school accounts and publication workflows seamlessly.',
                          ),
                        ],
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('About'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryPale,
                      side: const BorderSide(
                        color: AppColors.primaryLight,
                        width: 1.5,
                      ),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
