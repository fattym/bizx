import 'package:flutter/material.dart';

import '../project/project_form_store.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class ProjectFormResponsesPage extends StatefulWidget {
  const ProjectFormResponsesPage({super.key});

  @override
  State<ProjectFormResponsesPage> createState() =>
      _ProjectFormResponsesPageState();
}

class _ProjectFormResponsesPageState extends State<ProjectFormResponsesPage> {
  final TextEditingController _filterController = TextEditingController();
  late Future<List<ProjectFormResponse>> _responsesFuture;
  List<ProjectFormResponse> _currentResponses = <ProjectFormResponse>[];

  @override
  void initState() {
    super.initState();
    _responsesFuture = ProjectFormStore.fetchResponses();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    setState(() {
      _responsesFuture = ProjectFormStore.fetchResponses(
        formNameFilter: _filterController.text,
      );
    });
  }

  Future<void> _downloadExcelLikeCsv() async {
    if (_currentResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No response data to export.')),
      );
      return;
    }

    final questionColumns = <String>{};
    for (final r in _currentResponses) {
      questionColumns.addAll(r.answers.keys);
    }
    final sortedQuestions = questionColumns.toList()..sort();

    final headers = <String>[
      'Form Name',
      'Respondent ID',
      'Submitted At',
      ...sortedQuestions,
    ];
    final buffer = StringBuffer('${headers.map(_csvEscape).join(',')}\n');

    for (final r in _currentResponses) {
      final row = <String>[
        r.formTitle,
        r.respondentId,
        r.submittedAt.toIso8601String(),
        ...sortedQuestions.map((q) => (r.answers[q] ?? '').toString()),
      ];
      buffer.writeln(row.map(_csvEscape).join(','));
    }

    final filter = _filterController.text.trim();
    final suffix = filter.isEmpty
        ? 'all_forms'
        : filter.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fileName =
        'project_form_responses_${suffix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    try {
      await downloadCsvTemplate(fileName, buffer.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel export download started: $fileName')),
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Download is not supported on this device in current mode.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 700;
    final maxContentWidth = screenWidth > 1200 ? 1100.0 : 980.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Project Form Responses')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child: isSmall
                    ? Column(
                        children: [
                          TextField(
                            controller: _filterController,
                            decoration: const InputDecoration(
                              labelText: 'Filter by form name',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _applyFilter(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _applyFilter,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Filter'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _downloadExcelLikeCsv,
                                  icon: const Icon(Icons.download_outlined),
                                  label: const Text('Download Excel'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _filterController,
                              decoration: const InputDecoration(
                                labelText: 'Filter by form name',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _applyFilter(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _applyFilter,
                            icon: const Icon(Icons.search),
                            label: const Text('Filter'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _downloadExcelLikeCsv,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Download Excel'),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: FutureBuilder<List<ProjectFormResponse>>(
                  future: _responsesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load responses: ${snapshot.error}',
                          ),
                        ),
                      );
                    }
                    final responses = snapshot.data ?? <ProjectFormResponse>[];
                    _currentResponses = responses;
                    if (responses.isEmpty) {
                      return const Center(
                        child: Text('No collected data found for this filter.'),
                      );
                    }
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        isSmall ? 12 : 16,
                        0,
                        isSmall ? 12 : 16,
                        isSmall ? 12 : 16,
                      ),
                      itemCount: responses.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: isSmall ? 8 : 10),
                      itemBuilder: (context, index) {
                        final r = responses[index];
                        return Card(
                          child: Padding(
                            padding: EdgeInsets.all(isSmall ? 12 : 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.formTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmall ? 15 : 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Submitted by: ${r.respondentId}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text('Submitted at: ${r.submittedAt.toLocal()}'),
                                const Divider(height: 20),
                                ...r.answers.entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text('${e.key}: ${e.value}'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
