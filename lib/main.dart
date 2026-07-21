import 'dart:ui' as ui;
import 'core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'features/welcome/welcome_page.dart';
import 'features/welcome/auth/login_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/welcome/auth/admin_login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/bas_dashboard_page.dart';
import 'core/constants/agent_dashboard_page.dart';
import 'features/profile/profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/github_release_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const DeHeusApp());
}

class DeHeusApp extends StatelessWidget {
  const DeHeusApp({super.key, this.useRemoteHeroImage = true});

  final bool useRemoteHeroImage;
  static const Color _accentColor = Color(0xFF653A48);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Longhorn Publishers PLC',
      debugShowCheckedModeBanner: false,
      initialRoute: ui.PlatformDispatcher.instance.defaultRouteName,
      routes: {
        '/': (_) => const _SessionEntryPage(),
        '/login': (_) => const DeHeusLogin(),
        '/admin-login': (_) => const AdminLoginPage(),
        '/admin': (_) => const AdminDashboardPage(),
      },

      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primaryGreen,
        scaffoldBackgroundColor: const Color(0xFFF6F3F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.longhornMaroon,
          tertiary: _accentColor,
          surface: const Color(0xFFFDFBF9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.charcoalGrey),
          bodyMedium: TextStyle(color: AppColors.charcoalGrey),
        ),
      ),
    );
  }
}

class _SessionEntryPage extends StatefulWidget {
  const _SessionEntryPage();

  @override
  State<_SessionEntryPage> createState() => _SessionEntryPageState();
}

class _SessionEntryPageState extends State<_SessionEntryPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolveStartupDestination();
  }

  Future<void> _resolveStartupDestination() async {
    final session = _supabase.auth.currentSession;
    if (session == null || session.user.id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _destination = const WelcomePage();
        _loading = false;
      });
      _checkForUpdate();
      return;
    }

    try {
      final userId = session.user.id;
      final userData =
          await _supabase
              .from('users')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
      final metadataRole = session.user.userMetadata?['role']?.toString();
      final dbRole = userData?['role'] as int?;
      final resolvedRole =
          dbRole ??
          int.tryParse(metadataRole ?? '') ??
          (metadataRole?.toLowerCase() == 'admin' ? 1 : null) ??
          5;

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
          destination = const SalesDashboard();
          break;
        default:
          destination = const SalesDashboard();
          break;
      }

      if (!mounted) return;
      setState(() {
        _destination = destination;
        _loading = false;
      });
      _checkForUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destination = const WelcomePage();
        _loading = false;
      });
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final updateAvailable = await GithubReleaseService(
      owner: 'dehus',
      repo: 'dehus',
    ).isUpdateAvailable();

    if (!mounted || !updateAvailable) return;

    final release = await GithubReleaseService(
      owner: 'dehus',
      repo: 'dehus',
    ).fetchLatestRelease();
    if (!mounted || release == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'A new version (${release.tagName.replaceFirst(RegExp(r'^v'), '')}) is available.\n\nPlease update to get the latest features and bug fixes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(
                release.apkDownloadUrl ?? release.htmlUrl,
              );
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open update link')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _destination == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _destination!;
  }
}
