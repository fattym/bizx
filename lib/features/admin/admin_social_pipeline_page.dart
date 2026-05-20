import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_social_inbox_page.dart';

class AdminSocialPipelinePage extends StatefulWidget {
  const AdminSocialPipelinePage({super.key});

  @override
  State<AdminSocialPipelinePage> createState() => _AdminSocialPipelinePageState();
}

class _AdminSocialPipelinePageState extends State<AdminSocialPipelinePage> {
  final _supabase = Supabase.instance.client;
  static const String _directFacebookUrl =
      'https://www.facebook.com/longhornpublishers/';
  static const String _directWhatsAppPhone = '0798734442';
  bool _isLoading = true;
  List<_SocialLead> _allLeads = <_SocialLead>[];

  @override
  void initState() {
    super.initState();
    _loadPipeline();
  }

  Future<void> _loadPipeline() async {
    setState(() => _isLoading = true);
    try {
      final schoolsRes = await _supabase
          .from('schools')
          .select('id,name,phone,source,captured_by,created_at')
          .order('created_at', ascending: false);

      final salesRes = await _supabase
          .from('school_sales')
          .select('school_id,sale_status,expected_value,stage_updated_at')
          .order('stage_updated_at', ascending: false);

      final latestSaleBySchool = <String, Map<String, dynamic>>{};
      for (final sale in List<Map<String, dynamic>>.from(salesRes)) {
        final schoolId = (sale['school_id'] ?? '').toString();
        if (schoolId.isNotEmpty && !latestSaleBySchool.containsKey(schoolId)) {
          latestSaleBySchool[schoolId] = sale;
        }
      }

      final leads = <_SocialLead>[];
      for (final school in List<Map<String, dynamic>>.from(schoolsRes)) {
        final source = (school['source'] ?? '').toString().toLowerCase().trim();
        if (source != 'facebook' && source != 'whatsapp') {
          continue;
        }
        final schoolId = (school['id'] ?? '').toString();
        final sale = latestSaleBySchool[schoolId];
        leads.add(
          _SocialLead(
            schoolName: (school['name'] ?? 'Unknown school').toString(),
            phone: (school['phone'] ?? '').toString(),
            source: source,
            stage: (sale?['sale_status'] ?? 'lead').toString(),
            expectedValue: ((sale?['expected_value'] ?? 0) as num).toDouble(),
            capturedBy: (school['captured_by'] ?? '').toString(),
            createdAt: DateTime.tryParse((school['created_at'] ?? '').toString()),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _allLeads = leads.isEmpty ? _dummyLeads() : leads;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load social pipeline: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facebookLeads = _allLeads.where((l) => l.source == 'facebook').toList();
    final whatsappLeads = _allLeads.where((l) => l.source == 'whatsapp').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Facebook & WhatsApp Pipeline'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Facebook'),
              Tab(text: 'WhatsApp'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Open Social Inbox',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSocialInboxPage(),
                  ),
                );
              },
              icon: const Icon(Icons.forum_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadPipeline,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _countCard('Facebook Leads', facebookLeads.length),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _countCard('WhatsApp Leads', whatsappLeads.length),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _openDirectWhatsApp,
                          icon: const Icon(Icons.chat),
                          label: const Text('Open Direct WhatsApp'),
                        ),
                        FilledButton.icon(
                          onPressed: _openDirectFacebook,
                          icon: const Icon(Icons.facebook),
                          label: const Text('Open Direct Facebook'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildList(facebookLeads),
                        _buildList(whatsappLeads),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _countCard(String label, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 6),
            Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_SocialLead> leads) {
    if (leads.isEmpty) {
      return const Center(
        child: Text('No leads found for this channel yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lead = leads[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    lead.source == 'facebook' ? Icons.facebook : Icons.chat,
                    color: lead.source == 'facebook' ? Colors.indigo : Colors.green,
                  ),
                  title: Text(lead.schoolName),
                  subtitle: Text(
                    'Stage: ${lead.stage}\n'
                    'Expected: KES ${lead.expectedValue.toStringAsFixed(0)}\n'
                    'Phone: ${lead.phone.isEmpty ? 'N/A' : lead.phone}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lead.capturedBy.isEmpty ? 'Unassigned' : lead.capturedBy,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(lead.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(lead),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openFacebook(lead),
                      icon: const Icon(Icons.facebook, size: 18),
                      label: const Text('Facebook'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp(_SocialLead lead) async {
    final cleanPhone = lead.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      _showInfo('No phone number found for this lead.');
      return;
    }

    final message = Uri.encodeComponent('Hello ${lead.schoolName}');
    final deepLink = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$message');
    final webLink = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    final openedApp = await launchUrl(deepLink, mode: LaunchMode.externalApplication);
    if (!openedApp) {
      final openedWeb = await launchUrl(webLink, mode: LaunchMode.externalApplication);
      if (!openedWeb) _showInfo('Could not open WhatsApp.');
    }
  }

  Future<void> _openFacebook(_SocialLead lead) async {
    final query = Uri.encodeComponent(lead.schoolName);
    final facebookSearch = Uri.parse('https://www.facebook.com/search/top?q=$query');
    final opened = await launchUrl(
      facebookSearch,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showInfo('Could not open Facebook.');
  }

  Future<void> _openDirectWhatsApp() async {
    final message = Uri.encodeComponent('Hello Longhorn Publishers');
    final deepLink = Uri.parse(
      'whatsapp://send?phone=$_directWhatsAppPhone&text=$message',
    );
    final webLink = Uri.parse(
      'https://wa.me/$_directWhatsAppPhone?text=$message',
    );
    final openedApp = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );
    if (!openedApp) {
      final openedWeb = await launchUrl(
        webLink,
        mode: LaunchMode.externalApplication,
      );
      if (!openedWeb) _showInfo('Could not open direct WhatsApp.');
    }
  }

  Future<void> _openDirectFacebook() async {
    final opened = await launchUrl(
      Uri.parse(_directFacebookUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showInfo('Could not open direct Facebook page.');
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

List<_SocialLead> _dummyLeads() {
  return const [
    _SocialLead(
      schoolName: 'Green Valley School',
      phone: '0798734442',
      source: 'facebook',
      stage: 'contacted',
      expectedValue: 120000,
      capturedBy: 'sales@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Sunrise Academy',
      phone: '0712345678',
      source: 'facebook',
      stage: 'meeting_scheduled',
      expectedValue: 85000,
      capturedBy: 'agent@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Hilltop Primary',
      phone: '0700111222',
      source: 'whatsapp',
      stage: 'lead',
      expectedValue: 60000,
      capturedBy: 'manager@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Lakeview School',
      phone: '0722333444',
      source: 'whatsapp',
      stage: 'negotiation',
      expectedValue: 145000,
      capturedBy: 'sales@dehus.com',
      createdAt: null,
    ),
  ];
}

class _SocialLead {
  const _SocialLead({
    required this.schoolName,
    required this.phone,
    required this.source,
    required this.stage,
    required this.expectedValue,
    required this.capturedBy,
    required this.createdAt,
  });

  final String schoolName;
  final String phone;
  final String source;
  final String stage;
  final double expectedValue;
  final String capturedBy;
  final DateTime? createdAt;
}
